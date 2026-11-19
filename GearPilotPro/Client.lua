local addonName, GP = ...
local P = GP.Planner
local pending, missing = {}, {}
GP.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or ""

local function itemData(ref)
    local name, link, quality, _, minLevel, _, _, _, equip, icon, _, classID, subclassID = C_Item.GetItemInfo(ref)
    if not name or not link then
        local id = type(ref) == "number" and ref or tonumber(tostring(ref):match("item:(%d+)"))
        if id and not pending[id] and not missing[id] then
            pending[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        return { id = id, link = type(ref) == "string" and ref or nil, loading = id and not missing[id] }
    end
    local item = {
        name = name, link = link, id = tonumber(link:match("item:(%d+)")), quality = quality, minLevel = minLevel,
        equip = equip, icon = icon, classID = classID, subclassID = subclassID,
    }
    item.stats = GP.Stats.Read(link, item)
    return item
end
GP.ItemData = itemData

function GP.ReadGear()
    local equipment = {}
    for _, slot in ipairs(P.slots) do
        local link = GetInventoryItemLink("player", slot[1])
        if link then equipment[slot[1]] = itemData(link) end
    end
    return equipment
end

function GP.Player()
    local _, class = UnitClass("player")
    return { class = class, level = UnitLevel("player") or 1, faction = UnitFactionGroup("player") }
end

-- Candidates of one source ("Bags", "Quests", "Dungeons") inside the level window.
-- Returns entries, loading, state; state "missing" when ForeverDB is not installed.
function GP.ReadCandidates(source, low, high)
    local entries, loading = {}, false
    local player = GP.Player()
    local function add(entry, ref)
        local item = itemData(ref)
        loading = loading or item.loading
        if item.name then
            entry.item = item
            entries[#entries + 1] = entry
        end
    end
    if source == "Bags" then
        local visited = {}
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local link = C_Container.GetContainerItemLink(bag, slot)
                if link and not visited[link] then
                    visited[link] = true
                    add({ source = source, key = link, bag = bag, bagSlot = slot }, link)
                end
            end
        end
        return entries, loading, "ready"
    end
    local rows = GP.Sources.Rows(player.class, player.faction, GP.settings.minChance)
    if not rows then return entries, false, "missing" end
    local db = ForeverDB
    local dungeonQuests = GP.settings.dungeonQuests
    for _, row in ipairs(rows) do
        local isDungeonQuest = row.dungeonQuest ~= nil
        local wanted = row.source ~= "Quests" or dungeonQuests == "show"
            or (dungeonQuests == "hide" and not isDungeonQuest) or (dungeonQuests == "only" and isDungeonQuest)
        local info = db.item[row.itemID]
        local required = info and info[3] or 0
        if wanted and row.source == source and row.level >= low and row.level <= high and required <= high
            and (source ~= "Quests" or not GP.Sources.QuestDone(row.sourceID)) then
            add({
                source = source, sourceID = row.sourceID, name = row.name, level = row.level, row = row,
                choiceGroup = row.choiceGroup, key = ("%s:%s:%d"):format(source, tostring(row.sourceID), row.itemID),
            }, row.itemID)
        end
    end
    return entries, loading, "ready"
end

local function bounded(value, fallback, lower, upper)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    return math.max(lower, math.min(upper, math.floor(value)))
end
local chances = { [0.01] = true, [0.02] = true, [0.05] = true, [0.1] = true }
local pages = { upgrades = true, quests = true, dungeons = true, bags = true, gear = true, settings = true, help = true }
local function initialize()
    local player = GP.Player()
    local saved = type(GearPilotProSettings) == "table" and GearPilotProSettings or {}
    saved.below = bounded(saved.below, 2, 0, 10)
    saved.above = bounded(saved.above, 3, 0, 10)
    saved.profile = P.Profile(saved.profile or P.defaultProfile[player.class]).key
    saved.minChance = chances[saved.minChance] and saved.minChance or 0.02
    saved.page = pages[saved.page] and saved.page or "upgrades"
    if saved.tooltip == nil then saved.tooltip = true end
    saved.questSort = (saved.questSort == "distance" or saved.questSort == "zone") and saved.questSort or "gain"
    saved.dungeonQuests = (saved.dungeonQuests == "hide" or saved.dungeonQuests == "only") and saved.dungeonQuests or "show"
    GearPilotProSettings = saved
    GP.settings = saved
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "ITEM_DATA_LOAD_RESULT",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, arg, success)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        initialize()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if not pending[arg] then return end
        pending[arg] = nil
        if not success then missing[arg] = true end
    end
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
end)

SLASH_GEARPILOTPRO1 = "/gpp"
SLASH_GEARPILOTPRO2 = "/gearpilotpro"
SlashCmdList.GEARPILOTPRO = function() if GP.Toggle then GP.Toggle() end end
