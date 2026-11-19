-- Offline checks: lua5.1 tests/run.lua
local GP = {}
for _, file in ipairs({ "Stats", "Planner", "Sources", "Skills" }) do
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
    { "Equip: Increases damage done by Fire spells and effects by up to 9.", "SCHOOL_FIRE", 9 },
    { "Anlegen: Erhöht durch Frostzauber und Frosteffekte zugefügten Schaden um bis zu 7.", "SCHOOL_FROST", 7 },
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
-- Slot filter "chest": the chest reward of q1 counts although the legs reward is the better one.
local chestOnly = { level = 20, below = 1, above = 2, profile = melee, class = "ROGUE", slotAllowed = function(slot) return slot == 5 end }
local filtered = P.Recommend({
    row("a", "Quests", 20, item(10, { AGI = 6 }), "q1"),
    row("b", "Quests", 20, item(11, { AGI = 9 }, 10, "INVTYPE_LEGS"), "q1"),
}, {}, chestOnly)
assert(#filtered == 1 and filtered[1].entry.key == "a", "the slot filter applies before the best reward of a quest")

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
assert(#rogue == 1 and rogue[1].slot == 17 and rogue[1].gain == (10 - 5) * 4 * 0.5, "off-hand weapon DPS counts half")

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
-- Quest chain and giver spots
local chainDb = {
    qx = { [3] = { 77, nil, { 2 } }, [2] = { 77, nil, { 9, 1 } }, [9] = { 178 }, [1] = { 77 }, [4] = { nil, nil, nil, { 1, 2 } } },
    spw = { c5 = { { 0, -9000, 100 } } }, spm = { c6 = { [1429] = { 500, 250 } } },
}
local chain = S.Chain(chainDb, 3, "Alliance")
assert(table.concat(chain, ",") == "1,2,3", "Horde prerequisite 9 skipped: " .. table.concat(chain, ","))
assert(table.concat(S.Chain(chainDb, 4, "Alliance"), ",") == "1,2,4", "group prerequisites without duplicates")
local spot = S.Spot(chainDb, "c5")
assert(spot.world and spot.map == 0 and spot.x == -9000)
spot = S.Spot(chainDb, "c6")
assert(not spot.world and spot.map == 1429 and spot.x == 0.5 and spot.y == 0.25)
assert(S.Spot(chainDb, "c7") == nil)

-- Tooltip comparison
local worn = { [5] = item(1, { AGI = 10 }) }
local better = P.Compare(item(2, { AGI = 12 }), worn, melee, "ROGUE", 20)
assert(better.usable and math.abs(better.percent - 20) < 1e-6)
local worse = P.Compare(item(3, { AGI = 5 }), worn, melee, "ROGUE", 20)
assert(worse.percent < 0)
assert(P.Compare(item(4, { AGI = 5 }, 10, nil, 4, 4), worn, melee, "ROGUE", 20).usable == false, "plate for a rogue")
assert(P.Compare(item(5, { AGI = 5 }, 10, "INVTYPE_BODY"), worn, melee, "ROGUE", 20) == nil, "shirts are not scored")
assert(P.Compare(worn[5], worn, melee, "ROGUE", 20).worn)

-- Forever replacement of a Classic quest with the same name
local twinDb = { quest = { [286] = { "Return the Statuette" }, [98189] = { "Return the Statuette" }, [5] = { "Other" } },
    qx = { [5] = { nil, nil, nil, { 286, 98189 } } } }
assert(table.concat(S.Chain(twinDb, 5), ",") == "98189,5", "Classic twin dropped from the chain")
assert(S.GiverName({ obj = { [9] = { "Wanted Poster" } } }, "o9") == "Wanted Poster")

-- Mail and plate only from level 40: judged at the level you can wear the item, not the top of the range.
local hunt = { level = 38, below = 2, above = 3, profile = P.Profile("ranged"), class = "HUNTER" }
local mail35 = row("mail 35", "Quests", 40, item(80, { AGI = 20 }, 35, "INVTYPE_CHEST", 4, 3))
local mail41 = row("mail 41", "Quests", 41, item(81, { AGI = 20 }, 41, "INVTYPE_LEGS", 4, 3))
local leather = row("leather", "Quests", 39, item(82, { AGI = 5 }, 37, "INVTYPE_FEET", 4, 2))
local picks = P.Recommend({ mail35, mail41, leather }, {}, hunt)
local keys = {}
for _, r in ipairs(picks) do keys[r.entry.key] = true end
assert(not keys["mail 35"], "level 38 hunter: no mail before 40")
assert(keys["mail 41"] and keys["leather"], "mail that needs level 41 is fine, leather always")
local plate = item(83, { STR = 20 }, 30, "INVTYPE_CHEST", 4, 4)
assert(P.Compare(plate, {}, P.Profile("melee-str"), "WARRIOR", 39).usable == false)
assert(P.Compare(plate, {}, P.Profile("melee-str"), "WARRIOR", 40).usable)
assert(P.Compare(plate, {}, P.Profile("melee-str"), "PALADIN", 40).usable)
assert(P.Compare(item(84, { INT = 5 }, 45, "INVTYPE_CHEST", 4, 3), {}, P.Profile("caster"), "SHAMAN", 39).usable, "mail with level 45 for a shaman")
assert(P.Compare(item(85, { INT = 5 }, 30, "INVTYPE_CHEST", 4, 3), {}, P.Profile("caster"), "SHAMAN", 39).usable == false)
assert(P.Compare(item(86, { INT = 5 }, 30, "INVTYPE_CHEST", 4, 3), {}, P.Profile("caster"), "DRUID", 60).usable == false, "druids never wear mail")
assert(P.HeavyArmor(plate, "WARRIOR") and not P.HeavyArmor(plate, "ROGUE"))

-- New 0.4.0 helpers
local pawn = P.ParsePawn('( Pawn: v1: "Fury": Class=Warrior, Strength=2.00, Agility=1.40, Ap=1.00, HitRating=20.0, Dps=8.0 )')
assert(pawn.STR == 1 and math.abs(pawn.AGI - 0.7) < 1e-9 and pawn.HIT == 10 and pawn.DPS == 4 and pawn.AP == 0.5)
assert(P.ParsePawn("nothing here") == nil)
P.SetCustom({ STR = 1, STA = 0.5 })
assert(P.Profile("custom").STR == 1 and #P.All() == #P.profiles + 1)
assert(P.SpecProfile("PALADIN", 2) == "tank" and P.SpecProfile("PRIEST", 3) == "caster" and P.SpecProfile("MAGE", nil) == "caster")
local function res(zone, gain, dungeonQuest, chance, name, boss)
    return { gain = gain, item = { quality = 2, name = "x" }, entry = { row = { zone = zone, dungeonQuest = dungeonQuest,
        chance = chance, name = name, level = 20, boss = boss } } }
end
local zones = P.ByZone({ res("Westfall", 5), res("Duskwood", 8), res("Westfall", 6) })
assert(zones[1].zone == "Westfall" and zones[1].gain == 11 and #zones[1].results == 2)
local dungeons = P.ByDungeon({ res(nil, 10, nil, 0.2, "The Deadmines", "VanCleef"), res(nil, 10, nil, nil, "Hall", "Durgen") },
    { res(nil, 3, "The Deadmines") })
assert(dungeons[1].name == "The Deadmines" and math.abs(dungeons[1].expected - 5) < 1e-9 and #dungeons[1].quests == 1)
assert(dungeons[2].unknown == 1 and math.abs(dungeons[2].expected - 10 * P.UNKNOWN_CHANCE) < 1e-9)
local worn2 = { [5] = item(90, { AGI = 10 }) }
local clutter = P.Clutter({ { key = "a", item = item(91, { AGI = 3 }) }, { key = "b", item = item(92, { AGI = 30 }) },
    { key = "c", item = item(93, { AGI = 3 }, 10, nil, 4, 4) }, { key = "d", item = item(94, { AGI = 1 }) } },
    worn2, melee, "ROGUE", 20, { [94] = { kind = "plan" } })
local reasons = {}
for _, c in ipairs(clutter) do reasons[c.key] = c.reason end
assert(reasons.a == "worse" and not reasons.b and reasons.c == "unusable" and not reasons.d, "reserved items stay")
-- Profession tools and gear never go: skinning knife for a priest, a fishing pole, "Fishing +5" boots.
local knife = item(7005, { DPS = 2 }, 1, "INVTYPE_WEAPON", 2, 15)
local pole = item(4000, { DPS = 1 }, 1, "INVTYPE_2HWEAPON", 2, 20)
assert(St.IsToolText("Mining Pick", {}) and St.IsToolText("Stiefel", { "Anlegen: Angeln um 5 erhöht." })
    and St.IsToolText("X", { "Requires Engineering (225)" }) and not St.IsToolText("Cape", { "Equip: +5 Agility." }))
local tools = P.Clutter({ { key = "k", item = knife }, { key = "p", item = pole } }, {}, P.Profile("caster"), "PRIEST", 20)
assert(#tools == 0, "profession tools are never listed as can go")
local skills, anySkill = GP.Skills.Parse({ { "Schwerter", 45, 110 }, { "Defense", 100, 110 }, { "Bows", 80, 110 } })
assert(anySkill and skills[7].rank == 45 and skills[2].rank == 80 and not skills[4])

-- Weapon setups: two-hand against two one-hand weapons
local fury = P.Profile("melee-str")
local w2h = item(100, { DPS = 30, STR = 10 }, 30, "INVTYPE_2HWEAPON", 2, 8)
local w1a = item(101, { DPS = 20, STR = 5 }, 30, "INVTYPE_WEAPON", 2, 7)
local w1b = item(102, { DPS = 18, STR = 6 }, 30, "INVTYPE_WEAPON", 2, 0)
local sets = P.WeaponSets({ { item = w2h, key = "a" }, { item = w1a, key = "b" }, { item = w1b, key = "c" } },
    { [16] = w2h }, fury, "WARRIOR", 30)
assert(sets.twoHand.main == w2h and math.abs(sets.twoHand.score - (30 * 4 + 10)) < 1e-9)
assert(sets.pair.main == w1a and sets.pair.off == w1b, "warrior dual wields from 20")
assert(math.abs(sets.pair.score - ((20 * 4 + 5) + (18 * 4 * 0.5 + 6))) < 1e-9)
assert(math.abs(sets.current.score - (30 * 4 + 10)) < 1e-9)
local palaSets = P.WeaponSets({ { item = w1a, key = "b" }, { item = w1b, key = "c" },
    { item = item(103, { STA = 10 }, 30, "INVTYPE_SHIELD", 4, 6), key = "d" } }, {}, fury, "PALADIN", 30)
assert(palaSets.pair.off and palaSets.pair.off.equip == "INVTYPE_SHIELD", "paladin: shield, no second weapon")
assert(P.SpecProfile("HUNTER", 3) == "melee-agi", "survival hunters fight in melee")

-- Code review 0.5.0 -------------------------------------------------------------------------------------------
-- (2) role and primary stat from C_SpecializationInfo decide
assert(P.SpecProfile("WARRIOR", 3, "TANK") == "tank" and P.SpecProfile("DRUID", 4, "HEALER") == "healer")
assert(P.SpecProfile("SHAMAN", 2, "DAMAGER", 2) == "melee-agi" and P.SpecProfile("PALADIN", 3, "DAMAGER", 1) == "melee-str")
assert(P.SpecProfile("HUNTER", 3, "DAMAGER", 2) == "melee-agi" and P.SpecProfile("HUNTER", 2, "DAMAGER", 2) == "ranged")
-- (3) two choice rewards of one quest are never main + off hand
local qa = item(110, { DPS = 20 }, 30, "INVTYPE_WEAPON", 2, 7)
local qb = item(111, { DPS = 19 }, 30, "INVTYPE_WEAPON", 2, 7)
local qc = item(112, { DPS = 5 }, 30, "INVTYPE_WEAPON", 2, 15)
local choiceSets = P.WeaponSets({ { item = qa, key = "qa", entry = { choiceGroup = "q9" } }, { item = qb, key = "qb", entry = { choiceGroup = "q9" } },
    { item = qc, key = "qc", entry = {} } }, {}, fury, "WARRIOR", 30)
assert(choiceSets.pair.main == qa and choiceSets.pair.off == qc, "same quest choice cannot fill both hands")
-- (4) race masks: human-only quest not for a dwarf; full faction masks also for the Skyborne
assert(S.RaceAllowed(1, S.RaceBit(1), "Alliance") and not S.RaceAllowed(1, S.RaceBit(3), "Alliance"))
assert(S.RaceAllowed(77, 2 ^ 32, "Alliance") and not S.RaceAllowed(178, 2 ^ 32, "Alliance"))
assert(S.RaceAllowed(4294967373, 2 ^ 32, "Alliance"))
local raceDb = {
    item = { [200] = { "Human Helm", 2, 10, 12, 4, 1, 1 } }, quest = { [20] = { "Human only", 12, 10 } },
    qx = { [20] = { 1 }, [30] = { nil, nil, { 21, 22 } }, [21] = { 77 }, [22] = { 77 } }, rew = { [200] = { 20 } },
}
local function build(raceID) return S.Build(raceDb, { class = "MAGE", faction = "Alliance", raceBit = S.RaceBit(raceID) }) end
assert(#build(1) == 1 and #build(3) == 0, "human-only reward hidden for a dwarf")
assert(table.concat(S.Chain(raceDb, 30, "Alliance", 1, function(id) return id == 22 end), ",") == "22,30",
    "the branch already done is the chain step")
assert(table.concat(S.Chain(raceDb, 30, "Alliance", 1), ",") == "21,30")
-- (5) schools stay apart; the general SCHOOL weight still covers every school
local fireScale = P.ParsePawn('( Pawn: v1: "Fire": SpellDamage=1, FireSpellDamage=0.9 )')
assert(fireScale.SCHOOL_FIRE == 0.9 and not fireScale.SCHOOL_FROST and not fireScale.SCHOOL)
assert(P.Score({ stats = { SCHOOL_FROST = 10 } }, fireScale) == 0, "a fire scale does not count frost")
assert(P.Score({ stats = { SCHOOL_FIRE = 10 } }, fireScale) == 9)
assert(P.Score({ stats = { SCHOOL_FROST = 10 } }, P.Profile("caster")) == 6, "built-in caster weights every school")
-- (6) a dungeon with only a quest upgrade is in the overview
local onlyQuest = P.ByDungeon({}, { res(nil, 7, "Razorfen Downs") })
assert(#onlyQuest == 1 and onlyQuest[1].name == "Razorfen Downs" and onlyQuest[1].expected == 7 and #onlyQuest[1].results == 0)

-- 0.6.0: chain status, grey quests, twins
local steps = { { done = true }, {}, { active = true }, {}, {} }
local doneCount, nextIndex, started = P.ChainStatus(steps)
assert(steps[2].skipped and doneCount == 2 and nextIndex == 4 and started, "step 2 skipped, step 4 next")
-- With prerequisites: quest 3 needs 1 and 2 (independent); accepting 2 does not make 1 skipped.
local graphSteps = { { id = 1, pre = {} }, { id = 2, pre = {}, active = true }, { id = 3, pre = { 1, 2 } } }
local gDone, gNext = P.ChainStatus(graphSteps)
assert(not graphSteps[1].skipped and gDone == 0 and gNext == 1, "an independent required quest stays open")
local crumb = { { id = 4, pre = {} }, { id = 5, pre = { 4 }, done = true }, { id = 6, pre = { 5 } } }
local cDone, cNext = P.ChainStatus(crumb)
assert(crumb[1].skipped and cDone == 2 and cNext == 3, "a step a done quest builds on counts as skipped")
local chainDb = { qx = { [3] = { nil, nil, nil, { 1, 2 } }, [2] = {}, [1] = {} } }
local chainIds, chainParents = S.Chain(chainDb, 3, "Alliance", 1)
assert(#chainIds == 3 and chainIds[3] == 3 and #chainParents[3] == 2)
local fresh = { {}, {} }
local d0, n0, s0 = P.ChainStatus(fresh)
assert(d0 == 0 and n0 == 1 and not s0)
assert(P.GreyLevel(40) == 31 and P.IsGrey(31, 40) and not P.IsGrey(32, 40) and P.GreyLevel(20) == 13 and not P.IsGrey(5, 5))
local twins = S.Twins({ quest = { [286] = { "Return the Statuette" }, [98189] = { "Return the Statuette" }, [5] = { "Other" },
    [6] = { "Same name" }, [7] = { "Same name" } } })
assert(twins[286][1] == 98189 and twins[98189][1] == 286 and not twins[6], "only Classic <-> Forever pairs")

-- 0.7.0: best in slot, wishlist text, item sources
local bisPool = {
    { item = item(300, { AGI = 10 }, 30, "INVTYPE_CHEST", 4, 2), key = "a" },
    { item = item(301, { AGI = 14 }, 30, "INVTYPE_CHEST", 4, 2), key = "b" },
    { item = item(302, { AGI = 99 }, 45, "INVTYPE_CHEST", 4, 2), key = "too high" },
    { item = item(303, { AGI = 6 }, 30, "INVTYPE_FINGER", 4, 0), key = "r1" },
    { item = item(304, { AGI = 8 }, 30, "INVTYPE_FINGER", 4, 0), key = "r2" },
    { item = item(305, { AGI = 4 }, 30, "INVTYPE_FINGER", 4, 0), key = "r3" },
    { item = item(306, { DPS = 20 }, 30, "INVTYPE_WEAPON", 2, 15), key = "d1" },
    { item = item(307, { DPS = 18 }, 30, "INVTYPE_WEAPON", 2, 15), key = "d2" },
    { item = item(308, { AGI = 50 }, 30, "INVTYPE_CHEST", 4, 3), key = "mail" },
}
local bis = P.BestInSlot(bisPool, melee, "ROGUE", 30, 40)
local bySlot = {}
for _, b in ipairs(bis) do bySlot[b.slot] = b.item.id end
assert(bySlot[5] == 301, "best usable chest within the level limit, no mail for a rogue")
assert(bySlot[11] == 304 and bySlot[12] == 303, "two best different rings")
assert(bySlot[16] == 306 and bySlot[17] == 307, "dual wield daggers")
-- One choice quest leads chest (20 vs 19 elsewhere) and shoulders (20 vs 5 elsewhere): shoulders keep it.
local choicePool = {
    { item = item(320, { AGI = 20 }, 30, "INVTYPE_CHEST", 4, 2), key = "qc", entry = { choiceGroup = "q9" } },
    { item = item(321, { AGI = 20 }, 30, "INVTYPE_SHOULDER", 4, 2), key = "qs", entry = { choiceGroup = "q9" } },
    { item = item(322, { AGI = 19 }, 30, "INVTYPE_CHEST", 4, 2), key = "c2", entry = {} },
    { item = item(323, { AGI = 5 }, 30, "INVTYPE_SHOULDER", 4, 2), key = "s2", entry = {} },
    { item = item(324, { AGI = 9 }, 30, "INVTYPE_FINGER", 4, 0), key = "qr1", entry = { choiceGroup = "q7" } },
    { item = item(325, { AGI = 8 }, 30, "INVTYPE_FINGER", 4, 0), key = "qr2", entry = { choiceGroup = "q7" } },
    { item = item(326, { AGI = 2 }, 30, "INVTYPE_FINGER", 4, 0), key = "r", entry = {} },
}
local chosen = {}
for _, b in ipairs(P.BestInSlot(choicePool, melee, "ROGUE", 30, 40)) do chosen[b.slot] = b.item.id end
assert(chosen[3] == 321 and chosen[5] == 322, "one choice quest, one item: the cheaper slot gives way")
assert(chosen[11] == 324 and chosen[12] == 326, "two rings of one choice quest are not both picked")
assert(P.Signature(P.SetCustom({ AGI = 2 })) ~= P.Signature(P.SetCustom({ AGI = 3 })))
local text = P.ExportWishlist({ [303] = { goal = true }, [12] = {} })
assert(text == "GP1:12,303!")
local back = P.ImportWishlist("my list GP1:12, 303! ")
assert(back[12] and not back[12].goal and back[303].goal and P.ImportWishlist("nope") == nil)
local srcDb = {
    item = { [500] = { "Cape", 2, 20, 25, 4, 1, 16 } }, quest = { [1] = { "Q", 20, 15 } }, qx = { [1] = { 77 } }, rew = { [500] = { 1 } },
    npc = { [639] = { "Edwin VanCleef", "", 21, 21, 1 }, [100] = { "Wolf", "", 10, 11, 0 }, [7] = { "Vendor" } },
    spw = { c639 = { { 36, 1, 2 } } }, drop = { [500] = { 639, 1500, 100, 30 } }, vend = { [500] = { 7 } }, nfac = { [7] = "A" },
    world = { [500] = 18 }, dng = { [1581] = { "The Deadmines", 40, { 1436, 420, 720 } } },
}
local found = S.ItemSources(srcDb, 500, { faction = "Alliance", raceBit = 1, class = "MAGE",
    catalog = { tailoring = { recipes = { [9] = { name = "Cape", makes = 500, learn = 120 } } } } })
local kinds = {}
for _, f in ipairs(found) do kinds[#kinds + 1] = f.kind end
assert(table.concat(kinds, ",") == "quest,dungeon,vendor,craft,mob,world", table.concat(kinds, ","))
assert(found[2].name == "The Deadmines" and found[2].chance == 0.15 and found[5].name == "Wolf")
local door = S.Entrance(srcDb, "The Deadmines")
assert(door and door.map == 1436 and math.abs(door.x - 0.42) < 1e-9)

assert(S.raidNames["Naxxramas"] and S.raidNames["Molten Core"] and not S.raidNames["The Deadmines"])
local raidDb = { item = { [600] = { "Tier Shoulders", 4, 60, 88, 4, 4, 3 } }, quest = { [9] = { "Tier quest", 60, 60 } },
    qx = { [9] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 3456 } }, rew = { [600] = { 9 } },
    dng = { [3456] = { "Naxxramas" } } }
local raidRows = S.Build(raidDb, { class = "WARRIOR", faction = "Alliance" })
assert(raidRows[1] and raidRows[1].raidQuest, "a quest that plays in a raid is a raid source")

-- AllTheThings dungeon data: bosses without ForeverDB spawns, loot without recorded drops, entrances.
local att = { instances = { { id = 2970, name = "The Drowned City", level = 35, area = 16550, entrance = { 1434, 21.5, 27.8 },
    bosses = { { name = "Zul'Alai", npcs = { 900 }, items = { 700, 701 } }, { name = "Tide Lord", npcs = { 901 }, items = { 702 } } } } } }
local attDb = {
    item = { [700] = { "Tide Robe", 3, 33, 38, 4, 1, 20 }, [701] = { "Drowned Staff", 3, 33, 38, 2, 10, 17 },
        [702] = { "Coral Ring", 3, 33, 38, 4, 0, 11 } },
    npc = { [900] = { "Zul'Alai", "", 36, 36, 1 } }, drop = { [700] = { 900, 0 }, [702] = { 901, 2500 } },
    dng = { [16550] = { "The Drowned City" } },
}
local attRows = S.Build(attDb, { class = "MAGE", faction = "Alliance", att = att })
local byItem = {}
for _, r in ipairs(attRows) do byItem[r.itemID] = r end
assert(byItem[700] and byItem[700].name == "The Drowned City" and byItem[700].forever and not byItem[700].chance
    and math.abs(byItem[700].estimate - 0.5) < 1e-9, "unknown rate gets the loot table share")
assert(byItem[701] and byItem[701].boss == "Zul'Alai" and byItem[701].level == 35 and byItem[701].estimate, "ATT-only loot")
assert(byItem[702] and byItem[702].chance == 0.25 and not byItem[702].estimate, "known rate, boss found via ATT")
local none = S.Build(attDb, { class = "MAGE", faction = "Alliance" })
assert(#none == 0, "without ATT the bosses have no dungeon")
local attSources = S.ItemSources(attDb, 701, { att = att })
assert(attSources[1] and attSources[1].kind == "dungeon" and attSources[1].estimate == 0.5)
local attDoor = S.Entrance(attDb, "The Drowned City", att)
assert(attDoor and attDoor.map == 1434 and math.abs(attDoor.x - 0.215) < 1e-9)

-- Wishlist hints: ATT-only loot (701) reaches the boss and the dungeon (map 2970) too.
local byNpc, byMap = S.DropIndex(attDb, att, { 700, 701, 500 })
assert(byNpc[900] and #byNpc[900] == 2 and byMap[2970] and #byMap[2970] == 2, "ATT loot in the drop hints")
local classicNpc, classicMap = S.DropIndex(srcDb, nil, { 500 })
assert(classicNpc[639][1].chance == 1500 and classicMap[36][1].boss == "Edwin VanCleef" and not classicMap[0])
-- 1.0.2: dungeon catalog (levels from bosses and drops, quests from ATT and the dungeon zone) and windows.
att.instances[1].quests = { 9001, 9002 }
attDb.quest = { [9001] = { "Into the Deep", 36, 33 }, [9002] = { "Old Quest", 35, 30 }, [9003] = { "Zone quest", 37, 34 } }
attDb.qx = { [9003] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 16550 } }
attDb.npc[900] = { "Zul'Alai", "", 34, 35, 1 }
att.index = nil
local catalogList, catalogByName = S.Catalog(attDb, att, S.Build(attDb, { class = "MAGE", faction = "Alliance", att = att }))
local drowned = catalogByName["The Drowned City"]
assert(drowned and drowned.mapID == 2970 and drowned.low == 35 and drowned.high == 35 and #drowned.quests == 3, "catalog entry")
assert(#catalogList == 1 and #drowned.bosses == 2 and drowned.bosses[1].name == "Zul'Alai")
local dq = S.DungeonQuest(attDb, 9001, { class = "MAGE", faction = "Alliance", raceBit = 1 })
assert(dq and dq.title == "Into the Deep" and dq.level == 36)
-- Windows: a dungeon drop at level 34 counts in a dungeon window 1..43 although your range is 39..42.
local windowed = P.Recommend({ row("dungeon 34", "Dungeons", 34, item(330, { AGI = 20 }, 34)) }, {},
    { level = 40, below = 1, above = 2, profile = melee, class = "ROGUE", windows = { Dungeons = { 1, 43 } } })
assert(#windowed == 1, "dungeon window instead of your range")
local outside = P.Recommend({ row("dungeon 34", "Dungeons", 34, item(330, { AGI = 20 }, 34)) }, {},
    { level = 40, below = 1, above = 2, profile = melee, class = "ROGUE" })
assert(#outside == 0)

-- 1.2.0: quest experience (Classic reduction below your level, ForeverDB fallback, sums, text).
CreateFrame = CreateFrame or function() return { RegisterEvent = function() end, SetScript = function() end } end
GP.L = GP.L or function(key) return key end
local playerLevel = 40
GP.Player = function() return { level = playerLevel } end
assert(loadfile("GearPilotPro/QuestXP.lua"))("GearPilotPro", GP)
local XP = GP.QuestXP
assert(XP.Factor(35, 40) == 1 and math.abs(XP.Factor(34, 40) - 0.8) < 1e-9 and math.abs(XP.Factor(31, 40) - 0.2) < 1e-9
    and XP.Factor(30, 40) == 0.1 and XP.Factor(45, 40) == 1)
ForeverDB = { qrw = { [1] = { 1200, 2000 }, [2] = { 0, 3000 } }, quest = { [1] = { "A", 38 }, [2] = { "B", 33 }, [3] = { "C", 40 } } }
GearPilotProCache = nil
assert(XP.Get(1).xp == 2000 and XP.Get(1).money == 1200 and XP.Get(2).xp == 1800 and XP.Get(3).xp == nil)
local sumXP, sumMoney, sumUnknown = XP.Sum({ { id = 1 }, { id = 2 }, { id = 3 } })
assert(sumXP == 3800 and sumMoney == 1200 and sumUnknown == 1)
assert(XP.Text(1500) == "1,500 XP" and XP.Text(150) == "150 XP" and XP.Text(1234567) == "1,234,567 XP")
playerLevel = 60
assert(XP.Get(1).xp == 0 and XP.Get(1).money == 1200, "at the top level quests give money, no experience")
ForeverDB = nil

-- 1.2.3: crit and hit as percent, not as the client's rating; a boss is not a vendor of its own loot.
local rod = St.Combine({ ITEM_MOD_CRIT_RATING_SHORT = 14, ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 25.7 },
    { "Anlegen: Erhöht Eure Chance, einen kritischen Treffer zu erzielen, um 1%." }, { equip = "INVTYPE_2HWEAPON" })
assert(rod.CRIT == 1 and rod.STA == 10, "the tooltip percent wins over the rating")
local ratingOnly = St.Combine({ ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 2 }, {}, {})
assert(ratingOnly.HIT == 1 and ratingOnly.CRIT == 2, "a rating alone is converted, a small value is a percent")
local vendorDb = { item = { [800] = { "Boss Ring", 3, 55, 60, 4, 0, 11 } }, npc = { [1] = { "Boss", "", 60, 60, 3 }, [2] = { "Quartermaster", "", 55, 55, 1 } },
    drop = { [800] = { 1, 1200 } }, vend = { [800] = { 1, 2 } }, spw = { c1 = { { 229, 50, 50 } } }, dng = {}, area = {} }
local vendorList = S.ItemSources(vendorDb, 800, {})
local vendorNames = {}
for _, src in ipairs(vendorList) do if src.kind == "vendor" then vendorNames[#vendorNames + 1] = src.name end end
assert(#vendorNames == 1 and vendorNames[1] == "Quartermaster", "the boss is a drop, not a vendor")

-- 1.3.0: quest route (available quests, zone choice by worth and way, order accept -> objectives -> turn in).
assert(loadfile("GearPilotPro/QuestRoute.lua"))("GearPilotPro", GP)
local QR = GP.QuestRoute
local routeDb = {
    quest = { [1] = { "Wolves", 20, 15 }, [2] = { "Follow-up", 21, 15 }, [3] = { "Far away", 20, 15 }, [4] = { "Grey", 10, 5 },
        [5] = { "Talk task", 20, 15 }, [6] = { "Horde only", 20, 15 } },
    qx = { [1] = { nil, nil, nil, nil, nil, nil, nil, { 100 }, nil, nil, 40 }, [2] = { nil, nil, { 1 }, nil, nil, nil, nil, nil, nil, nil, 40 },
        [3] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 33 }, [4] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 40 },
        [5] = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 40 }, [6] = { 2 ^ 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, 40 } },
    qg = { [1] = { "c10" }, [2] = { "c10" }, [3] = { "c30" }, [4] = { "c10" }, [5] = { "c11" }, [6] = { "c10" } },
    qe = { [1] = { "c10" }, [2] = { "c10" }, [3] = { "c30" }, [4] = { "c10" }, [5] = { "c11" }, [6] = { "c10" } },
    spw = { c10 = { { 0, 100, 100 } }, c11 = { { 0, 400, 100 } }, c30 = { { 0, 9000, 9000 } }, c100 = { { 0, 200, 200 }, { 0, 5000, 5000 } } },
    npc = { [100] = { "Wolf" } }, area = { [40] = { "Westfall" }, [33] = { "Stranglethorn" } }, dng = {},
    taxi = { [1] = { "Sentinel Hill, Westfall", 0, 120, 90, 0, 0, 0, 541 }, [2] = { "Grom'gol, Stranglethorn", 0, 110, 95, 0, 0, 2224, 0 } },
}
local routeCtx = { class = "WARRIOR", faction = "Alliance", raceBit = 1, level = 20, grey = 13, position = { 0, 90, 90 },
    done = function() return false end, active = function() return false end, xp = function() return 1000 end }
local plan = QR.Plan(routeDb, routeCtx)
local ids = {}
for _, q in ipairs(plan.quests) do ids[q.id] = true end
assert(plan.zone.name == "Westfall" and ids[1] and ids[5] and not ids[2] and not ids[4] and not ids[6], "available quests of the best zone")
assert(plan.next and plan.next.name == "Stranglethorn")
local order = {}
for i, t in ipairs(plan.tasks) do order[t.kind .. t.quest.id] = i end
assert(order.accept1 < order.objective1 and order.objective1 < order.turnin1, "accept, objective, turn in")
assert(order.turnin5 == #plan.tasks, "a quest with unknown objectives is turned in last")
assert(plan.tasks[order.objective1].p[2] == 200, "the objective spawn nearest the giver")
assert(QR.FlightPoint(routeDb, { 0, 100, 100 }, "Alliance") == "Sentinel Hill, Westfall"
    and QR.FlightPoint(routeDb, { 0, 100, 100 }, "Horde") == "Grom'gol, Stranglethorn")
routeCtx.done = function(id) return id == 1 end
local after = QR.Plan(routeDb, routeCtx)
local afterIds = {}
for _, q in ipairs(after.quests) do afterIds[q.id] = true end
assert(afterIds[2] and not afterIds[1], "the follow-up comes in once its prerequisite is done")

-- The generated file loads and covers the new Forever dungeons.
local data = {}
assert(loadfile("GearPilotPro/Data/Dungeons.lua"))("GearPilotPro", data)
local ids = {}
for _, inst in ipairs(data.DungeonData.instances) do
    ids[inst.id] = inst
    for _, boss in ipairs(inst.bosses) do assert(#boss.npcs > 0, inst.name) end
end
for _, id in ipairs({ 2970, 2994, 2998, 2999, 3039, 3065 }) do assert(ids[id] and #ids[id].bosses > 0, "dungeon " .. id) end

print("GearPilot checks passed")
