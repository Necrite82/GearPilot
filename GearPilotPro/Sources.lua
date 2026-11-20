-- Quest rewards and dungeon drops from the ForeverDB addon (GPL-3.0, github.com/foreverfraddons/forever-db).
-- ForeverDB is LoadOnDemand: it is loaded the first time GearPilot needs quest or dungeon data.
-- Sources.Build is pure Lua so tests can run it with a small sample database.
local _, GP = ...
local Sources = {}
GP.Sources = Sources

-- Classic instance maps (ForeverDB spawn coordinates name the map). Raids are marked.
Sources.instances = {
    [33] = {"Shadowfang Keep"}, [34] = {"The Stockade"}, [36] = {"The Deadmines"}, [43] = {"Wailing Caverns"},
    [47] = {"Razorfen Kraul"}, [48] = {"Blackfathom Deeps"}, [70] = {"Uldaman"}, [90] = {"Gnomeregan"},
    [109] = {"The Temple of Atal'Hakkar"}, [129] = {"Razorfen Downs"}, [189] = {"Scarlet Monastery"},
    [209] = {"Zul'Farrak"}, [229] = {"Blackrock Spire"}, [230] = {"Blackrock Depths"}, [289] = {"Scholomance"},
    [329] = {"Stratholme"}, [349] = {"Maraudon"}, [389] = {"Ragefire Chasm"}, [429] = {"Dire Maul"},
    [249] = {"Onyxia's Lair", true}, [309] = {"Zul'Gurub", true}, [409] = {"Molten Core", true},
    [469] = {"Blackwing Lair", true}, [509] = {"Ruins of Ahn'Qiraj", true}, [531] = {"Temple of Ahn'Qiraj", true},
    [533] = {"Naxxramas", true},
}
-- Raid names, so quests that play in a raid (tier tokens) count as raid sources.
Sources.raidNames = {}
for _, instance in pairs(Sources.instances) do
    if instance[2] then Sources.raidNames[instance[1]] = true end
end
-- Not dungeons: PvP halls and the tram.
local notDungeons = { [2257] = true, [2917] = true, [2918] = true }

-- Race bits: Alliance human 1, dwarf 4, night elf 8, gnome 64, Skyborne 2^32; Horde orc 2, undead 16,
-- tauren 32, troll 128, Skyborne 2^33. Plain arithmetic: the masks are larger than 32 bits.
local function bit(mask, value)
    return math.floor(mask / value) % 2 == 1
end
function Sources.QuestFaction(mask)
    if type(mask) ~= "number" or mask <= 0 then return nil end
    local alliance = bit(mask, 1) or bit(mask, 4) or bit(mask, 8) or bit(mask, 64) or bit(mask, 2 ^ 32)
    local horde = bit(mask, 2) or bit(mask, 16) or bit(mask, 32) or bit(mask, 128) or bit(mask, 2 ^ 33)
    if alliance and not horde then return "Alliance" end
    if horde and not alliance then return "Horde" end
    return nil
end
-- Race masks: bit 2^(raceID - 1). Classic data often marks a quest for "every Alliance / Horde race" without
-- the Skyborne bits (2^32 Alliance, 2^33 Horde); such a full faction mask counts for the Skyborne too.
local ALLIANCE_ALL, HORDE_ALL = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128
local function fullFaction(mask, all)
    for _, value in ipairs(all == ALLIANCE_ALL and { 1, 4, 8, 64 } or { 2, 16, 32, 128 }) do
        if not bit(mask, value) then return false end
    end
    return true
end
function Sources.RaceAllowed(mask, raceBit, faction)
    if type(mask) ~= "number" or mask <= 0 then return true end
    if raceBit and bit(mask, raceBit) then return true end
    if raceBit then
        -- A Skyborne (or any race missing from old masks) still gets quests open to the whole faction.
        if faction == "Alliance" and fullFaction(mask, ALLIANCE_ALL) then return true end
        if faction == "Horde" and fullFaction(mask, HORDE_ALL) then return true end
        return false
    end
    local questFaction = Sources.QuestFaction(mask)
    return not questFaction or not faction or questFaction == faction
end
function Sources.RaceBit(raceID)
    return type(raceID) == "number" and raceID > 0 and 2 ^ (raceID - 1) or nil
end

local classBits = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
    WARLOCK = 256, DRUID = 1024 }
function Sources.ClassAllowed(mask, class)
    if type(mask) ~= "number" or mask <= 0 or not classBits[class] then return true end
    return bit(mask, classBits[class])
end

-- Creature name: the one you have seen in your language (GP.Names), else ForeverDB's.
local function creatureName(db, id)
    local known = GP.Names and GP.Names.Get(id)
    if known then return known end
    local npc = db.npc and db.npc[id]
    return npc and npc[1] or nil
end
Sources.CreatureName = creatureName
local function npcName(db, ref)
    if type(ref) ~= "string" then return nil end
    local kind, id = ref:sub(1, 1), tonumber(ref:sub(2))
    if kind == "c" then return creatureName(db, id) end
    local entry = kind == "o" and db.obj and db.obj[id] or nil
    return entry and entry[1] or nil
end
Sources.GiverName = npcName

-- Forever replaced some Classic quests with new ones of the same name (new IDs from 20000 up). When both turn up
-- in one place, only the Forever one counts.
local FOREVER_IDS = 20000
local function replaced(db, older, newer)
    if older >= FOREVER_IDS or newer < FOREVER_IDS then return false end
    local a, b = db.quest and db.quest[older], db.quest and db.quest[newer]
    return a and b and a[1] == b[1] or false
end
Sources.Replaced = replaced

-- AllTheThings' boss lists (Data/Dungeons.lua): creature -> instance and item -> { instance, boss }.
-- They fill in what ForeverDB lacks: bosses of the new Forever dungeons without spawn data, and boss loot
-- without recorded drops.
local function attIndex(data)
    if type(data) ~= "table" then return nil end
    if data.index then return data.index end
    local npcs, items, areas, names = {}, {}, {}, {}
    for _, instance in ipairs(data.instances or {}) do
        if instance.area then areas[instance.area] = instance end
        if instance.name then names[instance.name] = instance end
        for _, boss in ipairs(instance.bosses or {}) do
            for _, npcID in ipairs(boss.npcs or {}) do npcs[npcID] = npcs[npcID] or instance end
            for _, itemID in ipairs(boss.items or {}) do
                items[itemID] = items[itemID] or {}
                table.insert(items[itemID], { instance = instance, boss = boss })
            end
        end
    end
    data.index = { npcs = npcs, items = items, areas = areas, names = names }
    return data.index
end
Sources.AttIndex = attIndex

-- An ATT instance as a dungeon source: ForeverDB's area name where it has one (names group dungeons).
-- Forever instance IDs are map IDs (the client names them in your language); Classic ones are journal IDs.
-- Classic instance names in lower case -> map ID (ATT writes "Atal'hakkar", ForeverDB "Atal'Hakkar").
local classicByName
local function classicMap(name)
    if not classicByName then
        classicByName = {}
        for map, instance in pairs(Sources.instances) do classicByName[instance[1]:lower()] = map end
    end
    return name and classicByName[name:lower()]
end
local function attDungeon(db, instance)
    local area = instance.area
    local entry = area and ((db.dng and db.dng[area]) or (db.area and db.area[area]))
    local forever = instance.id > 1000
    local name = entry and entry[1] or instance.name
    local map = classicMap(name)
    if map then name = Sources.instances[map][1] end
    return "a" .. (area or ("i" .. instance.id)), name, instance.raid == true or (map and Sources.instances[map][2] == true) or false,
        forever, forever and instance.id or map
end

-- Where an NPC lives: a Forever dungeon (ForeverDB "ind"), a Classic instance map (spawn coordinates) or,
-- failing both, AllTheThings' boss list.
local function dungeonOf(db, npcID, att)
    local key = "c" .. npcID
    local inside = db.ind and db.ind[key]
    if inside and not notDungeons[inside[1]] then
        local area = inside[1]
        local entry = (db.dng and db.dng[area]) or (db.area and db.area[area])
        local name = entry and entry[1] or ("#" .. area)
        local known = att and (att.areas[area] or att.names[name])
        return "a" .. area, name, known and known.raid == true or false, true,
            known and known.id > 1000 and known.id or nil
    end
    local spawns = db.spw and db.spw[key]
    for _, spawn in ipairs(spawns or {}) do
        local instance = Sources.instances[spawn[1]]
        if instance then return "m" .. spawn[1], instance[1], instance[2] == true, false, spawn[1] end
    end
    local instance = att and att.npcs[npcID]
    if instance then return attDungeon(db, instance) end
    return nil
end

-- ForeverDB lists some bosses also as vendors of their own loot. A "vendor" inside a dungeon that drops the
-- item is that boss, not a vendor (real dungeon vendors such as Lokhtos do not drop what they sell).
local function bossAsVendor(db, itemID, npcID, att)
    local drops = db.drop and db.drop[itemID]
    if not drops then return false end
    for i = 1, #drops, 2 do
        if drops[i] == npcID then return dungeonOf(db, npcID, att) ~= nil end
    end
    return false
end
Sources.BossAsVendor = bossAsVendor

-- Boss name for a drop: ForeverDB's creature name, else ATT's.
local function bossName(db, npcID, boss)
    local npc = db.npc and db.npc[npcID]
    return creatureName(db, npcID) or (boss and boss.name)
end

-- Equipment the player's class can wear or wield: armor (4) and weapons (2), quality above poor.
local function equippable(item, class)
    if not item then return false end
    local quality, classID, invType = item[2], item[5], item[7]
    if (classID ~= 2 and classID ~= 4) or not GP.Planner.inventoryTypes[invType] then return false end
    if quality == 0 then return false end
    local allowed = item[9]
    if type(allowed) == "number" and allowed > 0 and classBits[class] and not bit(allowed, classBits[class]) then return false end
    return true
end

-- Returns rows: { itemID, source = "Quests"|"Dungeons", sourceID, level, name, faction, prerequisites,
-- choiceGroup, giver, zone, chance (0..1, nil unknown), estimate (0..1, ATT loot table share), boss, raid,
-- forever }. options: { class, faction, minChance (0..1), raceBit, att (GP.DungeonData) }
function Sources.Build(db, options)
    local rows = {}
    local class, faction, raceBit = options.class, options.faction, options.raceBit
    local minChance = (options.minChance or 0.02) * 10000
    local att = attIndex(options.att)
    for itemID, quests in pairs(db.rew or {}) do
        local item = db.item and db.item[itemID]
        if equippable(item, class) then
            for _, questID in ipairs(quests) do
                local superseded = false
                for _, other in ipairs(quests) do
                    if replaced(db, questID, other) then superseded = true end
                end
                local quest = not superseded and db.quest and db.quest[questID]
                local detail = db.qx and db.qx[questID] or {}
                local questFaction = Sources.QuestFaction(detail[1])
                if quest and Sources.RaceAllowed(detail[1], raceBit, faction)
                    and Sources.ClassAllowed(detail[2], class) then
                    local level = quest[2]
                    if type(level) ~= "number" or level <= 0 then level = quest[3] or item[3] end
                    local reward = db.qrw and db.qrw[questID]
                    -- Choice rewards: you pick one. Without detail data treat every reward like a choice,
                    -- so GearPilot never counts two items from the same quest.
                    local choice = true
                    if reward and type(reward[4]) == "table" then
                        for _, fixed in ipairs(reward[4]) do
                            if fixed == itemID then choice = false end
                        end
                    end
                    local giver = db.qg and db.qg[questID] and db.qg[questID][1]
                    local zoneID = type(detail[11]) == "number" and detail[11] > 0 and detail[11] or nil
                    local zone = zoneID and db.area and db.area[zoneID]
                    local dungeon = zoneID and db.dng and db.dng[zoneID]
                    rows[#rows + 1] = {
                        itemID = itemID, source = "Quests", sourceID = questID, level = level, name = quest[1],
                        minLevel = quest[3], faction = questFaction,
                        choiceGroup = choice and ("q" .. questID) or nil, giver = npcName(db, giver),
                        giverRef = giver, zone = zone and zone[1] or (dungeon and dungeon[1]) or nil,
                        dungeonQuest = dungeon and dungeon[1] or nil,
                        raidQuest = dungeon and Sources.raidNames[dungeon[1]] or nil,
                        exclusive = type(detail[5]) == "table" and detail[5] or nil,
                    }
                end
            end
        end
    end
    -- Dropped items: ForeverDB's drop table plus boss loot only AllTheThings lists.
    local dropped = {}
    for itemID in pairs(db.drop or {}) do dropped[itemID] = true end
    for itemID in pairs(att and att.items or {}) do dropped[itemID] = true end
    for itemID in pairs(dropped) do
        local list = db.drop and db.drop[itemID] or {}
        local item = db.item and db.item[itemID]
        if equippable(item, class) then
            -- One row per dungeon (by name: ForeverDB and ATT may use two areas for one dungeon).
            local best, recorded = {}, {}
            for i = 1, #list, 2 do
                local npcID, chance = list[i], list[i + 1] or 0
                local key, name, raid, forever, mapID = dungeonOf(db, npcID, att)
                -- Known rate at least minChance; unknown rate (0) only for Forever dungeons and elite bosses.
                local npc = db.npc and db.npc[npcID]
                local rank = npc and npc[5] or 0
                local boss = att and att.npcs[npcID] and true
                if key and chance > 0 then recorded[name] = true end
                local accepted = key and (chance >= minChance or (chance == 0 and (forever or rank >= 1 or boss)))
                if accepted and (not best[name] or chance > best[name].chance) then
                    best[name] = { key = key, name = name, raid = raid, forever = forever, mapID = mapID,
                        npc = npc and creatureName(db, npcID), level = npc and (npc[4] or npc[3]), chance = chance }
                end
            end
            -- Boss loot ATT knows: an unknown rate gets the boss's loot table share as estimate.
            for _, found in ipairs(att and att.items[itemID] or {}) do
                local key, name, raid, forever, mapID = attDungeon(db, found.instance)
                local estimate = 1 / math.max(1, #found.boss.items)
                local known = best[name]
                -- A recorded rate below the minimum stays out; ATT only fills in unknown rates.
                if not known and not recorded[name] then
                    best[name] = { key = key, name = name, raid = raid, forever = forever, mapID = mapID, chance = 0, estimate = estimate,
                        npc = bossName(db, found.boss.npcs[1], found.boss), level = found.instance.level }
                elseif known and known.chance == 0 then
                    known.estimate = estimate
                end
            end
            for _, source in pairs(best) do
                rows[#rows + 1] = {
                    itemID = itemID, source = "Dungeons", sourceID = source.key, level = source.level or item[3],
                    name = source.name, boss = source.npc, raid = source.raid, forever = source.forever,
                    mapID = source.mapID, chance = source.chance > 0 and source.chance / 10000 or nil,
                    estimate = source.chance == 0 and source.estimate or nil,
                }
            end
        end
    end
    -- Vendors: every equippable item a vendor sells; vendors of the other faction are left out.
    for itemID, vendors in pairs(db.vend or {}) do
        local item = db.item and db.item[itemID]
        if equippable(item, class) then
            local list = {}
            for _, npcID in ipairs(vendors) do
                local side = db.nfac and db.nfac[npcID]
                local friendly = not side or not faction or side == "AH"
                    or (faction == "Alliance" and side == "A") or (faction == "Horde" and side == "H")
                local npc = db.npc and db.npc[npcID]
                if friendly and npc and not bossAsVendor(db, itemID, npcID, att) then list[#list + 1] = { ref = "c" .. npcID, name = creatureName(db, npcID) } end
            end
            if #list > 0 then
                rows[#rows + 1] = { itemID = itemID, source = "Vendors", sourceID = "v" .. itemID, level = item[3] or 1,
                    name = list[1].name, vendors = list }
            end
        end
    end
    return rows
end

-- Crafted gear from CraftPilot's recipe catalog (CraftPilotPro.CatalogData): one row per recipe whose product
-- the class can equip. level = the product's required level.
function Sources.Crafted(catalog, db, class)
    local rows = {}
    for profession, data in pairs(catalog or {}) do
        for recipeID, recipe in pairs(type(data) == "table" and data.recipes or {}) do
            local itemID = recipe.makes
            local item = itemID and db.item and db.item[itemID]
            if equippable(item, class) then
                rows[#rows + 1] = { itemID = itemID, source = "Crafted", sourceID = profession .. ":" .. recipeID,
                    level = item[3] or 1, name = recipe.name, profession = profession, recipeID = recipeID,
                    learn = recipe.learn, forever = recipe.forever }
            end
        end
    end
    return rows
end

-- Equippable items by required level, for the auction house search.
function Sources.EquipIndex(db, class)
    local index = {}
    for itemID, item in pairs(db.item or {}) do
        if equippable(item, class) then
            local level = item[3] or 1
            index[level] = index[level] or {}
            table.insert(index[level], itemID)
        end
    end
    return index
end

-- Every source of one item, for the wishlist: quests, dungeon and world drops, vendors, world drop level and
-- (with CraftPilot's catalog) recipes. Pure Lua; options = { faction, raceBit, class, catalog }.
function Sources.ItemSources(db, itemID, options)
    options = options or {}
    local list = {}
    local att = attIndex(options.att)
    local item = db.item and db.item[itemID]
    for _, questID in ipairs(db.rew and db.rew[itemID] or {}) do
        local quest = db.quest and db.quest[questID]
        local detail = db.qx and db.qx[questID] or {}
        if quest and Sources.RaceAllowed(detail[1], options.raceBit, options.faction)
            and Sources.ClassAllowed(detail[2], options.class) then
            local superseded = false
            for _, other in ipairs(db.rew[itemID]) do
                if replaced(db, questID, other) then superseded = true end
            end
            if not superseded then
                local giver = db.qg and db.qg[questID] and db.qg[questID][1]
                local zoneID = type(detail[11]) == "number" and detail[11] > 0 and detail[11] or nil
                local zone = zoneID and db.area and db.area[zoneID]
                local dungeon = zoneID and db.dng and db.dng[zoneID]
                list[#list + 1] = { kind = "quest", questID = questID, name = quest[1], level = quest[2], giverRef = giver,
                    giver = npcName(db, giver), zone = zone and zone[1] or (dungeon and dungeon[1]) or nil,
                    dungeonQuest = dungeon and dungeon[1] or nil }
            end
        end
    end
    -- Drops: dungeons grouped (best chance per dungeon), open world mobs individually.
    local dungeons = {}
    local drops = db.drop and db.drop[itemID] or {}
    for i = 1, #drops, 2 do
        local npcID, chance = drops[i], drops[i + 1] or 0
        local npc = db.npc and db.npc[npcID]
        local key, name, raid, forever, mapID = dungeonOf(db, npcID, att)
        if key then
            local entry = dungeons[name]
            if not entry or chance > entry.rawChance then
                local new = { kind = "dungeon", key = key, name = name, raid = raid, forever = forever, mapID = mapID,
                    boss = npc and creatureName(db, npcID), level = npc and (npc[4] or npc[3]), rawChance = chance,
                    chance = chance > 0 and chance / 10000 or nil }
                if entry then
                    for k, v in pairs(new) do entry[k] = v end
                else
                    dungeons[name] = new
                    list[#list + 1] = new
                end
            end
        elseif npc then
            list[#list + 1] = { kind = "mob", npcRef = "c" .. npcID, name = creatureName(db, npcID), level = npc[4] or npc[3],
                rank = npc[5], rawChance = chance, chance = chance > 0 and chance / 10000 or nil }
        end
    end
    for _, found in ipairs(att and att.items[itemID] or {}) do
        local key, name, raid, forever, mapID = attDungeon(db, found.instance)
        local estimate = 1 / math.max(1, #found.boss.items)
        local entry = dungeons[name]
        if not entry then
            entry = { kind = "dungeon", key = key, name = name, raid = raid, forever = forever, mapID = mapID, rawChance = 0,
                boss = bossName(db, found.boss.npcs[1], found.boss), level = found.instance.level }
            dungeons[name] = entry
            list[#list + 1] = entry
        end
        if not entry.chance then entry.estimate = estimate end
    end
    for _, npcID in ipairs(db.vend and db.vend[itemID] or {}) do
        local side = db.nfac and db.nfac[npcID]
        local friendly = not side or not options.faction or side == "AH"
            or (options.faction == "Alliance" and side == "A") or (options.faction == "Horde" and side == "H")
        local npc = db.npc and db.npc[npcID]
        if friendly and npc and not bossAsVendor(db, itemID, npcID, att) then
            list[#list + 1] = { kind = "vendor", npcRef = "c" .. npcID, name = creatureName(db, npcID) }
        end
    end
    local world = db.world and db.world[itemID]
    if world then list[#list + 1] = { kind = "world", level = world } end
    for profession, data in pairs(options.catalog or {}) do
        for recipeID, recipe in pairs(type(data) == "table" and data.recipes or {}) do
            if recipe.makes == itemID then
                list[#list + 1] = { kind = "craft", profession = profession, recipeID = recipeID, name = recipe.name,
                    learn = recipe.learn }
            end
        end
    end
    -- Most useful first: quests, dungeons (by chance), vendors, crafting, mobs (by chance), world drop.
    local order = { quest = 1, dungeon = 2, vendor = 3, craft = 4, mob = 5, world = 6 }
    table.sort(list, function(a, b)
        if order[a.kind] ~= order[b.kind] then return order[a.kind] < order[b.kind] end
        return (a.rawChance or 0) > (b.rawChance or 0)
    end)
    -- Keep the list short: at most 5 open world mobs.
    local mobs, kept = 0, {}
    for _, source in ipairs(list) do
        if source.kind ~= "mob" then kept[#kept + 1] = source
        else
            mobs = mobs + 1
            if mobs <= 5 then kept[#kept + 1] = source end
        end
    end
    return kept, item
end

-- Dungeon entrance on the map (uiMap, x, y in 0..1) by dungeon name, from ForeverDB's dng table.
function Sources.Entrance(db, name, data)
    for _, entry in pairs(db.dng or {}) do
        if entry[1] == name and type(entry[3]) == "table" and entry[3][1] then
            return { world = false, map = entry[3][1], x = entry[3][2] / 1000, y = entry[3][3] / 1000 }
        end
    end
    -- AllTheThings' entrance (percent coordinates), matched by its name or ForeverDB's name for its area.
    data = data or GP.DungeonData
    for _, instance in ipairs(type(data) == "table" and data.instances or {}) do
        local entrance = instance.entrance
        if entrance and (instance.name == name or select(2, attDungeon(db, instance)) == name) then
            return { world = false, map = entrance[1], x = entrance[2] / 100, y = entrance[3] / 100 }
        end
    end
    return nil
end

-- Quest chain: every prerequisite (recursively), earliest first, ending with the quest itself.
-- preQuestSingle means "one of these": a branch you have already done wins, otherwise the first one open to
-- your race (or faction). isDone(questID) is optional.
function Sources.Chain(db, questID, faction, raceBit, isDone)
    local order, seen, parents = {}, {}, {}
    local function visit(id, depth)
        if seen[id] or depth > 20 then return end
        seen[id] = true
        parents[id] = {}
        local detail = db.qx and db.qx[id] or {}
        if type(detail[3]) == "table" then
            local chosen
            for _, pre in ipairs(detail[3]) do
                local preDetail = db.qx and db.qx[pre] or {}
                if Sources.RaceAllowed(preDetail[1], raceBit, faction) then
                    if isDone and isDone(pre) then chosen = pre break end
                    chosen = chosen or pre
                end
            end
            if chosen then table.insert(parents[id], chosen); visit(chosen, depth + 1) end
        end
        if type(detail[4]) == "table" then
            for _, pre in ipairs(detail[4]) do table.insert(parents[id], pre); visit(pre, depth + 1) end
        end
        order[#order + 1] = id
    end
    visit(questID, 0)
    local kept = {}
    for _, id in ipairs(order) do
        local superseded = false
        for _, other in ipairs(order) do
            if replaced(db, id, other) then superseded = true end
        end
        if not superseded then kept[#kept + 1] = id end
    end
    -- parents: quest -> the prerequisites it needs (for "skipped" in Planner.ChainStatus).
    return kept, parents
end

-- Where a quest giver stands: first spawn in world coordinates (spw) or a map spot (spm, 0-1000).
function Sources.Spot(db, ref)
    if type(ref) ~= "string" then return nil end
    local spawns = db.spw and db.spw[ref]
    if spawns and spawns[1] and spawns[1][2] then
        return { world = true, map = spawns[1][1], x = spawns[1][2], y = spawns[1][3] }
    end
    local spots = db.spm and db.spm[ref]
    if spots then
        for uiMap, xy in pairs(spots) do
            if xy[1] then return { world = false, map = uiMap, x = xy[1] / 1000, y = xy[2] / 1000 } end
        end
    end
    return nil
end

-- In game -----------------------------------------------------------------------------------------------------
Sources.state = "unknown" -- unknown | missing | ready
function Sources.Database()
    if type(ForeverDB) == "table" and ForeverDB.item then
        Sources.state = "ready"
        return ForeverDB
    end
    local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if load and not (InCombatLockdown and InCombatLockdown()) then pcall(load, "ForeverDB") end
    if type(ForeverDB) == "table" and ForeverDB.item then
        Sources.state = "ready"
        return ForeverDB
    end
    Sources.state = "missing"
    return nil
end

-- Dungeon catalog: every dungeon and raid GearPilot knows, with its level range (bosses and drops), bosses and
-- loot (AllTheThings), quests (AllTheThings and ForeverDB's dungeon zone) and the map ID for its local name.
-- rows: Sources.Build rows (drops and dungeon quests add names and levels). Returns list and byName.
function Sources.Catalog(db, data, rows)
    local att = attIndex(data)
    local list, byName = {}, {}
    local function get(name)
        local d = byName[name]
        if not d then
            d = { name = name, bosses = {}, quests = {}, questSeen = {} }
            byName[name] = d
            list[#list + 1] = d
        end
        return d
    end
    local function level(d, value)
        if type(value) ~= "number" or value <= 0 then return end
        d.low = math.min(d.low or value, value)
        d.high = math.max(d.high or value, value)
    end
    local function quest(d, id)
        if not d.questSeen[id] and db.quest and db.quest[id] then
            d.questSeen[id] = true
            d.quests[#d.quests + 1] = id
        end
    end
    for _, instance in ipairs(type(data) == "table" and data.instances or {}) do
        local _, name, raid, forever, mapID = attDungeon(db, instance)
        local d = get(name)
        d.raid, d.forever, d.mapID, d.area = raid, forever, d.mapID or mapID, instance.area
        d.recommended = instance.level
        for _, boss in ipairs(instance.bosses or {}) do
            d.bosses[#d.bosses + 1] = { name = bossName(db, boss.npcs[1], boss), npcs = boss.npcs, items = boss.items, rare = boss.rare }
            for _, npcID in ipairs(boss.npcs or {}) do
                local npc = db.npc and db.npc[npcID]
                -- Boss levels; very low ones (summoned helpers) are ignored.
                local minLv, maxLv = npc and npc[3], npc and (npc[4] or npc[3])
                if type(minLv) == "number" and minLv >= (instance.level or 1) - 5 then level(d, minLv); level(d, maxLv) end
            end
        end
        for _, id in ipairs(instance.quests or {}) do quest(d, id) end
    end
    for _, row in ipairs(rows or {}) do
        if row.source == "Dungeons" then
            local d = get(row.name)
            d.mapID = d.mapID or row.mapID
            d.raid = d.raid or row.raid
            d.forever = d.forever or row.forever
            level(d, row.level)
        elseif row.source == "Quests" and row.dungeonQuest and byName[row.dungeonQuest] then
            quest(byName[row.dungeonQuest], row.sourceID)
        end
    end
    for id, detail in pairs(db.qx or {}) do
        local zone = type(detail[11]) == "number" and db.dng and db.dng[detail[11]]
        if zone and byName[zone[1]] then quest(byName[zone[1]], id) end
    end
    for _, d in ipairs(list) do
        d.mapID = d.mapID or classicMap(d.name)
        if d.recommended then
            d.low = d.low and math.max(d.low, d.recommended) or d.recommended
            d.high = math.max(d.high or d.low, d.low)
        end
        d.low, d.high = d.low or 1, d.high or d.low or 1
        d.questSeen = nil
        table.sort(d.quests)
    end
    table.sort(list, function(a, b)
        if a.low ~= b.low then return a.low < b.low end
        return a.name < b.name
    end)
    return list, byName
end

-- One quest of a dungeon for the player: title, levels, giver, faction check; nil when the quest is not for
-- this character (race, class) or a Classic quest replaced by its Forever twin in the same list.
function Sources.DungeonQuest(db, questID, options, others)
    local quest = db.quest and db.quest[questID]
    if not quest then return nil end
    local detail = db.qx and db.qx[questID] or {}
    if not Sources.RaceAllowed(detail[1], options.raceBit, options.faction) or not Sources.ClassAllowed(detail[2], options.class) then
        return nil
    end
    for _, other in ipairs(others or {}) do
        if other ~= questID and replaced(db, questID, other) then return nil end
    end
    local giver = db.qg and db.qg[questID] and db.qg[questID][1]
    return { id = questID, title = quest[1], level = quest[2], minLevel = quest[3], giverRef = giver,
        giver = npcName(db, giver), prerequisites = (detail[3] or detail[4]) and true or false }
end

function Sources.Rows(class, faction, minChance, raceBit)
    -- Compared field by field (1.6.3: building a signature string on every call made garbage).
    local last = Sources.signature
    if Sources.rows and last and last[1] == class and last[2] == faction and last[3] == minChance and last[4] == raceBit then
        return Sources.rows
    end
    local signature = { class, faction, minChance, raceBit }
    local db = Sources.Database()
    if not db then return nil end
    Sources.rows = Sources.Build(db, { class = class, faction = faction, minChance = minChance, raceBit = raceBit,
        att = GP.DungeonData })
    Sources.signature = signature
    return Sources.rows
end

-- Wishlist drop hints: who drops which of the given items (byNpc) and which instance holds them (byMap, keyed
-- by the instance map ID that GetInstanceInfo returns). ForeverDB drops and AllTheThings boss loot together;
-- chance in 1/10000 (0 = unknown). Classic instances come from spawn maps, Forever dungeons from their area.
function Sources.DropIndex(db, data, ids)
    local byNpc, byMap = {}, {}
    if type(db) ~= "table" then return byNpc, byMap end
    local att = attIndex(data)
    local seenNpc, seenMap = {}, {}
    local function add(id, npcID, chance, mapID, boss)
        if npcID and not seenNpc[npcID .. ":" .. id] then
            seenNpc[npcID .. ":" .. id] = true
            byNpc[npcID] = byNpc[npcID] or {}
            table.insert(byNpc[npcID], { id = id, chance = chance })
        end
        if mapID and not seenMap[mapID .. ":" .. id] then
            seenMap[mapID .. ":" .. id] = true
            byMap[mapID] = byMap[mapID] or {}
            table.insert(byMap[mapID], { id = id, chance = chance, boss = boss })
        end
    end
    for _, id in ipairs(ids or {}) do
        local drops = db.drop and db.drop[id] or {}
        for i = 1, #drops, 2 do
            local npcID, chance = drops[i], drops[i + 1] or 0
            local npc = db.npc and db.npc[npcID]
            local _, _, _, _, mapID = dungeonOf(db, npcID, att)
            local spawns = db.spw and db.spw["c" .. npcID]
            local map = mapID or (spawns and spawns[1] and Sources.instances[spawns[1][1]] and spawns[1][1])
            add(id, npcID, chance, map, npc and creatureName(db, npcID))
        end
        for _, found in ipairs(att and att.items[id] or {}) do
            local _, _, _, _, mapID = attDungeon(db, found.instance)
            for _, npcID in ipairs(found.boss.npcs or {}) do
                add(id, npcID, 0, mapID, bossName(db, npcID, found.boss))
            end
        end
    end
    return byNpc, byMap
end

-- "12 %", an ATT estimate "ca. 20 % (estimated)" or nil when nothing is known.
function Sources.ChanceText(row)
    if row and row.chance then return ("%d %%"):format(math.floor(row.chance * 100 + .5)) end
    if row and row.estimate then return GP.L("ca. %d %% (estimated)"):format(math.floor(row.estimate * 100 + .5)) end
    return nil
end

function Sources.BuildDate()
    return type(ForeverDB) == "table" and ForeverDB.meta and ForeverDB.meta.build or nil
end

-- Localized names where the client knows them; ForeverDB names are English.
function Sources.QuestTitle(questID, fallback)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(title) == "string" and title ~= "" then return title end
        if C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
    end
    return fallback
end
function Sources.DungeonName(row)
    if row.mapID and GetRealZoneText then
        local ok, name = pcall(GetRealZoneText, row.mapID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return row.name
end
-- Map position (uiMap, x, y in 0..1) and world position of a spot. World and map conversion need the game.
function Sources.MapPoint(spot)
    if not spot then return nil end
    if not spot.world then return spot.map, spot.x, spot.y end
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local vector = CreateVector2D(spot.x, spot.y)
    local ok, uiMap, pos = pcall(C_Map.GetMapPosFromWorldPos, spot.map, vector)
    if not (ok and uiMap and pos) then return nil end
    -- The continent map comes first; the zone at that spot gives the zone name and zone coordinates.
    if C_Map.GetMapInfoAtPosition then
        local found, info = pcall(C_Map.GetMapInfoAtPosition, uiMap, pos.x, pos.y)
        if found and info and info.mapID and info.mapID ~= uiMap then
            local zoneOk, _, zonePos = pcall(C_Map.GetMapPosFromWorldPos, spot.map, vector, info.mapID)
            if zoneOk and zonePos then return info.mapID, zonePos.x, zonePos.y end
        end
    end
    return uiMap, pos.x, pos.y
end
function Sources.WorldPoint(spot)
    if not spot then return nil end
    if spot.world then return spot.map, spot.x, spot.y end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, spot.map, CreateVector2D(spot.x, spot.y))
    if ok and continent and pos then return continent, pos.x, pos.y end
    return nil
end
-- Distance in yards from the player, nil when unknown or on another continent.
function Sources.Distance(spot)
    if not (spot and UnitPosition) then return nil end
    local py, px, _, instance = UnitPosition("player")
    if not py then return nil end
    local map, x, y = Sources.WorldPoint(spot)
    if not map or map ~= instance then return nil end
    return math.sqrt((x - py) ^ 2 + (y - px) ^ 2)
end
function Sources.MapName(uiMap)
    local info = uiMap and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
    return info and info.name or nil
end

-- Classic quest <-> Forever replacement of the same name: done in either version counts as done.
function Sources.Twins(db)
    local byTitle, twins = {}, {}
    for id, quest in pairs(db.quest or {}) do
        local title = quest[1]
        if title then
            byTitle[title] = byTitle[title] or {}
            table.insert(byTitle[title], id)
        end
    end
    for _, ids in pairs(byTitle) do
        if #ids > 1 then
            for _, a in ipairs(ids) do
                for _, b in ipairs(ids) do
                    if (a < FOREVER_IDS and b >= FOREVER_IDS) or (b < FOREVER_IDS and a >= FOREVER_IDS) then
                        twins[a] = twins[a] or {}
                        table.insert(twins[a], b)
                    end
                end
            end
        end
    end
    return twins
end
local function flagged(questID)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end
function Sources.QuestDone(questID)
    if flagged(questID) then return true end
    if type(ForeverDB) == "table" and ForeverDB.quest then
        Sources.twins = Sources.twins or Sources.Twins(ForeverDB)
        for _, twin in ipairs(Sources.twins[questID] or {}) do
            if flagged(twin) then return true end
        end
    end
    return false
end
-- A quest that cannot be taken any more because its alternative (exclusiveTo) is done.
function Sources.Excluded(row)
    for _, other in ipairs(row.exclusive or {}) do
        if Sources.QuestDone(other) then return true end
    end
    return false
end
