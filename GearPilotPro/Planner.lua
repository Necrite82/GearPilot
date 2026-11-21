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
-- The player's own profile (weights edited in game or imported from Pawn / WoWSims).
Planner.custom = nil
function Planner.SetCustom(weights)
    local profile = { key = "custom", name = "Own profile" }
    for key, value in pairs(weights or {}) do
        if type(value) == "number" and value ~= 0 then profile[key] = value end
    end
    Planner.custom = profile
    return profile
end
function Planner.All()
    local list = {}
    for _, profile in ipairs(Planner.profiles) do list[#list + 1] = profile end
    if Planner.custom then list[#list + 1] = Planner.custom end
    return list
end
function Planner.Profile(key)
    if key == "custom" and Planner.custom then return Planner.custom end
    for _, profile in ipairs(Planner.profiles) do
        if profile.key == key then return profile end
    end
    return Planner.profiles[1]
end

-- Specialization -> profile (Forever has three per class; a fourth for druids is the healer).
Planner.specProfiles = {
    WARRIOR = { "melee-str", "melee-str", "tank" }, PALADIN = { "healer", "tank", "melee-str" },
    HUNTER = { "ranged", "ranged", "melee-agi" }, ROGUE = { "melee-agi", "melee-agi", "melee-agi" },
    PRIEST = { "healer", "healer", "caster" }, SHAMAN = { "caster", "melee-str", "healer" },
    MAGE = { "caster", "caster", "caster" }, WARLOCK = { "caster", "caster", "caster" },
    DRUID = { "caster", "melee-agi", "healer", "healer" },
}
-- Role and primary stat decide when the game gives them; the spec order table is the fallback. Hunters:
-- Survival (third specialization) fights in melee.
function Planner.SpecProfile(class, spec, role, primaryStat)
    if role == "TANK" then return "tank" end
    if role == "HEALER" then return "healer" end
    if role == "DAMAGER" then
        if class == "HUNTER" then return spec == 3 and "melee-agi" or "ranged" end
        if primaryStat == 1 then return "melee-str" end
        if primaryStat == 2 then return "melee-agi" end
        if primaryStat == 4 then return "caster" end
    end
    local list = Planner.specProfiles[class]
    return list and spec and list[spec] or Planner.defaultProfile[class]
end

-- Pawn scale strings, also WoWSims' Pawn export: ( Pawn: v1: "Name": Strength=1.00, Agility=0.80, ... )
Planner.pawnKeys = {
    strength = "STR", agility = "AGI", stamina = "STA", intellect = "INT", spirit = "SPI", armor = "ARMOR",
    dps = "DPS", meleedps = "DPS", rangeddps = "RDPS", wanddps = "WAND", ap = "AP", rap = "RAP",
    spelldamage = "SP", spellpower = "SP", healing = "HEAL", mp5 = "MP5", hp5 = "HP5",
    critrating = "CRIT", crit = "CRIT", hitrating = "HIT", hit = "HIT", spellcritrating = "SCRIT", spellcrit = "SCRIT",
    spellhitrating = "SHIT", spellhit = "SHIT", defenserating = "DEF", defense = "DEF", dodgerating = "DODGE",
    dodge = "DODGE", parryrating = "PARRY", parry = "PARRY", blockrating = "BLOCK", block = "BLOCK",
    blockvalue = "BLOCKVAL", hasterating = "HASTE", haste = "HASTE",
    firespelldamage = "SCHOOL_FIRE", frostspelldamage = "SCHOOL_FROST", shadowspelldamage = "SCHOOL_SHADOW",
    arcanespelldamage = "SCHOOL_ARCANE", naturespelldamage = "SCHOOL_NATURE", holyspelldamage = "SCHOOL_HOLY",
}
function Planner.ParsePawn(text)
    if type(text) ~= "string" then return nil end
    local weights, found = {}, 0
    for name, value in text:gmatch("([%a]+)%s*=%s*(%-?[%d%.]+)") do
        local key = Planner.pawnKeys[name:lower()]
        local number = tonumber(value)
        if key and number then
            weights[key] = number
            found = found + 1
        end
    end
    if found == 0 then return nil end
    -- Pawn scales often weight Strength at 1 and the rest relative to it: normalize so the largest weight
    -- of a main stat is 1 and the scores stay comparable with the built-in profiles.
    local top = 0
    for _, key in ipairs({ "STR", "AGI", "INT", "SP", "HEAL", "STA" }) do top = math.max(top, weights[key] or 0) end
    if top > 0 then
        for key, value in pairs(weights) do weights[key] = value / top end
    end
    return weights
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
-- Hunters and shamans wear mail, warriors and paladins plate only from level 40 (learned at the class trainer).
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

Planner.HEAVY_ARMOR_LEVEL = 40
function Planner.HeavyArmor(item, class)
    local base = classArmor[class]
    return item.classID == 4 and base and base < 4 and item.subclassID == base + 1
        and (class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN" or class == "HUNTER") or false
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

-- Weight of a value: school damage (SCHOOL_FIRE, ...) uses its own weight, otherwise the general SCHOOL weight.
function Planner.Weight(profile, key)
    local weight = profile and profile[key]
    if weight == nil and profile and key:sub(1, 7) == "SCHOOL_" then weight = profile.SCHOOL end
    return type(weight) == "number" and weight or nil
end

function Planner.Score(item, profile)
    if not item then return 0 end
    if not item.stats then return nil end
    local score = 0
    for key, value in pairs(item.stats) do
        local weight = Planner.Weight(profile, key)
        if weight then score = score + weight * value end
    end
    return score
end

function Planner.Range(level, below, above)
    return math.max(1, level - below), math.min(60, level + above)
end

-- What the new item would replace in a slot and the score of that. A two-hand weapon replaces main and off hand;
-- with a two-hand weapon worn, a one-hand weapon competes against it alone and leaves the off hand empty.
-- Score in a slot: an off-hand weapon deals half damage, so its weapon DPS counts half.
Planner.OFFHAND_DPS = 0.5
function Planner.SlotScore(item, profile, slot)
    local score = Planner.Score(item, profile)
    if score and slot == 17 and item and item.classID == 2 and item.stats and item.stats.DPS then
        score = score - (1 - Planner.OFFHAND_DPS) * item.stats.DPS * (profile.DPS or 0)
    end
    return score
end

local function baseline(slot, item, equipped, profile)
    local current = equipped[slot]
    if item.equip == "INVTYPE_2HWEAPON" then
        local main, off = Planner.SlotScore(equipped[16], profile, 16), Planner.SlotScore(equipped[17], profile, 17)
        if not main or not off then return nil end
        return main + off, equipped[16], equipped[17]
    end
    if slot == 17 and equipped[16] and equipped[16].equip == "INVTYPE_2HWEAPON" then return nil end
    local base = Planner.SlotScore(current, profile, slot)
    return base, current
end

local function pairedSlot(slot)
    if slot == 11 or slot == 13 then return slot + 1 end
    if slot == 12 or slot == 14 then return slot - 1 end
end
local function fitsPair(item, other)
    if not other then return true end
    if item.id and item.id == other.id and (item.unique or other.unique) then return false end
    if item.limitCategory and item.limitCategory == other.limitCategory then
        return math.min(item.limitMax or 1, other.limitMax or 1) >= 2
    end
    return true
end

-- candidates: { key, source, level?, choiceGroup?, item = {id, link, equip, minLevel, classID, subclassID, stats} }
-- options: { level, below, above, profile, class }
-- options: { level, below, above, profile, class, slotAllowed (optional: slot -> boolean),
--   windows (optional: source -> { low, high }, e.g. dungeons with their own range) }
function Planner.Recommend(candidates, equipped, options)
    local low, high = Planner.Range(options.level, options.below, options.above)
    local results, groups = {}, {}
    for _, entry in ipairs(candidates) do
        local item = entry.item
        local slots = targetSlots[item.equip]
        local bag = entry.source == "Bags"
        local sourceLevel = entry.level or item.minLevel
        local window = options.windows and options.windows[entry.source]
        local lo, hi = low, high
        if window then lo, hi = window[1], window[2] end
        local inRange = bag or (sourceLevel and sourceLevel >= lo and sourceLevel <= hi)
        local targetLevel = bag and options.level or hi
        -- Proficiencies (mail and plate from level 40, dual wield) count from the level you can really wear the
        -- item: your level now, or its required level if that is higher. Never the top of the level range.
        local wearLevel = math.max(options.level, item.minLevel or options.level)
        if item.equip == "INVTYPE_WEAPON" and dualWield(options.class, wearLevel) then slots = {16, 17} end
        if slots and inRange and item.minLevel and item.minLevel <= targetLevel
            and Planner.CanUse(item, options.class, wearLevel) then
            local score = Planner.Score(item, options.profile)
            local best
            if score then
                for _, slot in ipairs(slots) do
                    -- The slot filter applies before the best slot and the best reward of a quest are chosen.
                    local allowed = (not options.slotAllowed or options.slotAllowed(slot))
                        and fitsPair(item, equipped[pairedSlot(slot)])
                    local base, current, second = baseline(slot, item, equipped, options.profile)
                    local worn = current and current.link and current.link == item.link
                    local inSlot = Planner.SlotScore(item, options.profile, slot)
                    if allowed and base and not worn and inSlot > base and (not best or inSlot - base > best.gain) then
                        best = { entry = entry, item = item, slot = slot, current = current, second = second,
                            gain = inSlot - base, score = inSlot }
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
    local best, worn
    for _, slot in ipairs(slots) do
        local score = Planner.SlotScore(item, profile, slot)
        local base, current = baseline(slot, item, equipped, profile)
        if current and current.link and current.link == item.link then
            worn = { usable = true, worn = true, slot = slot, score = score }
        elseif base and fitsPair(item, equipped[pairedSlot(slot)]) and (not best or score - base > best.gain) then
            best = { usable = true, slot = slot, gain = score - base, base = base, score = score, current = current }
        end
    end
    -- A matching link in the first ring slot does not rule out a useful second copy in the other slot.
    if worn and (not best or best.gain <= 0) then return worn end
    if best and best.base > 0 then best.percent = best.gain / best.base * 100 end
    return best
end

-- Weapon setups: the best two-hand weapon against the best main hand + off hand (second weapon for dual
-- wielders, shield or held item otherwise) from a pool of { item, entry } (worn, bags and sources).
-- Returns { current = set, twoHand = set or nil, pair = set or nil }; a set is { main, off, mainEntry, offEntry, score }.
local mainTypes = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local offWeapons = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }
local offOther = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
function Planner.WeaponSets(pool, equipped, profile, class, level, maxLevel)
    local function usable(item)
        return item and item.stats and Planner.CanUse(item, class, math.max(level, item.minLevel or 0))
            and (item.minLevel or 0) <= (maxLevel or level)
    end
    local currentScore = (Planner.SlotScore(equipped[16], profile, 16) or 0) + (Planner.SlotScore(equipped[17], profile, 17) or 0)
    local result = { current = { main = equipped[16], off = equipped[17], score = currentScore } }
    local mains, offs = {}, {}
    local dual = dualWield(class, level)
    for _, candidate in ipairs(pool) do
        local item = candidate.item
        if usable(item) then
            if item.equip == "INVTYPE_2HWEAPON" then
                local score = Planner.SlotScore(item, profile, 16)
                if not result.twoHand or score > result.twoHand.score then
                    result.twoHand = { main = item, mainEntry = candidate.entry, score = score }
                end
            end
            if mainTypes[item.equip] then mains[#mains + 1] = candidate end
            if offOther[item.equip] or (dual and offWeapons[item.equip]) then offs[#offs + 1] = candidate end
        end
    end
    for _, m in ipairs(mains) do
        local mainScore = Planner.SlotScore(m.item, profile, 16)
        -- Without an off hand the main hand alone still counts.
        if not result.pair or mainScore > result.pair.score then
            result.pair = { main = m.item, mainEntry = m.entry, score = mainScore }
        end
        for _, o in ipairs(offs) do
            -- Two choice rewards of one quest cannot both be taken.
            local mg, og = m.entry and m.entry.choiceGroup, o.entry and o.entry.choiceGroup
            local same = o.item == m.item or (o.key and o.key == m.key) or (mg and mg == og)
            if not same then
                local score = mainScore + Planner.SlotScore(o.item, profile, 17)
                if score > result.pair.score then
                    result.pair = { main = m.item, off = o.item, mainEntry = m.entry, offEntry = o.entry, score = score }
                end
            end
        end
    end
    return result
end

-- Best in slot, computed by GearPilot from a pool of { item, entry, key } with the weights of a profile:
-- per slot the highest score; rings and trinkets the two best different items; weapons the better of the best
-- two-hand weapon and the best main + off hand (WeaponSets). Two choice rewards of one quest are never both
-- picked: the slot that loses least takes its next best item. Returns a list in slot order:
-- { slot, item, entry, score }, slots without a usable item are left out.
local function groupOf(candidate) return candidate and candidate.entry and candidate.entry.choiceGroup end
-- Slot groups for choice conflicts: both rings count as one, both trinkets, main and off hand.
local function slotGroup(slot)
    if slot == 12 then return 11 elseif slot == 14 then return 13 elseif slot == 17 then return 16 end
    return slot
end
local function selectBest(pool, profile, class, level, maxLevel, excluded)
    local best, pairs2 = {}, { [11] = {}, [13] = {} }
    local function usable(item)
        return item and item.stats and (item.minLevel or 0) <= (maxLevel or level)
            and Planner.CanUse(item, class, math.max(level, item.minLevel or 0))
    end
    local function allowed(candidate, slot)
        local group = groupOf(candidate)
        return not (group and excluded[slot] and excluded[slot][group])
    end
    local weapons = {}
    for _, candidate in ipairs(pool) do
        local item = candidate.item
        local slots = usable(item) and targetSlots[item.equip]
        if slots then
            local slot = slots[1]
            if slot == 16 or slot == 17 then
                if allowed(candidate, 16) then weapons[#weapons + 1] = candidate end
            elseif slot == 11 or slot == 13 then
                if allowed(candidate, slot) then
                    table.insert(pairs2[slot], { item = item, entry = candidate.entry, score = Planner.SlotScore(item, profile, slot) })
                end
            elseif allowed(candidate, slot) then
                local score = Planner.SlotScore(item, profile, slot)
                if not best[slot] or score > best[slot].score then
                    best[slot] = { slot = slot, item = item, entry = candidate.entry, score = score }
                end
            end
        end
    end
    for first, list in pairs(pairs2) do
        table.sort(list, function(a, b) return a.score > b.score end)
        local taken, takenGroup = {}, {}
        for _, choice in ipairs(list) do
            local id, group = choice.item.id, groupOf(choice)
            if not (id and taken[id]) and not (group and takenGroup[group]) then
                local slot = best[first] and first + 1 or first
                best[slot] = { slot = slot, item = choice.item, entry = choice.entry, score = choice.score }
                if id then taken[id] = true end
                if group then takenGroup[group] = true end
                if slot == first + 1 then break end
            end
        end
    end
    local sets = Planner.WeaponSets(weapons, {}, profile, class, level, maxLevel)
    local pick = sets.pair
    if sets.twoHand and (not pick or sets.twoHand.score >= pick.score) then pick = sets.twoHand end
    if pick then
        best[16] = { slot = 16, item = pick.main, entry = pick.mainEntry, score = Planner.SlotScore(pick.main, profile, 16) }
        if pick.off then
            best[17] = { slot = 17, item = pick.off, entry = pick.offEntry, score = Planner.SlotScore(pick.off, profile, 17) }
        end
    end
    return best
end
local function total(best)
    local sum = 0
    for _, pick in pairs(best) do sum = sum + (pick.score or 0) end
    return sum
end
-- First choice group used by two slot groups, with those slot groups; nil without a conflict.
local function conflict(best)
    local seen = {}
    for slot, pick in pairs(best) do
        local group = pick.entry and pick.entry.choiceGroup
        if group then
            local slots = seen[group] or {}
            seen[group] = slots
            local key = slotGroup(slot)
            local known = false
            for _, other in ipairs(slots) do if other == key then known = true end end
            if not known then slots[#slots + 1] = key end
            if #slots > 1 then return group, slots end
        end
    end
    return nil
end
function Planner.BestInSlot(pool, profile, class, level, maxLevel)
    local excluded = {}
    local best = selectBest(pool, profile, class, level, maxLevel, excluded)
    for _ = 1, 30 do
        local group, slots = conflict(best)
        if not group then break end
        -- Leave the group out of the slot where that costs least.
        local chosen, chosenBest, chosenTotal
        for _, slot in ipairs(slots) do
            excluded[slot] = excluded[slot] or {}
            excluded[slot][group] = true
            local trial = selectBest(pool, profile, class, level, maxLevel, excluded)
            local sum = total(trial)
            if not chosenTotal or sum > chosenTotal then chosen, chosenBest, chosenTotal = slot, trial, sum end
            excluded[slot][group] = nil
        end
        excluded[chosen][group] = true
        best = chosenBest
    end
    local list = {}
    for _, slot in ipairs(Planner.slots) do
        if best[slot[1]] then list[#list + 1] = best[slot[1]] end
    end
    return list
end

-- Profile weights as text, for caches that depend on them.
function Planner.Signature(profile)
    local keys = {}
    for key, value in pairs(profile or {}) do
        if type(value) == "number" then keys[#keys + 1] = key .. "=" .. value end
    end
    table.sort(keys)
    return (profile and profile.key or "") .. ":" .. table.concat(keys, ",")
end

-- Wishlist text for sharing: "GP1:" then item IDs separated by commas, "!" after the ID marks a goal.
function Planner.ExportWishlist(items)
    local ids = {}
    for id in pairs(items) do ids[#ids + 1] = id end
    table.sort(ids)
    local parts = {}
    for _, id in ipairs(ids) do parts[#parts + 1] = id .. (items[id].goal and "!" or "") end
    return "GP1:" .. table.concat(parts, ",")
end
function Planner.ImportWishlist(text)
    if type(text) ~= "string" then return nil end
    local body = text:match("GP1:([%d!,%s]+)")
    if not body then return nil end
    local items, count = {}, 0
    for id, goal in body:gmatch("(%d+)(!?)") do
        items[tonumber(id)] = { goal = goal == "!" }
        count = count + 1
    end
    return count > 0 and items or nil
end

-- Grey quests: Classic's rule for the highest quest level that gives (almost) no experience.
function Planner.GreyLevel(level)
    if level <= 5 then return 0 end
    if level <= 39 then return level - 5 - math.floor(level / 10) end
    if level <= 59 then return level - 1 - math.floor(level / 5) end
    return level - 9
end
function Planner.IsGrey(questLevel, playerLevel)
    return type(questLevel) == "number" and questLevel > 0 and questLevel <= Planner.GreyLevel(playerLevel)
end

-- Chain status: a step that is not done counts as skipped (breadcrumbs, optional quests) when a done or
-- accepted step builds on it. With step.pre (the prerequisites of each step, from Sources.Chain) only the
-- real predecessors of your progress count, so an independent required quest stays open; without it every
-- step before the last progress counts. Marks step.skipped; returns done count (skipped included), next index
-- and whether the chain is begun.
function Planner.ChainStatus(steps)
    local lastProgress, byID, graph = 0, {}, true
    for i, step in ipairs(steps) do
        if step.done or step.active then lastProgress = i end
        if step.id then byID[step.id] = step end
        if type(step.pre) ~= "table" then graph = false end
    end
    local behind = {}
    if graph then
        local function mark(step, depth)
            if depth > 30 then return end
            for _, id in ipairs(step.pre) do
                if not behind[id] then
                    behind[id] = true
                    if byID[id] then mark(byID[id], depth + 1) end
                end
            end
        end
        for _, step in ipairs(steps) do
            if step.done or step.active then mark(step, 0) end
        end
    end
    local done, nextIndex = 0, nil
    for i, step in ipairs(steps) do
        local before = graph and behind[step.id] or (not graph and i < lastProgress)
        step.skipped = not step.done and not step.active and before or nil
        if step.done or step.skipped then done = done + 1
        elseif not step.active and not nextIndex then nextIndex = i end
    end
    return done, nextIndex, lastProgress > 0
end

-- Quest upgrades by zone: one entry per zone with the summed gain, best first.
function Planner.ByZone(results)
    local zones, list = {}, {}
    for _, result in ipairs(results) do
        local row = result.entry.row
        local zone = row and row.zone or "?"
        local entry = zones[zone]
        if not entry then
            entry = { key = "zone:" .. zone, zone = zone, results = {}, gain = 0 }
            zones[zone] = entry
            list[#list + 1] = entry
        end
        entry.results[#entry.results + 1] = result
        entry.gain = entry.gain + result.gain
    end
    table.sort(list, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.zone < b.zone
    end)
    return list
end

-- Dungeon upgrades: per dungeon the expected gain of one run (gain x drop chance; an unknown chance counts
-- with its loot table estimate or UNKNOWN_CHANCE and is marked), its bosses and the dungeon quests with an upgrade.
Planner.UNKNOWN_CHANCE = 0.1
function Planner.ByDungeon(dropResults, questResults)
    local dungeons, list = {}, {}
    for _, result in ipairs(dropResults) do
        local row = result.entry.row
        local entry = dungeons[row.name]
        if not entry then
            entry = { key = "dungeon:" .. row.name, name = row.name, row = row, results = {}, quests = {}, expected = 0,
                unknown = 0, low = row.level, high = row.level }
            dungeons[row.name] = entry
            list[#list + 1] = entry
        end
        entry.results[#entry.results + 1] = result
        entry.expected = entry.expected + result.gain * (row.chance or row.estimate or Planner.UNKNOWN_CHANCE)
        if not row.chance and not row.estimate then entry.unknown = entry.unknown + 1 end
        if not row.chance and row.estimate then entry.estimated = (entry.estimated or 0) + 1 end
        entry.low = math.min(entry.low, row.level)
        entry.high = math.max(entry.high, row.level)
    end
    for _, result in ipairs(questResults or {}) do
        local row = result.entry.row
        local name = row.dungeonQuest
        if name then
            local entry = dungeons[name]
            if not entry then
                -- A dungeon with only a quest upgrade is still worth the trip.
                entry = { key = "dungeon:" .. name, name = name, row = { name = name, level = row.level }, results = {},
                    quests = {}, expected = 0, unknown = 0, low = row.level, high = row.level }
                dungeons[name] = entry
                list[#list + 1] = entry
            end
            entry.quests[#entry.quests + 1] = result
            entry.expected = entry.expected + result.gain
        end
    end
    table.sort(list, function(a, b)
        if a.expected ~= b.expected then return a.expected > b.expected end
        return a.name < b.name
    end)
    return list
end

-- Bag items worth getting rid of: gear the class cannot use, or that loses against what you wear in every
-- slot it fits. Items another addon reserves (CraftPilot plans) are kept.
function Planner.Clutter(bagItems, equipped, profile, class, level, reserved)
    local list = {}
    for _, entry in ipairs(bagItems) do
        local item = entry.item
        local tool = GP.Stats and GP.Stats.IsTool and GP.Stats.IsTool(item)
        if not (reserved and item.id and reserved[item.id]) and not tool then
            local result = Planner.Compare(item, equipped, profile, class, level)
            if result and not result.worn then
                local reason
                if result.usable == false then
                    reason = "unusable"
                elseif result.gain and result.gain < 0 and (item.minLevel or 0) <= level then
                    reason = "worse"
                end
                if reason then
                    list[#list + 1] = { key = entry.key, entry = entry, item = item, reason = reason,
                        gain = result.gain, percent = result.percent, slot = result.slot }
                end
            end
        end
    end
    table.sort(list, function(a, b) return (a.item.sellPrice or 0) > (b.item.sellPrice or 0) end)
    return list
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
