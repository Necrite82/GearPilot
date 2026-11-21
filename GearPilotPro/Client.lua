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
    if equip == "INVTYPE_FINGER" or equip == "INVTYPE_TRINKET" then
        item.unique, item.limitCategory, item.limitMax = GP.Stats.ItemLimits(link)
    end
    return item
end
GP.ItemData = itemData

-- 1.6.3: your gear is read once and kept until it changes (every tooltip, page and route plan asked again).
local gearCache
function GP.ReadGear()
    if gearCache then return gearCache end
    local equipment, loading = {}, false
    for _, slot in ipairs(P.slots) do
        local link = GetInventoryItemLink("player", slot[1])
        if link then
            equipment[slot[1]] = itemData(link)
            loading = loading or equipment[slot[1]].loading or false
        end
    end
    if not loading then gearCache = equipment end
    return equipment
end
function GP.GearChanged()
    gearCache = nil
    if GP.TooltipChanged then GP.TooltipChanged() end
end

function GP.Player()
    local _, class = UnitClass("player")
    local _, _, raceID = UnitRace("player")
    return { class = class, level = UnitLevel("player") or 1, faction = UnitFactionGroup("player"),
        raceBit = GP.Sources.RaceBit(raceID) }
end

-- Dungeon catalog for the player's rows (Sources.Catalog), cached with the rows.
function GP.Catalog()
    local player = GP.Player()
    local rows = GP.Sources.Rows(player.class, player.faction, GP.settings.minChance, player.raceBit)
    if not rows then return {}, {} end
    if GP.catalogRows ~= rows then
        GP.catalogList, GP.catalogByName = GP.Sources.Catalog(ForeverDB, GP.DungeonData, rows)
        GP.catalogRows = rows
    end
    return GP.catalogList, GP.catalogByName
end
-- Raids in WoW Forever (Blizzard's raid overview, Oct 20, 2026: Barrow Deeps, Hyjal Summit, Onyxia's Lair). The
-- Classic raids in the data (Molten Core, Blackwing Lair, ...) are not announced for Forever.
-- opens: the announced opening day (provisional until it has passed); later raids get their own date here.
GP.FOREVER_RAIDS = {
    ["Onyxia's Lair"] = { opens = "2026-12-09" },
    ["Barrow Deeps"] = { opens = "2026-12-09" },
    ["Hyjal Summit"] = { opens = "2026-12-09" },
}
function GP.ForeverRaid(name) return name ~= nil and GP.FOREVER_RAIDS[name] ~= nil end
-- Opening day of a confirmed raid that is not open yet ("09.12.2026"), nil when open (or unknown).
function GP.RaidOpens(name)
    local info = name and GP.FOREVER_RAIDS[name]
    if not (info and info.opens) then return nil end
    local today = date and date("%Y-%m-%d") or "0000-00-00"
    if today >= info.opens then return nil end
    local y, m, d = info.opens:match("(%d+)-(%d+)-(%d+)")
    return ("%s.%s.%s"):format(d, m, y)
end
-- Range of your dungeons: from dungeonBelow levels below to dungeonAbove levels above your level.
function GP.DungeonRange()
    local s = GP.settings
    return P.Range(GP.Player().level, s.dungeonBelow, s.dungeonAbove)
end
-- A dungeon is in your range when its level range overlaps it.
function GP.DungeonInRange(d, low, high)
    if not d then return false end
    if not low then low, high = GP.DungeonRange() end
    return (d.low or 1) <= high and (d.high or d.low or 1) >= low
end

-- Candidates of one source ("Bags", "Quests", "Dungeons") inside the level window.
-- Dungeons: low/high is the dungeon range; a drop counts when its dungeon overlaps the range (options.all: every
-- dungeon) and you can wear it by the top of the range. Returns entries, loading, state; state "missing" when
-- ForeverDB is not installed.
function GP.ReadCandidates(source, low, high, options)
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
    -- The catalog once, not per row (1.6.3: was asked thousands of times per page).
    local byName = source == "Dungeons" and select(2, GP.Catalog()) or nil
    for _, row in ipairs(rows) do
        local isDungeonQuest = row.dungeonQuest ~= nil
        local wanted = row.source ~= "Quests" or dungeonQuests == "show"
            or (dungeonQuests == "hide" and not isDungeonQuest) or (dungeonQuests == "only" and isDungeonQuest)
        local info = db.item[row.itemID]
        local required = info and info[3] or 0
        if wanted and row.exclusive and GP.Sources.Excluded(row) then wanted = false end
        local inWindow = row.level >= low and row.level <= high
        if source == "Dungeons" and row.source == source then
            inWindow = (options and options.all) or GP.DungeonInRange(byName[row.name], low, high)
        end
        if wanted and row.source == source and inWindow and required <= high
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
local pages = { upgrades = true, route = true, quests = true, dungeons = true, raids = true, shop = true, auction = true, wishlist = true, bags = true, gear = true, settings = true, help = true }
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
    if type(saved.routeDetour) ~= "number" or saved.routeDetour < 0 or saved.routeDetour > 1 then saved.routeDetour = 0.3 end
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
    saved.wishlist = type(saved.wishlist) == "table" and saved.wishlist or {}
    if saved.wishAlerts == nil then saved.wishAlerts = true end
    saved.bisTarget = (saved.bisTarget == "preraid" or saved.bisTarget == "raid") and saved.bisTarget or "now"
    if saved.minimap == nil then saved.minimap = true end
    if type(saved.custom) == "table" then P.SetCustom(saved.custom) end
    saved.questSort = (saved.questSort == "distance" or saved.questSort == "zone") and saved.questSort or "gain"
    saved.dungeonQuests = (saved.dungeonQuests == "hide" or saved.dungeonQuests == "only") and saved.dungeonQuests or "show"
    -- 1.0.2: own dungeon range, quests until grey, dungeons to go.
    saved.dungeonBelow = bounded(saved.dungeonBelow, 5, 0, 15)
    saved.dungeonAbove = bounded(saved.dungeonAbove, 3, 0, 15)
    saved.dungeonShow = saved.dungeonShow == "range" and "range" or "all"
    if saved.questsGrey == nil then saved.questsGrey = false end
    saved.togo = type(saved.togo) == "table" and saved.togo or {}
    if saved.togoAutoRemove == nil then saved.togoAutoRemove = false end
    if saved.mapReveal == nil then saved.mapReveal = true end
    -- 1.3.0 quest route
    saved.routeFocus = (saved.routeFocus == "xp" or saved.routeFocus == "gear") and saved.routeFocus or "balanced"
    saved.routeDungeon = saved.routeDungeon == true
    GearPilotProSettings = saved
    GP.settings = saved
end

-- Other addons ------------------------------------------------------------------------------------------------
-- Opens a recipe in CraftPilot: its profession, the recipe selected (as CraftPilot's own item database does).
-- Falls back to CraftPilot's item database for the product.
function GP.OpenRecipe(profession, recipeID, itemID)
    local cp = GP.CraftPilot()
    if not cp then return end
    if cp.OpenRecipe and pcall(cp.OpenRecipe, cp, profession, recipeID) then return end
    local ok = cp.ChangeView and cp.OpenTab and cp.db and cp.db.ui and pcall(function()
        cp:ChangeView(profession, false)
        cp.db.ui.selectedRecipes = cp.db.ui.selectedRecipes or {}
        cp.db.ui.selectedRecipes[profession] = recipeID
        cp:OpenTab("now")
    end)
    if not ok and cp.OpenItemInDB and itemID then pcall(cp.OpenItemInDB, cp, itemID) end
end

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
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_TALENT_UPDATE"
        or event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        GP.GearChanged()
    end
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        initialize()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if not pending[arg] then return end
        pending[arg] = nil
        if not success then missing[arg] = true end
        -- Items arrive in bursts of hundreds: one redraw a second instead of one every few items (1.7.1).
        if GP.ScheduleRefresh then GP.ScheduleRefresh(1) end
        return
    end
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
end)

SLASH_GEARPILOTPRO1 = "/gpp"
SLASH_GEARPILOTPRO2 = "/gearpilotpro"
SlashCmdList.GEARPILOTPRO = function(text)
    local command, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if (command == "ep" or command == "xp") and tonumber(rest) then
        GP.QuestXP.Test(tonumber(rest))
        return
    end
    if command == "speicher" or command == "memory" or command == "mem" then
        GP.Diagnostics.StartMemoryWatch(tonumber(rest) or 60)
        return
    end
    if command == "tracker" or command == "route" then
        GP.Tracker.Toggle()
        return
    end
    if GP.Toggle then GP.Toggle() end
end
