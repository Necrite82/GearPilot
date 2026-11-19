local addonName, GP = ...
local P = GP.Planner
local pending, missing = {}, {}

local function itemData(ref)
    local name, link, _, _, minLevel, _, _, _, equip, icon, _, classID, subclassID = C_Item.GetItemInfo(ref)
    if not name or not link then
        local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
        if id and not pending[id] and not missing[id] then
            pending[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        return { link = type(ref) == "string" and ref or nil, loading = id and not missing[id] }
    end
    return {
        name = name, link = link, id = tonumber(link:match("item:(%d+)")), minLevel = minLevel, equip = equip, icon = icon,
        classID = classID, subclassID = subclassID, stats = C_Item.GetItemStats(link),
    }
end

function GP.ReadGear()
    local equipment = {}
    for _, slot in ipairs(P.slots) do
        local link = GetInventoryItemLink("player", slot[1])
        if link then equipment[slot[1]] = itemData(link) end
    end
    return equipment
end

function GP.ReadCandidates(source, low, high)
    local entries, loading = {}, false
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
                    add({ source = source, key = link }, link)
                end
            end
        end
    else
        local faction = UnitFactionGroup("player")
        for _, row in ipairs(GP.catalog.rows) do
            if row.source == source and row.level >= low and row.level <= high
                and (not row.faction or row.faction == faction)
                and (source ~= "Quests" or not C_QuestLog.IsQuestFlaggedCompleted(row.sourceID)) then
                add({
                    source = source, sourceID = row.sourceID, name = row.name, level = row.level,
                    prerequisites = row.prerequisites, provenance = row.provenance,
                    key = ("%s:%d:%d"):format(source, row.sourceID, row.itemID),
                }, row.itemID)
            end
        end
    end
    return entries, loading
end

local defaultProfiles = {
    MAGE = 2, WARLOCK = 2, PRIEST = 2, HUNTER = 3,
}
local function bounded(value, fallback, lower, upper)
    value = tonumber(value)
    if not value or value ~= value then return fallback end
    return math.max(lower, math.min(upper, math.floor(value)))
end
local function initialize()
    local _, class = UnitClass("player")
    local saved = type(GearPilotSettings) == "table" and GearPilotSettings or {}
    saved.below = bounded(saved.below, 2, 0, 10)
    saved.above = bounded(saved.above, 2, 0, 10)
    saved.profile = bounded(saved.profile, defaultProfiles[class] or 1, 1, #P.profiles)
    saved.source = (saved.source == "Quests" or saved.source == "Dungeons") and saved.source or "Bags"
    GearPilotSettings = saved
    GP.settings = saved
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "ITEM_DATA_LOAD_RESULT",
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
