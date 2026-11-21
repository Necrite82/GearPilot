-- Same-item paired slots, actual item restrictions, and the quest route's data/profile dependencies.
local GP = ...
local P = GP.Planner
local function ring(id, value, equip)
    return { id = id, link = "item:" .. id, minLevel = 10, equip = equip or "INVTYPE_FINGER",
        classID = 4, subclassID = 0, stats = { AGI = value } }
end
local worn = { [11] = ring(910101, 20), [12] = ring(910102, 1) }
local copy = ring(910101, 20)
local options = { level = 20, below = 5, above = 5, profile = { AGI = 1 }, class = "ROGUE" }
local candidates = { { key = "copy", source = "Bags", item = copy } }
local list = P.Recommend(candidates, worn, options)
assert(#list == 1 and list[1].slot == 12 and list[1].gain == 19)
local compared = P.Compare(copy, worn, options.profile, "ROGUE", 20)
assert(compared and not compared.worn and compared.slot == 12 and compared.gain == 19,
    "Tooltip comparison must finish both ring slots before declaring the item worn")
copy.unique = true
assert(#P.Recommend(candidates, worn, options) == 0)
assert(P.Compare(copy, worn, options.profile, "ROGUE", 20).worn)
copy.unique = false
copy.limitCategory, copy.limitMax = 77, 1
worn[11].limitCategory, worn[11].limitMax = 77, 1
copy.id, copy.link = 910103, "item:910103"
assert(#P.Recommend(candidates, worn, options) == 0,"Different items in the same equip-limited category still conflict")
copy.limitMax, worn[11].limitMax = 2, 2
assert(#P.Recommend(candidates, worn, options) == 1,"A category allowing two items leaves both slots usable")
copy.equip = "INVTYPE_TRINKET"
assert(#P.Recommend(candidates, { [13] = ring(copy.id, 20, copy.equip), [14] = ring(910104, 1, copy.equip) }, options) == 1)

local saved = { frame = CreateFrame, items = C_Item, tips = C_TooltipInfo, commands = SlashCmdList,
    timer = C_Timer, quests = C_QuestLog, db = ForeverDB, cache = GearPilotProCache,
    xp = GetQuestLogRewardXP, money = GetQuestLogRewardMoney }
local frames = {}
CreateFrame = function()
    local f = { scripts = {} }
    f.RegisterEvent = function() end
    f.SetScript = function(self, name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList, C_Timer, C_QuestLog = {}, nil, {}
C_Item = {
    GetItemInfo = function() return "Reward", "item:910201", 2, 20, 10, "Armor", "Leather", 1, "INVTYPE_FINGER", 1, 10, 4, 0 end,
    GetItemStats = function() return { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_SPELL_POWER_SHORT = 20 } end,
    GetItemUniquenessByID = function() return false, "Category", 1, 77 end,
    GetItemUniqueness = function() return 77, 1 end,
}
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }
local H = { L = function(s) return s end, Stats = GP.Stats, Planner = P }
assert(loadfile("GearPilotPro/Client.lua"))("GearPilotPro", H)
local read = H.ItemData(910201)
assert(read.unique == false and read.limitCategory == 77 and read.limitMax == 1,
    "Client item data carries the real uniqueness/category metadata into the planner")
C_Item.GetItemUniquenessByID = function() return true end
C_Item.GetItemUniqueness = nil
assert(GP.Stats.ItemLimits(910201) == true)
C_Item.GetItemUniquenessByID = nil
C_TooltipInfo.GetHyperlink = function() return { lines = { {}, { leftText = "Einzigartig" } } } end
assert(GP.Stats.ItemLimits(910201) == true,"Older clients can read the restriction from the tooltip")
C_TooltipInfo.GetHyperlink = function() return { lines = { {}, { leftText = "Unique (2)" } } } end
assert(GP.Stats.ItemLimits(910201) == false)

local profile = { AGI = 1 }
H.Player = function() return { level = 20, class = "ROGUE", faction = "Alliance", raceBit = 1 } end
H.ActiveProfile = function() return profile end
H.ReadGear = function() return {} end
H.Sources = setmetatable({ Rows = function()
    return { { source = "Quests", sourceID = 1, itemID = 910201 } }
end }, { __index = GP.Sources })
H.settings = {}
ForeverDB = { quest = { [1] = { "Test quest", 20, 15 } }, qrw = { [1] = { 0, 1000 } },
    qx = { [1] = { [11] = 40 } }, qg = { [1] = { "c10" } }, qe = { [1] = { "c10" } },
    spw = { c10 = { { 0, 100, 100 } } }, area = { [40] = { "Westfall" } } }
GearPilotProCache = nil
GetQuestLogRewardXP = function() return 2000 end
GetQuestLogRewardMoney = function() return 0 end
assert(loadfile("GearPilotPro/QuestXP.lua"))("GearPilotPro", H)
local xpFrame = frames[#frames]
assert(loadfile("GearPilotPro/QuestRoute.lua"))("GearPilotPro", H)
local QR = H.QuestRoute
QR.Position = function() return { 0, 90, 90 } end
local first = QR.Current()
assert(first.xp == 1000 and first.quests[1].gain == 10)
local redrawn
H.ScheduleRefresh = function() redrawn = QR.Current() end
xpFrame.scripts.OnEvent(xpFrame, "QUEST_DATA_LOAD_RESULT", 1, true)
assert(redrawn ~= first and redrawn.xp == 2000,"Server XP must invalidate the plan before its redraw")
assert(H.QuestXP.Get(1, 20).xp == redrawn.xp)
local unchanged = QR.Current()
xpFrame.scripts.OnEvent(xpFrame, "QUEST_DATA_LOAD_RESULT", 1, true)
assert(QR.Current() == unchanged,"Repeated identical answers do not rebuild the route")

profile = { SP = 1 }
local switched = QR.Current()
assert(switched ~= unchanged and switched.quests[1].gain == 20,"Switching profiles refreshes cached reward scores")
profile.SP = 2
assert(QR.Current().quests[1].gain == 40,"Editing weights in the same profile table also refreshes the route")

CreateFrame, C_Item, C_TooltipInfo, SlashCmdList, C_Timer, C_QuestLog, ForeverDB, GearPilotProCache,
    GetQuestLogRewardXP, GetQuestLogRewardMoney = saved.frame, saved.items, saved.tips, saved.commands,
    saved.timer, saved.quests, saved.db, saved.cache, saved.xp, saved.money
print("PASS: 1.7.2 paired-slot comparisons, real item limits, server XP refresh and profile/weight changes")
