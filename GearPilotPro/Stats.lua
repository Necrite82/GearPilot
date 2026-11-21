-- Item values for scoring. The game's item stats miss most caster, healer and hunter values on Forever
-- (spell power, healing, mana per 5, crit and hit chance are "Equip:" lines), so the tooltip is read too.
local _, GP = ...
local Stats = {}
GP.Stats = Stats

-- Game stat keys -> GearPilot keys. Several client keys can mean the same value.
Stats.keys = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SP",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SCRIT",
    ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "HIT",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "HIT", ITEM_MOD_HIT_SPELL_RATING_SHORT = "SHIT",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL", ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS", RESISTANCE0_NAME = "ARMOR",
}

-- Rating points per 1 % at level 60 (the rate the client uses for ratings on Classic items).
Stats.ratingPerPercent = { CRIT = 14, SCRIT = 14, HIT = 10, SHIT = 8, DODGE = 12, PARRY = 20, BLOCK = 5 }

-- Lines that are not permanent item values.
local skip = { "use:", "benutzen:", "chance on hit", "trefferchance:", "bei treffer", "set:", "cooldown", "abklingzeit" }
-- Spell school words -> GearPilot key; each school keeps its own key so a fire scale does not count frost.
local schools = {
    { "fire", "SCHOOL_FIRE" }, { "feuer", "SCHOOL_FIRE" }, { "frost", "SCHOOL_FROST" },
    { "shadow", "SCHOOL_SHADOW" }, { "schatten", "SCHOOL_SHADOW" }, { "arcane", "SCHOOL_ARCANE" }, { "arkan", "SCHOOL_ARCANE" },
    { "nature", "SCHOOL_NATURE" }, { "natur", "SCHOOL_NATURE" }, { "holy", "SCHOOL_HOLY" }, { "heilig", "SCHOOL_HOLY" },
}
Stats.schoolKeys = { "SCHOOL_FIRE", "SCHOOL_FROST", "SCHOOL_SHADOW", "SCHOOL_ARCANE", "SCHOOL_NATURE", "SCHOOL_HOLY" }

local function has(text, ...)
    for i = 1, select("#", ...) do
        if text:find(select(i, ...), 1, true) then return true end
    end
    return false
end

-- One tooltip line -> key, value. English and German client texts; unknown lines give nil.
function Stats.ParseLine(line)
    if type(line) ~= "string" then return nil end
    local text = line:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for _, word in ipairs(skip) do
        if text:find(word, 1, true) then return nil end
    end
    -- "per 5 sec." / "alle 5 Sek.": the 5 is not the value.
    local number = text:gsub("5 se[ck]", ""):match("(%d+[%.,]?%d*)")
    if not number then return nil end
    local value = tonumber((number:gsub(",", ".")))
    if not value or value <= 0 then return nil end
    if has(text, "mana") and has(text, "5 sec", "5 sek") then return "MP5", value end
    if has(text, "health", "gesundheit", "leben") and has(text, "5 sec", "5 sek") then return "HP5", value end
    local healing = has(text, "healing", "heilung")
    local damage = has(text, "damage", "schaden")
    local spells = has(text, "spell", "zauber", "magic", "magisch")
    if healing and damage then return "SP", value end
    if healing then return "HEAL", value end
    if spells and damage then
        for _, school in ipairs(schools) do
            if text:find(school[1], 1, true) then return school[2], value end
        end
        return "SP", value
    end
    if has(text, "ranged attack power", "distanzangriffskraft", "fernkampfangriffskraft") then return "RAP", value end
    if has(text, "attack power", "angriffskraft") then return "AP", value end
    if has(text, "critical", "kritisch") then return spells and "SCRIT" or "CRIT", value end
    if has(text, "chance to hit", "trefferchance", "zu treffen", "hit chance") then return spells and "SHIT" or "HIT", value end
    if has(text, "defense", "verteidigung") then return "DEF", value end
    if has(text, "dodge", "ausweichen") then return "DODGE", value end
    if has(text, "parry", "parieren") then return "PARRY", value end
    if has(text, "block value", "blockwert") then return "BLOCKVAL", value end
    if has(text, "block", "blocken") then return "BLOCK", value end
    return nil
end

-- Game stats plus tooltip lines -> one table of GearPilot keys. Tooltip values only fill keys the game stats
-- do not already have, so nothing is counted twice. Weapon DPS is split: ranged weapons and wands get their
-- own keys because they matter very differently to hunters, casters and melee.
function Stats.Combine(raw, lines, item)
    local out = {}
    for key, value in pairs(raw or {}) do
        local mapped = Stats.keys[key]
        if mapped and type(value) == "number" then out[mapped] = (out[mapped] or 0) + value end
    end
    local fromTip = {}
    for _, line in ipairs(lines or {}) do
        local key, value = Stats.ParseLine(line)
        if key then fromTip[key] = (fromTip[key] or 0) + value end
    end
    for key, value in pairs(fromTip) do
        if not out[key] or out[key] == 0 then out[key] = value end
    end
    -- Crit, hit, dodge, parry and block count per 1 %. The Forever client's item stats give these as ratings
    -- (an item with "+1 % crit" says 14), the tooltip says the percent: the tooltip wins; a rating alone is
    -- converted at the level 60 rate.
    for key, rate in pairs(Stats.ratingPerPercent) do
        if fromTip[key] then
            out[key] = fromTip[key]
        elseif out[key] and out[key] > 3 then
            out[key] = out[key] / rate
        end
    end
    if out.DPS and item then
        local equip = item.equip
        if equip == "INVTYPE_RANGEDRIGHT" and item.subclassID == 19 then
            out.WAND, out.DPS = out.DPS, nil
        elseif equip == "INVTYPE_RANGED" or equip == "INVTYPE_RANGEDRIGHT" or equip == "INVTYPE_THROWN" then
            out.RDPS, out.DPS = out.DPS, nil
        end
    end
    return out
end

local function tooltipLines(link)
    local lines = {}
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return lines end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return lines end
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if type(text) == "string" then lines[#lines + 1] = text end
    end
    return lines
end

-- Rings and trinkets may be worn twice unless the item itself (or its equip category) limits them.
-- GetItemUniqueness returns category/max; GetItemUniquenessByID also reports ownership-unique items.
function Stats.ItemLimits(ref)
    local unique, category, maximum
    if C_Item and type(C_Item.GetItemUniquenessByID) == "function" then
        local ok, isUnique, _, count, id = pcall(C_Item.GetItemUniquenessByID, ref)
        if ok then
            if type(isUnique) == "boolean" then unique = isUnique end
            if type(id) == "number" and id > 0 then category, maximum = id, count end
        end
    end
    if C_Item and type(C_Item.GetItemUniqueness) == "function" then
        local ok, id, count = pcall(C_Item.GetItemUniqueness, ref)
        if ok and type(id) == "number" and id > 0 then category, maximum = id, count end
    end
    -- Older clients can lack both APIs. The localized tooltip still states the item's restriction.
    if unique == nil and not category then
        for _, line in ipairs(tooltipLines(ref)) do
            local text = line:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if text:match("^unique") or text:match("^einzigartig") then
                unique = (tonumber(text:match("%((%d+)%)")) or 1) == 1
                break
            end
        end
    end
    return unique == true, category, type(maximum) == "number" and maximum or nil
end

-- Profession tools and profession gear: never "can go", even when your class cannot wield them.
-- Known tools by ID, tool names (EN/DE), and tooltip lines naming a profession ("Requires Engineering",
-- "Fishing +5", "Angeln um 5 erhöht").
Stats.toolIDs = {
    [2901] = true, [7005] = true, [5956] = true, [6219] = true, [10498] = true, [9149] = true, [778] = true,
    [756] = true, [1959] = true, [20723] = true, [6256] = true, [6365] = true, [6366] = true, [6367] = true,
    [12225] = true, [19022] = true, [19970] = true, [12709] = true, [19901] = true,
}
local toolNames = { "fishing pole", "mining pick", "skinning knife", "blacksmith hammer", "arclight spanner",
    "angelrute", "spitzhacke", "kürschnermesser", "schmiedehammer", "bogenlicht" }
Stats.professions = { "fishing", "mining", "herbalism", "skinning", "blacksmithing", "engineering", "enchanting",
    "leatherworking", "tailoring", "alchemy", "cooking", "first aid", "angeln", "bergbau", "kräuterkunde",
    "kürschnerei", "schmiedekunst", "ingenieurskunst", "verzauberkunst", "lederverarbeitung", "schneiderei",
    "alchemie", "kochkunst", "erste hilfe" }
function Stats.IsToolText(name, lines)
    local lower = (name or ""):lower()
    for _, pattern in ipairs(toolNames) do
        if lower:find(pattern, 1, true) then return true end
    end
    for _, line in ipairs(lines or {}) do
        local text = line:lower()
        for _, profession in ipairs(Stats.professions) do
            if text:find(profession, 1, true) and (text:find("requires", 1, true) or text:find("benötigt", 1, true)
                or text:find("%d") ) then
                return true
            end
        end
    end
    return false
end
local tools = {}
function Stats.IsTool(item)
    if not item then return false end
    if item.id and Stats.toolIDs[item.id] then return true end
    if item.classID == 2 and item.subclassID == 20 then return true end -- fishing poles
    local key = item.link or item.id
    if key == nil then return false end
    if tools[key] == nil then tools[key] = Stats.IsToolText(item.name, item.link and tooltipLines(item.link) or {}) end
    return tools[key]
end

local cache = {}
function Stats.ClearCache() cache = {} end
function Stats.Read(link, item)
    if not link then return nil end
    if cache[link] then return cache[link] end
    local raw = C_Item.GetItemStats and C_Item.GetItemStats(link)
    if not raw then return nil end
    local values = Stats.Combine(raw, tooltipLines(link), item)
    Stats.misses = (Stats.misses or 0) + 1
    cache[link] = values
    return values
end

-- Display order and names for the comparison in the detail panel.
Stats.order = {
    "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "SP", "HEAL", "SCHOOL", "SCHOOL_FIRE", "SCHOOL_FROST",
    "SCHOOL_SHADOW", "SCHOOL_ARCANE", "SCHOOL_NATURE", "SCHOOL_HOLY", "MP5", "CRIT", "SCRIT",
    "HIT", "SHIT", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR", "DPS", "RDPS", "WAND", "HASTE", "HP5",
}
Stats.names = {
    STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit",
    AP = "Attack power", RAP = "Ranged attack power", SP = "Spell damage and healing", HEAL = "Healing",
    SCHOOL = "School spell damage", SCHOOL_FIRE = "Fire spell damage", SCHOOL_FROST = "Frost spell damage",
    SCHOOL_SHADOW = "Shadow spell damage", SCHOOL_ARCANE = "Arcane spell damage", SCHOOL_NATURE = "Nature spell damage",
    SCHOOL_HOLY = "Holy spell damage", MP5 = "Mana per 5 sec.", CRIT = "Critical strike %", SCRIT = "Spell critical strike %",
    HIT = "Hit %", SHIT = "Spell hit %", DEF = "Defense", DODGE = "Dodge %", PARRY = "Parry %", BLOCK = "Block %",
    BLOCKVAL = "Block value", ARMOR = "Armor", DPS = "Weapon DPS", RDPS = "Ranged weapon DPS", WAND = "Wand DPS",
    HASTE = "Haste", HP5 = "Health per 5 sec.",
}
