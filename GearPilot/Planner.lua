local _, GP = ...
local Planner = {}
GP.Planner = Planner

Planner.profiles = {
    { key = "Melee", STRENGTH = 1, AGILITY = 0.8, STAMINA = 0.5, ATTACK_POWER = 0.5, CRIT_RATING = 1, HIT_RATING = 1 },
    { key = "Caster", INTELLECT = 0.8, STAMINA = 0.5, SPELL_POWER = 1.5, CRIT_RATING = 1, HIT_RATING = 1, SPIRIT = 0.3 },
    { key = "Ranged", AGILITY = 1, STAMINA = 0.5, RANGED_ATTACK_POWER = 0.5, ATTACK_POWER = 0.5, CRIT_RATING = 1, HIT_RATING = 1 },
    { key = "Healer", INTELLECT = 1, SPIRIT = 0.7, STAMINA = 0.5, SPELL_POWER = 1.2, MANA_REGENERATION = 1.5 },
    { key = "Tank", STAMINA = 1.3, STRENGTH = 0.6, AGILITY = 0.5, DODGE_RATING = 1, PARRY_RATING = 1, DEFENSE_SKILL_RATING = 1 },
}

Planner.slots = {
    {1, "Head"}, {2, "Neck"}, {3, "Shoulders"}, {5, "Chest"}, {6, "Waist"},
    {7, "Legs"}, {8, "Feet"}, {9, "Wrists"}, {10, "Hands"}, {11, "Ring 1"},
    {12, "Ring 2"}, {13, "Trinket 1"}, {14, "Trinket 2"}, {15, "Back"},
    {16, "Main hand"}, {17, "Off hand"}, {18, "Ranged slot"},
}

local targetSlots = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3},
    INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_CLOAK = {15},
}

local classArmor = {
    WARRIOR = 3, PALADIN = 3, SHAMAN = 2, HUNTER = 2, ROGUE = 2,
    DRUID = 2, MAGE = 1, PRIEST = 1, WARLOCK = 1,
}

function Planner.ArmorAllowed(item, class, level)
    local armor = classArmor[class]
    if level >= 40 and (class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" or class == "HUNTER") then
        armor = armor + 1
    end
    return item.classID ~= 4 or item.subclassID == 0
        or (armor and item.subclassID and item.subclassID >= 1 and item.subclassID <= armor)
end

function Planner.Score(item, profile)
    if not item then return 0 end
    if not item.stats then return nil end
    local score = 0
    for key, weight in pairs(profile) do
        if key ~= "key" then
            score = score + weight * (item.stats["ITEM_MOD_" .. key .. "_SHORT"] or 0)
        end
    end
    return score
end

function Planner.Range(level, below, above)
    return math.max(1, level - below), math.min(60, level + above)
end

function Planner.Recommend(candidates, equipped, options)
    local low, high = Planner.Range(options.level, options.below, options.above)
    local results = {}
    for _, entry in ipairs(candidates) do
        local item = entry.item
        local sourceLevel = entry.level or item.minLevel
        local slots = targetSlots[item.equip]
        -- Bag upgrades can still be useful long after their required level.
        local inRange = entry.source == "Bags" or (sourceLevel and sourceLevel >= low and sourceLevel <= high)
        local targetLevel = entry.source == "Bags" and options.level or high
        if slots and inRange and item.minLevel and item.minLevel <= targetLevel
            and Planner.ArmorAllowed(item, options.class, targetLevel) then
            local score = Planner.Score(item, options.profile)
            local sameRing = item.equip == "INVTYPE_FINGER" and item.id
                and ((equipped[11] and equipped[11].id == item.id) or (equipped[12] and equipped[12].id == item.id))
            local best
            if score and not sameRing then
                for _, slot in ipairs(slots) do
                    local current = equipped[slot]
                    local base = Planner.Score(current, options.profile)
                    if base and (not current or not current.link or current.link ~= item.link)
                        and score > base and (not best or score - base > best.gain) then
                        best = { entry = entry, item = item, slot = slot, current = current, gain = score - base }
                    end
                end
            end
            if best then results[#results + 1] = best end
        end
    end
    table.sort(results, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.entry.key < b.entry.key
    end)
    return results
end
