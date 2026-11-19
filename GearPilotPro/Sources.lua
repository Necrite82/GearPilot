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
local classBits = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
    WARLOCK = 256, DRUID = 1024 }
function Sources.ClassAllowed(mask, class)
    if type(mask) ~= "number" or mask <= 0 or not classBits[class] then return true end
    return bit(mask, classBits[class])
end

local function npcName(db, ref)
    if type(ref) ~= "string" then return nil end
    local kind, id = ref:sub(1, 1), tonumber(ref:sub(2))
    local entry = kind == "c" and db.npc and db.npc[id] or kind == "o" and db.obj and db.obj[id] or nil
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

-- Where an NPC lives: a Forever dungeon (ForeverDB "ind") or a Classic instance map (spawn coordinates).
local function dungeonOf(db, npcID)
    local key = "c" .. npcID
    local inside = db.ind and db.ind[key]
    if inside and not notDungeons[inside[1]] then
        local area = inside[1]
        local entry = (db.dng and db.dng[area]) or (db.area and db.area[area])
        return "a" .. area, entry and entry[1] or ("#" .. area), false, true
    end
    local spawns = db.spw and db.spw[key]
    for _, spawn in ipairs(spawns or {}) do
        local instance = Sources.instances[spawn[1]]
        if instance then return "m" .. spawn[1], instance[1], instance[2] == true, false, spawn[1] end
    end
    return nil
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
-- choiceGroup, giver, zone, chance (0..1, nil unknown), boss, raid, forever }.
-- options: { class, faction, minChance (0..1) }
function Sources.Build(db, options)
    local rows = {}
    local class, faction = options.class, options.faction
    local minChance = (options.minChance or 0.02) * 10000
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
                if quest and (not questFaction or not faction or questFaction == faction)
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
                    local prerequisites = {}
                    for _, list in ipairs({detail[3], detail[4]}) do
                        if type(list) == "table" then
                            for _, id in ipairs(list) do prerequisites[#prerequisites + 1] = id end
                        end
                    end
                    local giver = db.qg and db.qg[questID] and db.qg[questID][1]
                    local zoneID = type(detail[11]) == "number" and detail[11] > 0 and detail[11] or nil
                    local zone = zoneID and db.area and db.area[zoneID]
                    local dungeon = zoneID and db.dng and db.dng[zoneID]
                    rows[#rows + 1] = {
                        itemID = itemID, source = "Quests", sourceID = questID, level = level, name = quest[1],
                        minLevel = quest[3], faction = questFaction, prerequisites = prerequisites,
                        choiceGroup = choice and ("q" .. questID) or nil, giver = npcName(db, giver),
                        giverRef = giver, zone = zone and zone[1] or (dungeon and dungeon[1]) or nil,
                        dungeonQuest = dungeon and dungeon[1] or nil,
                    }
                end
            end
        end
    end
    for itemID, list in pairs(db.drop or {}) do
        local item = db.item and db.item[itemID]
        if equippable(item, class) then
            local best = {}
            for i = 1, #list, 2 do
                local npcID, chance = list[i], list[i + 1] or 0
                local key, name, raid, forever, mapID = dungeonOf(db, npcID)
                -- Known rate at least minChance; unknown rate (0) only for Forever dungeons and elite bosses.
                local npc = db.npc and db.npc[npcID]
                local rank = npc and npc[5] or 0
                local accepted = key and (chance >= minChance or (chance == 0 and (forever or rank >= 1)))
                if accepted and (not best[key] or chance > best[key].chance) then
                    best[key] = { key = key, name = name, raid = raid, forever = forever, mapID = mapID,
                        npc = npc and npc[1], level = npc and (npc[4] or npc[3]), chance = chance }
                end
            end
            for _, source in pairs(best) do
                rows[#rows + 1] = {
                    itemID = itemID, source = "Dungeons", sourceID = source.key, level = source.level or item[3],
                    name = source.name, boss = source.npc, raid = source.raid, forever = source.forever,
                    mapID = source.mapID, chance = source.chance > 0 and source.chance / 10000 or nil,
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
                if friendly and npc then list[#list + 1] = { ref = "c" .. npcID, name = npc[1] } end
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

-- Quest chain: every prerequisite (recursively), earliest first, ending with the quest itself.
-- preQuestSingle means "one of these": the first one whose faction fits is taken.
function Sources.Chain(db, questID, faction)
    local order, seen = {}, {}
    local function visit(id, depth)
        if seen[id] or depth > 20 then return end
        seen[id] = true
        local detail = db.qx and db.qx[id] or {}
        if type(detail[3]) == "table" then
            for _, pre in ipairs(detail[3]) do
                local preDetail = db.qx and db.qx[pre] or {}
                local preFaction = Sources.QuestFaction(preDetail[1])
                if not preFaction or not faction or preFaction == faction then
                    visit(pre, depth + 1)
                    break
                end
            end
        end
        if type(detail[4]) == "table" then
            for _, pre in ipairs(detail[4]) do visit(pre, depth + 1) end
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
    return kept
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

function Sources.Rows(class, faction, minChance)
    local signature = table.concat({ class or "", faction or "", tostring(minChance) }, ":")
    if Sources.rows and Sources.signature == signature then return Sources.rows end
    local db = Sources.Database()
    if not db then return nil end
    Sources.rows = Sources.Build(db, { class = class, faction = faction, minChance = minChance })
    Sources.signature = signature
    return Sources.rows
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
    local ok, uiMap, pos = pcall(C_Map.GetMapPosFromWorldPos, spot.map, CreateVector2D(spot.x, spot.y))
    if ok and uiMap and pos then return uiMap, pos.x, pos.y end
    return nil
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

function Sources.QuestDone(questID)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end
