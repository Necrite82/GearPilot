local GP = {}
assert(loadfile("GearPilot/Planner.lua"))("GearPilot", GP)
local P = GP.Planner
local function item(id, strength, minLevel, equip, subclass)
    return {
        id = id, link = "item:" .. id, minLevel = minLevel, equip = equip or "INVTYPE_CHEST",
        classID = 4, subclassID = subclass or 2,
        stats = { ITEM_MOD_STRENGTH_SHORT = strength },
    }
end
local opts = { level = 20, below = 1, above = 2, profile = P.profiles[1], class = "ROGUE" }
local function row(key, source, level, gear)
    return { key = key, source = source, level = level, item = gear }
end
local equipped = { [5] = item(1, 4, 10) }
local candidates = {
    row("old bag item", "Bags", nil, item(2, 7, 10)),
    row("upcoming quest", "Quests", 22, item(3, 10, 22)),
    row("below range", "Quests", 18, item(4, 100, 10)),
    row("above range", "Dungeons", 23, item(5, 100, 10)),
    row("can't equip yet", "Quests", 22, item(6, 100, 23)),
    row("wrong armor", "Bags", nil, item(7, 100, 10, nil, 3)),
    row("weaker", "Bags", nil, item(8, 3, 10)),
}
local results = P.Recommend(candidates, equipped, opts)
assert(#results == 2, "Only eligible upgrades should be listed")
assert(results[1].entry.key == "upcoming quest" and results[1].gain == 6)
assert(results[2].entry.key == "old bag item" and results[2].gain == 3)
assert(#P.Recommend(candidates, { [5] = { loading = true } }, opts) == 0)

local rings = { [11] = item(11, 9, 10, "INVTYPE_FINGER", 0), [12] = item(12, 3, 10, "INVTYPE_FINGER", 0) }
local better = row("ring", "Bags", nil, item(13, 5, 10, "INVTYPE_FINGER", 0))
local duplicate = row("duplicate", "Bags", nil, rings[11])
local recommended = P.Recommend({ better, duplicate }, rings, opts)
assert(#recommended == 1 and recommended[1].slot == 12 and recommended[1].gain == 2)
local low, high = P.Range(60, 2, 3)
assert(low == 58 and high == 60)
low, high = P.Range(1, 2, 3)
assert(low == 1 and high == 4)
print("GearPilot planner checks passed")
