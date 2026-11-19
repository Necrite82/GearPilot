local addonName, GP = ...
local P = GP.Planner
local pending, missing = {}, {}
GP.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or ""

local function itemData(ref)
    if ref == nil or ref == "" then return { loading = true } end
    local name, link, quality, _, minLevel, _, _, _, equip, icon, sellPrice, classID, subclassID = C_Item.GetItemInfo(ref)
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
        equip = equip, icon = icon, classID = classID, subclassID = subclassID, sellPrice = sellPrice,
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
    local _, _, raceID = UnitRace("player")
    return { class = class, level = UnitLevel("player") or 1, faction = UnitFactionGroup("player"),
        raceBit = GP.Sources.RaceBit(raceID) }
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
    local rows = GP.Sources.Rows(player.class, player.faction, GP.settings.minChance, player.raceBit)
    if not rows then return entries, false, "missing" end
    local db = ForeverDB
    if source == "Crafted" then
        local cp = GP.CraftPilot()
        if not cp then return entries, false, "nocraftpilot" end
        GP.craftedRows = GP.craftedRows or GP.Sources.Crafted(cp.CatalogData, db, player.class)
        rows = GP.craftedRows
    elseif source == "Auction" then
        local price = GP.AuctionPrice
        if not GP.HasAuctionPrices() then return entries, false, "noauction" end
        GP.equipIndex = GP.equipIndex or GP.Sources.EquipIndex(db, player.class)
        for level = low, high do
            for _, itemID in ipairs(GP.equipIndex[level] or {}) do
                local value = price(itemID)
                if value and value > 0 then
                    add({ source = source, sourceID = "a" .. itemID, level = level, price = value,
                        row = { itemID = itemID, source = source, level = level, price = value },
                        key = "Auction:" .. itemID }, itemID)
                end
            end
        end
        return entries, loading, "ready"
    end
    local dungeonQuests = GP.settings.dungeonQuests
    for _, row in ipairs(rows) do
        local isDungeonQuest = row.dungeonQuest ~= nil
        local wanted = row.source ~= "Quests" or dungeonQuests == "show"
            or (dungeonQuests == "hide" and not isDungeonQuest) or (dungeonQuests == "only" and isDungeonQuest)
        local info = db.item[row.itemID]
        local required = info and info[3] or 0
        if wanted and row.exclusive and GP.Sources.Excluded(row) then wanted = false end
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
local pages = { upgrades = true, quests = true, dungeons = true, shop = true, auction = true, bags = true, gear = true, settings = true, help = true }
local function initialize()
    local player = GP.Player()
    local saved = type(GearPilotProSettings) == "table" and GearPilotProSettings or {}
    saved.below = bounded(saved.below, 2, 0, 10)
    saved.above = bounded(saved.above, 3, 0, 10)
    if type(saved.custom) == "table" then P.SetCustom(saved.custom) end
    saved.profile = P.Profile(saved.profile or P.defaultProfile[player.class]).key
    saved.minChance = chances[saved.minChance] and saved.minChance or 0.02
    saved.page = pages[saved.page] and saved.page or "upgrades"
    if saved.tooltip == nil then saved.tooltip = true end
    if saved.autoProfile == nil then saved.autoProfile = true end
    if saved.rewardHelp == nil then saved.rewardHelp = true end
    if saved.rollHelp == nil then saved.rollHelp = true end
    saved.include = type(saved.include) == "table" and saved.include or {}
    for _, key in ipairs({ "Vendors", "Auction", "Crafted" }) do
        if saved.include[key] == nil then saved.include[key] = true end
    end
    saved.views = type(saved.views) == "table" and saved.views or {}
    saved.shopSource = saved.shopSource or "all"
    saved.weaponPool = saved.weaponPool == "all" and "all" or "own"
    saved.shopSort = (saved.shopSort == "price" or saved.shopSort == "value") and saved.shopSort or "gain"
    saved.shopMax = tonumber(saved.shopMax) or 0
    saved.slotFilter = type(saved.slotFilter) == "string" and saved.slotFilter or "all"
    saved.ahSort = (saved.ahSort == "price" or saved.ahSort == "value") and saved.ahSort or "gain"
    saved.ahMax = tonumber(saved.ahMax) or 0
    saved.ahAge = (saved.ahAge == "today" or saved.ahAge == "week") and saved.ahAge or "all"
    saved.chains = saved.chains == "started" and "started" or "all"
    if saved.minimap == nil then saved.minimap = true end
    if type(saved.custom) == "table" then P.SetCustom(saved.custom) end
    saved.questSort = (saved.questSort == "distance" or saved.questSort == "zone") and saved.questSort or "gain"
    saved.dungeonQuests = (saved.dungeonQuests == "hide" or saved.dungeonQuests == "only") and saved.dungeonQuests or "show"
    GearPilotProSettings = saved
    GP.settings = saved
end

-- Other addons ------------------------------------------------------------------------------------------------
function GP.CraftPilot()
    local cp = rawget(_G, "CraftPilotPro")
    if type(cp) == "table" and type(cp.CatalogData) == "table" then return cp end
    return nil
end
-- Items CraftPilot keeps for plans, recipes and the raid stock.
function GP.Reserved()
    local cp = rawget(_G, "CraftPilotPro")
    if type(cp) ~= "table" or type(cp.ReservedItems) ~= "function" then return nil end
    local ok, items = pcall(cp.ReservedItems, cp)
    return ok and type(items) == "table" and items or nil
end
function GP.HasAuctionPrices()
    return type(Auctionator) == "table" and type(Auctionator.API) == "table" and type(Auctionator.API.v1) == "table"
        and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end
function GP.AuctionPrice(itemID)
    if not GP.HasAuctionPrices() then return nil end
    local ok, value = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "GearPilot", itemID)
    return ok and type(value) == "number" and value or nil
end
-- Days since Auctionator last saw the price (newer Auctionator versions only).
function GP.AuctionAge(itemID)
    local api = GP.HasAuctionPrices() and Auctionator.API.v1
    if not (api and api.GetAuctionAgeByItemID) then return nil end
    local ok, value = pcall(api.GetAuctionAgeByItemID, "GearPilot", itemID)
    return ok and type(value) == "number" and value or nil
end
-- Search the open auction house for item names (Auctionator does the search).
function GP.SearchAuction(names)
    local api = GP.HasAuctionPrices() and Auctionator.API.v1
    if not (api and api.MultiSearchExact) then return false end
    return pcall(api.MultiSearchExact, "GearPilot", names)
end
function GP.AuctionHouseOpen()
    local frame = rawget(_G, "AuctionHouseFrame") or rawget(_G, "AuctionFrame")
    return frame and frame.IsShown and frame:IsShown() or false
end
-- Auction house page: every equippable item with an Auctionator price, required level from fromLevel to toLevel.
-- Returns entries, loading, state ("noauction" without Auctionator, "noprices" without any price).
function GP.AuctionCandidates(fromLevel, toLevel)
    local entries, loading = {}, false
    if not GP.HasAuctionPrices() then return entries, false, "noauction" end
    local db = GP.Sources.Database()
    if not db then return entries, false, "missing" end
    local player = GP.Player()
    GP.equipIndex = GP.equipIndex or GP.Sources.EquipIndex(db, player.class)
    local priced = false
    for level = math.max(1, fromLevel), toLevel do
        for _, itemID in ipairs(GP.equipIndex[level] or {}) do
            local price = GP.AuctionPrice(itemID)
            if price and price > 0 then
                priced = true
                local item = itemData(itemID)
                loading = loading or item.loading
                if item.name then
                    local age = GP.AuctionAge(itemID)
                    entries[#entries + 1] = { source = "Auction", sourceID = "a" .. itemID, level = level, price = price, age = age,
                        row = { itemID = itemID, source = "Auction", level = level, price = price, age = age },
                        key = "AH:" .. itemID, item = item }
                end
            end
        end
    end
    return entries, loading, priced and "ready" or "noprices"
end

-- Professions the character has, by CraftPilot key (blacksmithing, tailoring, ...).
local professionKeys = {
    [164] = "blacksmithing", [165] = "leatherworking", [197] = "tailoring", [202] = "engineering",
    [171] = "alchemy", [333] = "enchanting",
}
function GP.Professions()
    local known = {}
    if not (GetProfessions and GetProfessionInfo) then return known end
    for _, index in ipairs({ GetProfessions() }) do
        if index then
            local ok, name, _, rank, _, _, _, skillLine = pcall(GetProfessionInfo, index)
            if ok and skillLine and professionKeys[skillLine] then known[professionKeys[skillLine]] = { name = name, rank = rank } end
        end
    end
    return known
end

-- Specialization from the game: retail-style specializations, otherwise the talent tree with most points.
-- Specialization index, role ("TANK", "HEALER", "DAMAGER") and primary stat (1 strength, 2 agility, 4 intellect).
-- Forever has these in C_SpecializationInfo; the old globals are only a fallback.
function GP.Specialization()
    local info = C_SpecializationInfo
    local get = info and info.GetSpecialization or GetSpecialization
    if get then
        local ok, spec = pcall(get)
        if ok and type(spec) == "number" and spec > 0 then
            local details = info and info.GetSpecializationInfo or GetSpecializationInfo
            if details then
                local found, _, _, _, _, role, primaryStat = pcall(details, spec)
                if found then return spec, role, primaryStat end
            end
            return spec
        end
    end
    if GetNumTalentTabs and GetTalentTabInfo then
        local best, most = nil, 0
        for tab = 1, GetNumTalentTabs() do
            local values = { pcall(GetTalentTabInfo, tab) }
            local points = type(values[4]) == "number" and values[4] or type(values[6]) == "number" and values[6] or 0
            if points > most then best, most = tab, points end
        end
        return best
    end
    return nil
end
function GP.ActiveProfile()
    local s = GP.settings
    if s.autoProfile then
        local player = GP.Player()
        return P.Profile(P.SpecProfile(player.class, GP.Specialization()))
    end
    return P.Profile(s.profile)
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "ITEM_DATA_LOAD_RESULT", "PLAYER_TALENT_UPDATE", "SKILL_LINES_CHANGED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
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
