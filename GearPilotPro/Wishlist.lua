-- Wishlist: items you want, where they come from, waypoints there, and hints when one is close.
-- Saved per character in GearPilotProSettings.wishlist = { [itemID] = { goal, price, added, got } }.
local _, GP = ...
local P, L, S = GP.Planner, GP.L, GP.Style
local Wish = {}
GP.Wish = Wish

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end
local function list()
    GP.settings.wishlist = type(GP.settings.wishlist) == "table" and GP.settings.wishlist or {}
    return GP.settings.wishlist
end
Wish.List = list

local function itemID(ref)
    if type(ref) == "number" then return ref end
    return tonumber(tostring(ref or ""):match("item:(%d+)"))
end
function Wish.Has(ref)
    local id = itemID(ref)
    return id and GP.settings and type(GP.settings.wishlist) == "table" and GP.settings.wishlist[id] ~= nil or false
end
function Wish.Add(ref, goal)
    local id = itemID(ref)
    if not id or not GP.settings then return false end
    local items = list()
    items[id] = items[id] or { added = time and time() or 0 }
    if goal then Wish.SetGoal(id, true) end
    local item = GP.ItemData(id)
    say(L("On your wishlist: ") .. (item.link or item.name or ("#" .. id)))
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
    return true
end
function Wish.Remove(ref)
    local id = itemID(ref)
    if id and GP.settings then list()[id] = nil end
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
end
function Wish.Toggle(ref)
    if Wish.Has(ref) then Wish.Remove(ref) else Wish.Add(ref) end
end
-- One goal per slot (two for rings and trinkets): marking a goal clears the old goal of that slot.
function Wish.SetGoal(id, on)
    local items = list()
    if not items[id] then return end
    if on then
        local item = GP.ItemData(id)
        local slots = item.equip and P.targetSlots[item.equip]
        local limit = slots and #slots or 1
        local same = {}
        for otherID, data in pairs(items) do
            if otherID ~= id and data.goal then
                local other = GP.ItemData(otherID)
                if other.equip and slots and P.targetSlots[other.equip] == slots then same[#same + 1] = otherID end
            end
        end
        while #same >= limit do
            items[table.remove(same, 1)].goal = nil
        end
    end
    items[id].goal = on or nil
end
function Wish.SetPrice(id, copper)
    local items = list()
    if items[id] then items[id].price = copper and copper > 0 and copper or nil end
end

-- In bags, bank or worn.
function Wish.Owned(id)
    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, id, true)
        if ok and count and count > 0 then return true end
    elseif GetItemCount and GetItemCount(id, true) > 0 then
        return true
    end
    for _, slot in ipairs(P.slots) do
        local link = GetInventoryItemLink("player", slot[1])
        if link and tonumber(link:match("item:(%d+)")) == id then return true end
    end
    return false
end

-- All sources of a wishlist item with ForeverDB and, if installed, CraftPilot's recipes.
function Wish.Sources(id)
    local db = GP.Sources.Database()
    if not db then return {} end
    local player = GP.Player()
    local cp = GP.CraftPilot()
    return (GP.Sources.ItemSources(db, id, { faction = player.faction, raceBit = player.raceBit, class = player.class,
        catalog = cp and cp.CatalogData, att = GP.DungeonData }))
end

-- Goals reached: "9 of 17 slots".
function Wish.Progress()
    local goals, reached = 0, 0
    for id, data in pairs(list()) do
        if data.goal then
            goals = goals + 1
            if data.got or Wish.Owned(id) then reached = reached + 1 end
        end
    end
    return reached, goals
end

-- Received: tick off and say so once.
local function checkReceived()
    if not GP.settings or type(GP.settings.wishlist) ~= "table" then return end
    for id, data in pairs(GP.settings.wishlist) do
        if not data.got and Wish.Owned(id) then
            data.got = true
            local item = GP.ItemData(id)
            say("|cff85d6a0" .. L("Wishlist item received: ") .. "|r" .. (item.link or item.name or ("#" .. id)))
        end
    end
end

-- Auction house alarm: a wishlist item in the scan (at or below its wish price).
local alarmed = {}
local function checkAuction()
    if not (GP.settings and GP.settings.wishAlerts ~= false and GP.HasAuctionPrices()) then return end
    for id, data in pairs(list()) do
        if not data.got then
            local price = GP.AuctionPrice(id)
            local age = GP.AuctionAge(id)
            local fresh = age == nil or age <= 1
            local key = id .. ":" .. tostring(price)
            if price and fresh and (not data.price or price <= data.price) and not alarmed[key] then
                alarmed[key] = true
                local item = GP.ItemData(id)
                local text = L("Wishlist item in the auction house: ") .. (item.link or item.name or ("#" .. id)) .. " · "
                    .. (GetCoinTextureString and GetCoinTextureString(price) or tostring(price))
                say("|cff85d6a0" .. text .. "|r")
                if UIErrorsFrame then UIErrorsFrame:AddMessage(text, .52, .84, .63) end
            end
        end
    end
end
Wish.CheckAuction = checkAuction

-- Drop hints: the target, or the dungeon you just entered, can drop a wishlist item.
local hinted = {}
local function dropIndex()
    local ids = {}
    for id, data in pairs(list()) do
        if not data.got then ids[#ids + 1] = id end
    end
    return GP.Sources.DropIndex(ForeverDB, GP.DungeonData, ids)
end
local function chanceText(chance)
    return chance and chance > 0 and (" (" .. ("%d %%"):format(math.floor(chance / 100 + .5)) .. ")") or ""
end
local function checkTarget()
    if not (GP.settings and GP.settings.wishAlerts ~= false) then return end
    local guid = UnitGUID and UnitGUID("target")
    -- The 12.x client hands out some unit values as "secret" values (in combat, for some units): those cannot be
    -- read by addons, so the hint is skipped then.
    if guid == nil or (issecretvalue and issecretvalue(guid)) or (canaccessvalue and not canaccessvalue(guid)) then return end
    local ok, id = pcall(string.match, guid, "^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    local npcID = ok and tonumber(id) or nil
    if not npcID or hinted["npc" .. npcID] then return end
    local byNpc = dropIndex()
    local found = byNpc[npcID]
    if found then
        hinted["npc" .. npcID] = true
        for _, drop in ipairs(found) do
            local item = GP.ItemData(drop.id)
            say(L("This target can drop a wishlist item: ") .. (item.link or item.name or ("#" .. drop.id)) .. chanceText(drop.chance))
        end
    end
end
local function checkInstance()
    if not (GP.settings and GP.settings.wishAlerts ~= false and GetInstanceInfo) then return end
    local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    if not instanceID or hinted["map" .. instanceID] then return end
    local _, byMap = dropIndex()
    local found = byMap[instanceID]
    if found then
        hinted["map" .. instanceID] = true
        for _, drop in ipairs(found) do
            local item = GP.ItemData(drop.id)
            say(L("Wishlist item in this dungeon: ") .. (item.link or item.name or ("#" .. drop.id))
                .. (drop.boss and (" · " .. drop.boss) or "") .. chanceText(drop.chance))
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if not GP.settings then return end
    -- Outside the click that changed the target, so nothing of GearPilot runs inside the game's own code.
    if event == "PLAYER_TARGET_CHANGED" then
        if C_Timer then C_Timer.After(0, checkTarget) else checkTarget() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(2, checkInstance)
        if event == "ZONE_CHANGED_NEW_AREA" then return end
    end
    if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        C_Timer.After(1, checkAuction)
        return
    end
    if event == "PLAYER_LOGIN" then
        -- Auctionator tells registered addons when its price data changes (newer versions).
        local api = GP.HasAuctionPrices() and Auctionator.API.v1
        if api and api.RegisterForDBUpdate then pcall(api.RegisterForDBUpdate, "GearPilot", function() C_Timer.After(1, checkAuction) end) end
    end
    checkReceived()
end)

-- Ctrl+Alt-click on an item (bags, links, quest rewards, loot) puts it on the wishlist or takes it off.
-- Alt-click alone stays with CraftPilot.
if hooksecurefunc and HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not (GP.settings and link and IsAltKeyDown and IsAltKeyDown() and IsControlKeyDown and IsControlKeyDown()) then return end
        if not link:find("item:", 1, true) then return end
        if Wish.Has(link) then
            Wish.Remove(link)
            say(L("Removed from your wishlist."))
        else
            Wish.Add(link)
        end
    end)
end

-- Text dialog for export and import.
local dialog
function Wish.Dialog(mode, text)
    if not dialog then
        local C = S.palette
        dialog = CreateFrame("Frame", "GearPilotProWishText", UIParent, "BackdropTemplate")
        S.Round(dialog)
        dialog:SetBackdropColor(C.window[1], C.window[2], C.window[3], 1)
        dialog:SetSize(520, 170)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        tinsert(UISpecialFrames, "GearPilotProWishText")
        dialog.title = S.Text(dialog, "GameFontNormalLarge", 18, 16, 460)
        dialog.hint = S.Text(dialog, "GameFontHighlightSmall", 18, 42, 480)
        local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -6, -6)
        dialog.box = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        dialog.box:SetSize(470, 22)
        dialog.box:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -86)
        dialog.box:SetAutoFocus(true)
        dialog.box:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.action = S.Primary(S.Button(dialog, 160, 26, L("Import"), nil))
        dialog.action:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 14)
        dialog.status = S.Text(dialog, "GameFontHighlightSmall", 18, 124, 300)
    end
    dialog.status:SetText("")
    if mode == "export" then
        dialog.title:SetText(L("Export wishlist"))
        dialog.hint:SetText(L("Copy the text (Ctrl+C) and share it. Goals are marked with !"))
        dialog.box:SetText(text or "")
        dialog.box:HighlightText()
        dialog.action:Hide()
    else
        dialog.title:SetText(L("Import wishlist"))
        dialog.hint:SetText(L("Paste a GearPilot wishlist text (GP1:...). Items are added to your list."))
        dialog.box:SetText("")
        dialog.action:Show()
        dialog.action:SetScript("OnClick", function()
            local items = P.ImportWishlist(dialog.box:GetText())
            if not items then
                dialog.status:SetText("|cffeb786b" .. L("No GearPilot wishlist found in the text.") .. "|r")
                return
            end
            local count = 0
            for id, data in pairs(items) do
                local existing = list()[id]
                list()[id] = existing or { added = time and time() or 0 }
                if data.goal then Wish.SetGoal(id, true) end
                count = count + 1
            end
            dialog:Hide()
            say((L("%d items imported to your wishlist.")):format(count))
            if GP.Render then GP.Render() end
        end)
    end
    dialog:Show()
end
