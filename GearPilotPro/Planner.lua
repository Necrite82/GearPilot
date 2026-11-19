-- Scoring and upgrade search. Pure Lua: no game API, so tests can run it outside the game.
local _, GP = ...
local Planner = {}
GP.Planner = Planner

-- Provisional weights per point (crit, hit, dodge, parry and block per 1 %, weapon DPS per 1 DPS).
Planner.profiles = {
    { key = "melee-str", name = "Melee (strength)",
      STR = 1, AGI = 0.7, STA = 0.3, AP = 0.5, CRIT = 10, HIT = 10, DPS = 4, RDPS = 0.3, ARMOR = 0.01, DEF = 0.2 },
    { key = "melee-agi", name = "Melee (agility)",
      AGI = 1, STR = 0.6, STA = 0.3, AP = 0.5, CRIT = 10, HIT = 10, DPS = 4, RDPS = 0.4, ARMOR = 0.01 },
    { key = "ranged", name = "Ranged",
      AGI = 1, RAP = 0.5, AP = 0.4, INT = 0.3, STA = 0.3, SPI = 0.1, CRIT = 10, HIT = 10, RDPS = 5, DPS = 0.8, MP5 = 0.5 },
    { key = "caster", name = "Caster",
      SP = 1, SCHOOL = 0.6, INT = 0.4, SPI = 0.15, STA = 0.25, CRIT = 6, SCRIT = 8, HIT = 4, SHIT = 8, MP5 = 0.5, WAND = 1.5 },
    { key = "healer", name = "Healer",
      HEAL = 1, SP = 0.9, INT = 0.5, SPI = 0.4, MP5 = 1.5, STA = 0.2, CRIT = 4, SCRIT = 5, WAND = 0.3 },
    { key = "tank", name = "Tank",
      STA = 1, ARMOR = 0.05, DEF = 1.2, DODGE = 12, PARRY = 10, BLOCK = 6, BLOCKVAL = 0.3, STR = 0.6, AGI = 0.6,
      HIT = 5, DPS = 2 },
}
Planner.defaultProfile = {
    WARRIOR = "melee-str", PALADIN = "melee-str", SHAMAN = "melee-str", ROGUE = "melee-agi", DRUID = "melee-agi",
    HUNTER = "ranged", MAGE = "caster", WARLOCK = "caster", PRIEST = "caster",
}
function Planner.Profile(key)
    for _, profile in ipairs(Planner.profiles) do
        if profile.key == key then return profile end
    end
    return Planner.profiles[1]
end

Planner.slots = {
    {1, "Head"}, {2, "Neck"}, {3, "Shoulders"}, {15, "Back"}, {5, "Chest"}, {9, "Wrists"}, {10, "Hands"},
    {6, "Waist"}, {7, "Legs"}, {8, "Feet"}, {11, "Ring 1"}, {12, "Ring 2"}, {13, "Trinket 1"}, {14, "Trinket 2"},
    {16, "Main hand"}, {17, "Off hand"}, {18, "Ranged slot"},
}
Planner.slotNames = {}
for _, slot in ipairs(Planner.slots) do Planner.slotNames[slot[1]] = slot[2] end

local targetSlots = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}
Planner.targetSlots = targetSlots
-- ForeverDB stores the inventory type as a number.
Planner.inventoryTypes = {
    [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [5] = "INVTYPE_CHEST",
    [6] = "INVTYPE_WAIST", [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET", [9] = "INVTYPE_WRIST", [10] = "INVTYPE_HAND",
    [11] = "INVTYPE_FINGER", [12] = "INVTYPE_TRINKET", [13] = "INVTYPE_WEAPON", [14] = "INVTYPE_SHIELD",
    [15] = "INVTYPE_RANGED", [16] = "INVTYPE_CLOAK", [17] = "INVTYPE_2HWEAPON", [20] = "INVTYPE_ROBE",
    [21] = "INVTYPE_WEAPONMAINHAND", [22] = "INVTYPE_WEAPONOFFHAND", [23] = "INVTYPE_HOLDABLE",
    [25] = "INVTYPE_THROWN", [26] = "INVTYPE_RANGEDRIGHT", [28] = "INVTYPE_RELIC",
}

-- Classic proficiencies (Forever keeps the Classic ones). Armor: 1 cloth, 2 leather, 3 mail, 4 plate.
local classArmor = { WARRIOR = 3, PALADIN = 3, SHAMAN = 2, HUNTER = 2, ROGUE = 2, DRUID = 2, MAGE = 1, PRIEST = 1, WARLOCK = 1 }
local shields = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local relics = { PALADIN = 7, DRUID = 8, SHAMAN = 9 }
local function set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end
-- Weapon subclasses: 0/1 axe, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff, 13 fist, 15 dagger,
-- 16 thrown, 18 crossbow, 19 wand.
local weapons = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE = set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = set(4, 10, 15, 19),
    SHAMAN = set(0, 1, 4, 5, 10, 13, 15),
    MAGE = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID = set(4, 5, 10, 13, 15),
}
local function dualWield(class, level)
    return (class == "ROGUE" and level >= 10) or ((class == "WARRIOR" or class == "HUNTER") and level >= 20)
end

function Planner.CanUse(item, class, level)
    if item.classID == 4 then
        local sub = item.subclassID
        if sub == 0 or sub == nil then return true end
        if sub == 6 then return shields[class] == true end
        if sub >= 7 and sub <= 9 then return relics[class] == sub end
        local armor = classArmor[class]
        if level >= 40 and (class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" or class == "HUNTER") then
            armor = armor + 1
        end
        return armor ~= nil and sub >= 1 and sub <= armor
    elseif item.classID == 2 then
        local allowed = weapons[class]
        if not allowed or not allowed[item.subclassID] then return false end
        if item.equip == "INVTYPE_WEAPONOFFHAND" then return dualWield(class, level) end
        return true
    end
    return false
end

function Planner.Score(item, profile)
    if not item then return 0 end
    if not item.stats then return nil end
    local score = 0
    for key, value in pairs(item.stats) do
        local weight = profile[key]
        if type(weight) == "number" then score = score + weight * value end
    end
    return score
end

function Planner.Range(level, below, above)
    return math.max(1, level - below), math.min(60, level + above)
end

-- What the new item would replace in a slot and the score of that. A two-hand weapon replaces main and off hand;
-- with a two-hand weapon worn, a one-hand weapon competes against it alone and leaves the off hand empty.
local function baseline(slot, item, equipped, profile)
    local current = equipped[slot]
    if item.equip == "INVTYPE_2HWEAPON" then
        local main, off = Planner.Score(equipped[16], profile), Planner.Score(equipped[17], profile)
        if not main or not off then return nil end
        return main + off, equipped[16], equipped[17]
    end
    if slot == 17 and equipped[16] and equipped[16].equip == "INVTYPE_2HWEAPON" then return nil end
    local base = Planner.Score(current, profile)
    return base, current
end

-- candidates: { key, source, level?, choiceGroup?, item = {id, link, equip, minLevel, classID, subclassID, stats} }
-- options: { level, below, above, profile, class }
function Planner.Recommend(candidates, equipped, options)
    local low, high = Planner.Range(options.level, options.below, options.above)
    local results, groups = {}, {}
    for _, entry in ipairs(candidates) do
        local item = entry.item
        local slots = targetSlots[item.equip]
        local bag = entry.source == "Bags"
        local sourceLevel = entry.level or item.minLevel
        local inRange = bag or (sourceLevel and sourceLevel >= low and sourceLevel <= high)
        local targetLevel = bag and options.level or high
        if item.equip == "INVTYPE_WEAPON" and dualWield(options.class, targetLevel) then slots = {16, 17} end
        if slots and inRange and item.minLevel and item.minLevel <= targetLevel
            and Planner.CanUse(item, options.class, targetLevel) then
            local score = Planner.Score(item, options.profile)
            local unique = (item.equip == "INVTYPE_FINGER" or item.equip == "INVTYPE_TRINKET") and item.id
            local duplicate = unique and slots and ((equipped[slots[1]] and equipped[slots[1]].id == item.id)
                or (slots[2] and equipped[slots[2]] and equipped[slots[2]].id == item.id))
            local best
            if score and not duplicate then
                for _, slot in ipairs(slots) do
                    local base, current, second = baseline(slot, item, equipped, options.profile)
                    local worn = current and current.link and current.link == item.link
                    if base and not worn and score > base and (not best or score - base > best.gain) then
                        best = { entry = entry, item = item, slot = slot, current = current, second = second,
                            gain = score - base, score = score }
                    end
                end
            end
            if best then
                -- Quest choice rewards: only the best item of one quest, you can take just one.
                local group = entry.choiceGroup
                if group then
                    local previous = groups[group]
                    if not previous or best.gain > previous.gain then
                        if previous then previous.dropped = true end
                        groups[group] = best
                        results[#results + 1] = best
                    end
                else
                    results[#results + 1] = best
                end
            end
        end
    end
    local kept = {}
    for _, result in ipairs(results) do
        if not result.dropped then kept[#kept + 1] = result end
    end
    table.sort(kept, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.entry.key < b.entry.key
    end)
    return kept
end

-- One item against what is worn, for the item tooltip. Returns nil for items GearPilot does not score,
-- { usable = false } for items the class cannot use, otherwise the best slot with gain and percent.
function Planner.Compare(item, equipped, profile, class, level)
    local slots = item and targetSlots[item.equip]
    if not slots or not item.stats then return nil end
    if not Planner.CanUse(item, class, math.max(level, item.minLevel or 0)) then return { usable = false } end
    if item.equip == "INVTYPE_WEAPON" and dualWield(class, level) then slots = {16, 17} end
    local score = Planner.Score(item, profile)
    local best
    for _, slot in ipairs(slots) do
        local base, current = baseline(slot, item, equipped, profile)
        if current and current.link and current.link == item.link then
            return { usable = true, worn = true, slot = slot, score = score }
        end
        if base and (not best or score - base > best.gain) then
            best = { usable = true, slot = slot, gain = score - base, base = base, score = score, current = current }
        end
    end
    if best and best.base > 0 then best.percent = best.gain / best.base * 100 end
    return best
end

-- Differences between two value tables, for the detail panel.
function Planner.Diff(new, old)
    local out = {}
    local a, b = new and new.stats or {}, old and old.stats or {}
    for _, key in ipairs(GP.Stats and GP.Stats.order or {}) do
        local delta = (a[key] or 0) - (b[key] or 0)
        if math.abs(delta) > 0.001 then out[#out + 1] = { key = key, delta = delta } end
    end
    return out
end
