-- Offline checks: lua5.1 tests/run.lua
local GP = {}
for _, file in ipairs({ "Stats", "Planner", "Sources" }) do
    assert(loadfile("GearPilotPro/" .. file .. ".lua"))("GearPilotPro", GP)
end
local P, St, S = GP.Planner, GP.Stats, GP.Sources

-- Tooltip lines (English and German) ------------------------------------------------------------------------
local cases = {
    { "Equip: Increases damage and healing done by magical spells and effects by up to 12.", "SP", 12 },
    { "Anlegen: Erhöht durch sämtliche Zauber und magische Effekte verursachten Schaden und Heilung um bis zu 12.", "SP", 12 },
    { "Equip: Increases healing done by spells and effects by up to 22.", "HEAL", 22 },
    { "Anlegen: Erhöht durch Zauber und Effekte verursachte Heilung um bis zu 22.", "HEAL", 22 },
    { "Restores +4 mana per 5 sec.", "MP5", 4 },
    { "Anlegen: Stellt alle 5 Sek. 4 Mana wieder her.", "MP5", 4 },
    { "Equip: Improves your chance to get a critical strike by 1%.", "CRIT", 1 },
    { "Anlegen: Erhöht Eure Chance, einen kritischen Treffer zu erzielen, um 1%.", "CRIT", 1 },
    { "Equip: Improves your chance to get a critical strike with spells by 1%.", "SCRIT", 1 },
    { "Anlegen: Erhöht Eure Chance, einen kritischen Treffer durch Zauber zu erzielen, um 1%.", "SCRIT", 1 },
    { "Equip: Improves your chance to hit by 1%.", "HIT", 1 },
    { "Anlegen: Erhöht Eure Chance, mit Nahkampf- und Distanzangriffen zu treffen, um 1%.", "HIT", 1 },
    { "Equip: Improves your chance to hit with spells by 1%.", "SHIT", 1 },
    { "Equip: +24 ranged Attack Power.", "RAP", 24 },
    { "Anlegen: +24 Distanzangriffskraft.", "RAP", 24 },
    { "Equip: +20 Attack Power.", "AP", 20 },
    { "Equip: Increases damage done by Fire spells and effects by up to 9.", "SCHOOL", 9 },
    { "Use: Restores 375 to 625 mana.", nil },
    { "Chance on hit: Blasts your enemy for 30 Fire damage.", nil },
    { "11 - 21 Damage", nil },
    { "(8.2 damage per second)", nil },
    { "Requires Level 20", nil },
    { "Durability 30 / 30", nil },
}
for _, case in ipairs(cases) do
    local key, value = St.ParseLine(case[1])
    assert(key == case[2], ("%s -> %s, expected %s"):format(case[1], tostring(key), tostring(case[2])))
    if case[3] then assert(value == case[3], case[1]) end
end
local combined = St.Combine({ ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPELL_POWER_SHORT = 10 },
    { "Equip: Increases damage and healing done by magical spells and effects by up to 10.", "Restores 3 mana per 5 sec." })
assert(combined.INT == 5 and combined.SP == 10 and combined.MP5 == 3, "tooltip values must not double game stats")
local wand = St.Combine({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 }, {}, { equip = "INVTYPE_RANGEDRIGHT", subclassID = 19 })
assert(wand.WAND == 12 and not wand.DPS)
local bow = St.Combine({ ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 }, {}, { equip = "INVTYPE_RANGED", subclassID = 2 })
assert(bow.RDPS == 9 and not bow.DPS)

-- Planner ----------------------------------------------------------------------------------------------------------
local function item(id, stats, minLevel, equip, classID, subclass)
    return { id = id, link = "item:" .. id, minLevel = minLevel or 10, equip = equip or "INVTYPE_CHEST",
        classID = classID or 4, subclassID = subclass or 2, stats = stats }
end
local function row(key, source, level, gear, group)
    return { key = key, source = source, level = level, item = gear, choiceGroup = group }
end
local melee = P.Profile("melee-agi")
local opts = { level = 20, below = 1, above = 2, profile = melee, class = "ROGUE" }
local equipped = { [5] = item(1, { AGI = 4 }) }
local results = P.Recommend({
    row("old bag item", "Bags", nil, item(2, { AGI = 7 })),
    row("upcoming quest", "Quests", 22, item(3, { AGI = 10 }, 22)),
    row("below range", "Quests", 18, item(4, { AGI = 100 })),
    row("above range", "Dungeons", 23, item(5, { AGI = 100 })),
    row("can't equip yet", "Quests", 22, item(6, { AGI = 100 }, 23)),
    row("wrong armor", "Bags", nil, item(7, { AGI = 100 }, 10, nil, 4, 3)),
    row("weaker", "Bags", nil, item(8, { AGI = 3 })),
}, equipped, opts)
assert(#results == 2 and results[1].entry.key == "upcoming quest" and results[1].gain == 6)
assert(results[2].entry.key == "old bag item" and results[2].gain == 3)

-- Choice rewards: only the best item of one quest.
local choice = P.Recommend({
    row("a", "Quests", 20, item(10, { AGI = 6 }), "q1"),
    row("b", "Quests", 20, item(11, { AGI = 9 }, 10, "INVTYPE_LEGS"), "q1"),
    row("c", "Quests", 20, item(12, { AGI = 5 }, 10, "INVTYPE_FEET"), "q2"),
}, {}, opts)
assert(#choice == 2 and choice[1].entry.key == "b" and choice[2].entry.key == "c", "one item per choice quest")

-- Weapons: casters get wands and staves but not axes; two-hand weapon vs main and off hand.
local caster = { level = 20, below = 2, above = 2, profile = P.Profile("caster"), class = "MAGE" }
local magic = P.Recommend({
    row("wand", "Bags", nil, item(20, { WAND = 10, INT = 2 }, 15, "INVTYPE_RANGEDRIGHT", 2, 19)),
    row("axe", "Bags", nil, item(21, { STR = 20 }, 15, "INVTYPE_2HWEAPON", 2, 1)),
    row("staff", "Bags", nil, item(22, { SP = 12, INT = 5 }, 15, "INVTYPE_2HWEAPON", 2, 10)),
}, { [16] = item(30, { SP = 4 }, 10, "INVTYPE_WEAPON", 2, 15), [17] = item(31, { INT = 4 }, 10, "INVTYPE_HOLDABLE", 4, 0) }, caster)
assert(#magic == 2, "the axe is not usable by a mage")
local staff
for _, r in ipairs(magic) do if r.entry.key == "staff" then staff = r end end
assert(staff and math.abs(staff.gain - (12 + 5 * 0.4 - 4 - 4 * 0.4)) < 1e-6, "two-hand weapon vs main and off hand")

local hunter = { level = 30, below = 2, above = 2, profile = P.Profile("ranged"), class = "HUNTER" }
local bowRows = P.Recommend({ row("bow", "Bags", nil, item(40, { RDPS = 12, AGI = 3 }, 25, "INVTYPE_RANGED", 2, 2)) },
    { [18] = item(41, { RDPS = 8 }, 20, "INVTYPE_RANGED", 2, 2) }, hunter)
assert(#bowRows == 1 and bowRows[1].slot == 18 and bowRows[1].gain == 4 * 5 + 3)

-- Healer values: healing and mana per 5 count.
local healer = { level = 30, below = 2, above = 2, profile = P.Profile("healer"), class = "PRIEST" }
local heal = P.Recommend({ row("robe", "Bags", nil, item(45, { HEAL = 20, MP5 = 4 }, 25, "INVTYPE_ROBE", 4, 1)) },
    { [5] = item(46, { INT = 10 }, 20, "INVTYPE_ROBE", 4, 1) }, healer)
assert(#heal == 1 and math.abs(heal[1].gain - (20 + 4 * 1.5 - 10 * 0.5)) < 1e-6)

-- Dual wield: a rogue can put a one-hand weapon into the off hand.
local rogue = P.Recommend({ row("dagger", "Bags", nil, item(50, { DPS = 10 }, 15, "INVTYPE_WEAPON", 2, 15)) },
    { [16] = item(51, { DPS = 12 }, 10, "INVTYPE_WEAPON", 2, 15), [17] = item(52, { DPS = 5 }, 10, "INVTYPE_WEAPON", 2, 15) }, opts)
assert(#rogue == 1 and rogue[1].slot == 17)

-- Rings: no duplicate unique ring, second ring slot used.
local rings = { [11] = item(60, { AGI = 9 }, 10, "INVTYPE_FINGER", 4, 0), [12] = item(61, { AGI = 3 }, 10, "INVTYPE_FINGER", 4, 0) }
local ring = P.Recommend({ row("ring", "Bags", nil, item(62, { AGI = 5 }, 10, "INVTYPE_FINGER", 4, 0)),
    row("dup", "Bags", nil, rings[11]) }, rings, opts)
assert(#ring == 1 and ring[1].slot == 12 and ring[1].gain == 2)
local low, high = P.Range(60, 2, 3)
assert(low == 58 and high == 60)

-- Sources ------------------------------------------------------------------------------------------------------------
assert(S.QuestFaction(4294967373) == "Alliance")
assert(S.QuestFaction(8589934770) == "Horde")
assert(S.QuestFaction(0) == nil)
assert(S.ClassAllowed(1 + 8, "ROGUE") and not S.ClassAllowed(1 + 8, "MAGE"))
local db = {
    item = {
        [100] = { "Horde Helm", 2, 18, 22, 4, 2, 1 }, [101] = { "Alliance Boots", 2, 18, 22, 4, 2, 8 },
        [102] = { "Boss Sword", 3, 19, 24, 2, 7, 13 }, [103] = { "Trash Ring", 2, 19, 24, 4, 0, 11 },
        [104] = { "Forever Robe", 3, 12, 15, 4, 1, 20 }, [105] = { "Shirt", 1, 1, 1, 4, 0, 4 },
    },
    quest = { [1] = { "Horde quest", 20, 15 }, [2] = { "Alliance quest", 20, 15 } },
    qx = { [1] = { 178, nil, { 9 } }, [2] = { 77 } },
    qrw = { [1] = { 0, 100, { 100 }, {} } },
    qg = { [1] = { "c7" } },
    rew = { [100] = { 1 }, [101] = { 2 }, [105] = { 1 } },
    npc = { [7] = { "Giver" }, [639] = { "Edwin VanCleef", "", 21, 21, 0 }, [640] = { "Defias Thug", "", 18, 19, 0 },
        [900] = { "Durgen" } },
    spw = { c639 = { { 36, 1, 2 } }, c640 = { { 36, 3, 4 } } },
    ind = { c900 = { 16919 } },
    dng = { [16919] = { "The Hall of Thanes" } },
    drop = { [102] = { 639, 2000 }, [103] = { 640, 50 }, [104] = { 900, 0 } },
}
local rows = S.Build(db, { class = "WARRIOR", faction = "Horde", minChance = 0.02 })
local byItem = {}
for _, r in ipairs(rows) do byItem[r.itemID] = r end
assert(byItem[100] and byItem[100].choiceGroup == "q1" and byItem[100].giver == "Giver" and byItem[100].prerequisites[1] == 9)
assert(not byItem[101], "Alliance quest hidden for Horde")
assert(not byItem[105], "shirts are not scored")
assert(byItem[102] and byItem[102].name == "The Deadmines" and byItem[102].chance == 0.2 and byItem[102].level == 21)
assert(not byItem[103], "0.5 % trash drop below the minimum chance")
assert(byItem[104] and byItem[104].forever and byItem[104].chance == nil and byItem[104].level == 12,
    "Forever dungeon drop with unknown chance, level from the item")
print("GearPilot checks passed")
