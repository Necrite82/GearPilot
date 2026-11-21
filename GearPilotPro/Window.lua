-- GearPilot main window in the CraftPilot layout: sidebar on the left, page title in the header,
-- list on the left and details on the right.
local _, GP = ...
local P, L, S, St = GP.Planner, GP.L, GP.Style, GP.Stats
local C = S.palette
local W, H, SIDE, LIST = 760, 600, 180, 310
local U = { rows = {}, lines = {}, nav = {}, profileItems = {}, controls = {} }

local function color(t, c) t:SetTextColor(c[1], c[2], c[3]) end
local function number(v)
    if math.abs(v - math.floor(v + .5)) < .05 then return tostring(math.floor(v + .5)) end
    return ("%.1f"):format(v)
end
local function signed(v) return (v >= 0 and "+" or "-") .. number(math.abs(v)) end
local function tooltip(owner, title, lines)
    owner:HookScript("OnEnter", function()
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(type(title) == "function" and title() or title)
        for _, line in ipairs(type(lines) == "function" and lines() or lines or {}) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Window -----------------------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "GearPilotProWindow", UIParent, "BackdropTemplate")
S.Round(frame)
frame:SetBackdropColor(C.window[1], C.window[2], C.window[3], 1)
frame:SetSize(W, H)
frame:SetPoint("CENTER", UIParent, "CENTER", SIDE / 2, 0)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetClampRectInsets(-SIDE, 0, 0, 0)
frame:SetMovable(true)
frame:SetResizable(true)
if frame.SetResizeBounds then frame:SetResizeBounds(W, H, 1300, 950) end
frame:EnableMouse(true)
frame:Hide()
tinsert(UISpecialFrames, "GearPilotProWindow")

local function saveWindow()
    if not GP.settings then return end
    local point, _, relative, x, y = frame:GetPoint()
    GP.settings.window = { point = point, relative = relative, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight() }
end
local function startMove() frame:StartMoving() end
local function stopMove() frame:StopMovingOrSizing(); saveWindow() end
-- Size grip in the bottom right corner, as in CraftPilot.
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(18, 18)
grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); saveWindow() end)
local function listWidth()
    return math.max(LIST, math.floor((frame:GetWidth() - 36) * 0.42))
end
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
header:SetHeight(92)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", startMove)
header:SetScript("OnDragStop", stopMove)
U.pageTitle = S.Text(header, "GameFontNormalLarge", 18, 25, W - 330)
U.pageSub = S.Text(header, "GameFontHighlightSmall", 18, 49, W - 60)
U.pageSub:SetTextColor(.72, .70, .66)
-- 1.3.5: close button in GearPilot's own style instead of the red default.
local close = S.Button(header, 26, 24, "x", function() frame:Hide() end)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -12)
local line = frame:CreateTexture(nil, "ARTWORK")
line:SetHeight(1)
line:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -94)
line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -94)
line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

-- Header chips: level window and data status. A click opens the settings.
local function chip(width)
    local b = CreateFrame("Frame", nil, header, "BackdropTemplate")
    S.Round(b)
    b:EnableMouse(true)
    b:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1)
    b:SetFrameLevel(header:GetFrameLevel() + 5)
    b:SetSize(width, 22)
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetSize(7, 7)
    b.dot:SetPoint("LEFT", b, "LEFT", 9, 0)
    b.dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    b.label = S.Text(b, "GameFontHighlightSmall", 21, 5, width - 28)
    b.label:SetWordWrap(false)
    return b
end
U.dataChip = chip(130)
U.dataChip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, -30)
U.rangeChip = chip(184)
U.rangeChip:SetPoint("RIGHT", U.dataChip, "LEFT", -8, 0)
U.dungeonChip = chip(130)
U.dungeonChip:SetPoint("RIGHT", U.rangeChip, "LEFT", -8, 0)
tooltip(U.dungeonChip, function() return L("Dungeon range") end, function()
    return { L("Dungeons whose level range overlaps this range count for your upgrades. Set it in the settings.") }
end)
tooltip(U.rangeChip, function() return L("Level range") end, function()
    return { L("Quests and the other sources in this range are compared; dungeons have their own range. Bag items are always compared.") }
end)
tooltip(U.dataChip, "ForeverDB", function()
    local build = GP.Sources.BuildDate()
    if build then return { L("Quest rewards and dungeon drops from ForeverDB (GPL-3.0)."), L("Data from ") .. build,
        L("Bosses and loot of the new Forever dungeons: AllTheThings (MIT).") } end
    return { L("ForeverDB is not installed. Quests and dungeons need it; the CurseForge app installs it with GearPilot.") }
end)

-- Footer
local footLine = frame:CreateTexture(nil, "ARTWORK")
footLine:SetHeight(1)
footLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 32)
footLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 32)
footLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
U.footer = S.Text(frame, "GameFontDisableSmall", 18, 0, W - 36)
U.footer:ClearAllPoints()
U.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 11)
U.footer:SetWordWrap(false)

-- Sidebar ------------------------------------------------------------------------------------------------------
local side = CreateFrame("Frame", "GearPilotProSidebar", frame, "BackdropTemplate")
S.Round(side)
side:SetBackdropColor(C.window[1], C.window[2], C.window[3], 1)
side:SetWidth(SIDE)
side:SetPoint("TOPRIGHT", frame, "TOPLEFT", 1, 0)
side:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 1, 0)
side:EnableMouse(true)
side:RegisterForDrag("LeftButton")
side:SetScript("OnDragStart", startMove)
side:SetScript("OnDragStop", stopMove)
local logo = side:CreateTexture(nil, "ARTWORK")
logo:SetSize(30, 30)
logo:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -14)
logo:SetTexture("Interface\\AddOns\\GearPilotPro\\Media\\GearPilot")
S.Text(side, "GameFontNormalLarge", 52, 14, SIDE - 60, "GearPilot")
S.Text(side, "GameFontDisableSmall", 52, 33, SIDE - 60, L("Gear companion"))

-- Profile menu, like CraftPilot's profession menu.
U.profileButton = S.Button(side, SIDE - 16, 30, "", function()
    U.profileMenu:SetShown(not U.profileMenu:IsShown())
    if U.profileMenu:IsShown() then U.renderProfileMenu() end
end)
U.profileButton:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -54)
tooltip(U.profileButton, function() return L("Stat profile") end, function()
    return { L("Which values count. Provisional weights; weapon DPS is included, random proc effects are not.") }
end)
U.character = S.Text(side, "GameFontDisableSmall", 14, 90, SIDE - 28)
U.profileMenu = S.Surface(frame, "raised")
U.profileMenu:SetFrameStrata("DIALOG")
U.profileMenu:SetPoint("TOPLEFT", U.profileButton, "TOPRIGHT", 6, 0)
U.profileMenu:Hide()
local function renderProfileMenu()
    local options = { { key = "auto", name = "Automatic (talents)" } }
    for _, profile in ipairs(P.All()) do options[#options + 1] = profile end
    for _, b in ipairs(U.profileItems) do b:Hide() end
    for i, option in ipairs(options) do
        local b = U.profileItems[i]
        if not b then
            b = S.Button(U.profileMenu, 198, 26, "", function(self)
                if self.profile == "auto" then
                    GP.settings.autoProfile = true
                else
                    GP.settings.autoProfile = false
                    GP.settings.profile = self.profile
                end
                U.profileMenu:Hide()
                GP.Render()
            end)
            b:SetPoint("TOPLEFT", U.profileMenu, "TOPLEFT", 8, -8 - (i - 1) * 30)
            U.profileItems[i] = b
        end
        b.profile = option.key
        b:SetText(L(option.name))
        local on = (option.key == "auto" and GP.settings.autoProfile) or (not GP.settings.autoProfile and GP.settings.profile == option.key)
        S.Segment(b, on)
        b:Show()
    end
    U.profileMenu:SetSize(214, 16 + #options * 30)
end
U.renderProfileMenu = renderProfileMenu

local navIcons = {
    upgrades = "Interface\\Icons\\INV_Sword_04", quests = "Interface\\Icons\\INV_Misc_Note_01",
    dungeons = "Interface\\Icons\\INV_Misc_Head_Dragon_01", shop = "Interface\\Icons\\INV_Misc_Coin_02",
    auction = "Interface\\Icons\\INV_Misc_Coin_04", wishlist = "Interface\\Icons\\INV_Misc_Note_06",
    bags = "Interface\\Icons\\INV_Misc_Bag_08", gear = "Interface\\Icons\\INV_Chest_Cloth_17",
    settings = "Interface\\Icons\\INV_Misc_Gear_01", help = "Interface\\Icons\\INV_Misc_QuestionMark",
    route = "Interface\\Icons\\INV_Misc_Map_01",
}
local function navButton(key, caption)
    local b = CreateFrame("Button", nil, side)
    b:SetSize(SIDE - 16, 34)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(1, 1, 1, 0)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, .05)
    b.iconBox = b:CreateTexture(nil, "BORDER")
    b.iconBox:SetSize(26, 26)
    b.iconBox:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.iconBox:SetColorTexture(.91, .68, .31, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("CENTER", b.iconBox, "CENTER", 0, 0)
    b.icon:SetTexture(navIcons[key])
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFontObject(S.Font("GameFontNormal"))
    b.label:SetPoint("LEFT", b, "LEFT", 40, 0)
    b.label:SetPoint("RIGHT", b, "RIGHT", -30, 0)
    b.label:SetJustifyH("LEFT")
    b.label:SetText(caption)
    b.badge = b:CreateFontString(nil, "OVERLAY")
    b.badge:SetFontObject(S.Font("GameFontHighlightSmall"))
    b.badge:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.badge:SetTextColor(.94, .82, .54)
    b:SetScript("OnClick", function() GP.Open(key) end)
    b.key = key
    U.nav[#U.nav + 1] = b
    return b
end
local mainPages = {
    { key = "upgrades", label = L("Best upgrades") }, { key = "route", label = L("Quest route") }, { key = "quests", label = L("Quests") },
    { key = "dungeons", label = L("Dungeons") }, { key = "raids", label = L("Raids") }, { key = "shop", label = L("Buy & craft") },
    { key = "auction", label = L("Auction house") }, { key = "wishlist", label = L("Wishlist") },
    { key = "bags", label = L("Bags") }, { key = "gear", label = L("Equipped gear") },
}
for i, page in ipairs(mainPages) do
    navButton(page.key, page.label):SetPoint("TOPLEFT", side, "TOPLEFT", 8, -124 - (i - 1) * 34)
end
navButton("settings", L("Settings")):SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 8, 96)
navButton("help", L("Help")):SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 8, 60)
local sideLine = side:CreateTexture(nil, "ARTWORK")
sideLine:SetHeight(1)
sideLine:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 1, 54)
sideLine:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -1, 54)
sideLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
U.sideData = S.Text(side, "GameFontDisableSmall", 14, 0, SIDE - 24, L("Data: ForeverDB (GPL-3.0)"))
U.sideData:ClearAllPoints()
U.sideData:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 14, 32)
U.sideFoot = S.Text(side, "GameFontDisableSmall", 14, 0, SIDE - 24)
U.sideFoot:ClearAllPoints()
U.sideFoot:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 14, 12)

-- List and detail ------------------------------------------------------------------------------------------------
local TOP, BOTTOM = 104, 44
U.listPanel = S.Surface(frame, "panel")
U.listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.listPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, BOTTOM)
U.listPanel:SetWidth(LIST)
U.listScroll = CreateFrame("ScrollFrame", nil, U.listPanel, "UIPanelScrollFrameTemplate")
U.listScroll:SetPoint("TOPLEFT", U.listPanel, "TOPLEFT", 6, -6)
U.listScroll:SetPoint("BOTTOMRIGHT", U.listPanel, "BOTTOMRIGHT", -26, 6)
U.listContent = CreateFrame("Frame", nil, U.listScroll)
U.listContent:SetSize(LIST - 32, 10)
U.listScroll:SetScrollChild(U.listContent)
U.empty = S.Text(U.listPanel, "GameFontDisableSmall", 14, 14, LIST - 28)

U.detailPanel = S.Surface(frame, "panel")
U.detailPanel:SetPoint("TOPLEFT", U.listPanel, "TOPRIGHT", 10, 0)
U.detailPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, BOTTOM)
U.detailScroll = CreateFrame("ScrollFrame", nil, U.detailPanel, "UIPanelScrollFrameTemplate")
U.detailScroll:SetPoint("TOPLEFT", U.detailPanel, "TOPLEFT", 6, -6)
U.detailScroll:SetPoint("BOTTOMRIGHT", U.detailPanel, "BOTTOMRIGHT", -26, 6)
U.detail = CreateFrame("Frame", nil, U.detailScroll)
U.detail:SetSize(W - LIST - 82, 10)
U.detailScroll:SetScrollChild(U.detail)
U.detailIcon = U.detail:CreateTexture(nil, "ARTWORK")
U.detailIcon:SetSize(40, 40)
U.detailIcon:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 10, -10)
U.detailIconHover = CreateFrame("Button", nil, U.detail)
U.detailIconHover:SetAllPoints(U.detailIcon)
U.detailIconHover:EnableMouse(true)
U.detailIconHover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
U.detailIconHover:SetScript("OnClick", function(_, button)
    if U.detailQuest then GP.QuestInfo.Click(U.detailQuest, U.detailQuestTitle, button) end
end)
U.detailIconHover:SetScript("OnEnter", function(self)
    if U.detailQuest then GP.QuestInfo.Show(self, U.detailQuest, U.detailQuestTitle); return end
    if not U.detailLink then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(U.detailLink)
    GameTooltip:Show()
end)
U.detailIconHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
U.detailName = S.Text(U.detail, "GameFontNormalLarge", 60, 11, 300)
U.detailSub = S.Text(U.detail, "GameFontDisableSmall", 60, 33, 300)
U.action = S.Button(U.detail, 120, 26, "", nil)
U.action:Hide()
U.action2 = S.Button(U.detail, 120, 26, "", nil)
U.action2:Hide()
U.action3 = S.Button(U.detail, 90, 26, "", nil)
U.action3:Hide()

-- Filter bar above the list: every setting is one block (caption and options in one rounded box); the blocks
-- flow from left to right and wrap when the window is narrow.
U.bar = S.Surface(frame, "panel")
U.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -TOP)
U.bar:SetHeight(44)
U.bar.pills = {}
local function setting(path)
    local s = GP.settings
    if path:find("%.") then
        local a, b = path:match("([^.]+)%.(.+)")
        return s[a] and s[a][b]
    end
    return s[path]
end
local function setSetting(path, value)
    local s = GP.settings
    if path:find("%.") then
        local a, b = path:match("([^.]+)%.(.+)")
        s[a] = s[a] or {}
        s[a][b] = value
    else
        s[path] = value
    end
end
local function pill(pages, label)
    local p = S.Surface(U.bar, "raised")
    p:SetHeight(30)
    p.pages = {}
    for _, page in ipairs(pages) do p.pages[page] = true end
    p.caption = S.Text(p, "GameFontHighlightSmall", 10, 9, 0, L(label))
    p.caption:SetTextColor(.66, .64, .60)
    p.caption:SetWordWrap(false)
    local width = p.caption.GetStringWidth and p.caption:GetStringWidth() or nil
    p.captionWidth = math.floor((type(width) == "number" and width > 0 and width or #L(label) * 6) + 18)
    p.caption:SetWidth(p.captionWidth - 10)
    p.buttons = {}
    U.bar.pills[#U.bar.pills + 1] = p
    return p
end
local function actionPill(pages, label, width, actions)
    local p = pill(pages, label)
    for i, action in ipairs(actions) do
        local b = S.Button(p, width - 2, 24, L(action[1]), action[2])
        b:SetPoint("TOPLEFT", p, "TOPLEFT", p.captionWidth + (i - 1) * width, -3)
        b.action = true
    end
    p:SetWidth(p.captionWidth + #actions * width + 4)
    return p
end
local function segmentPill(pages, label, width, options, field, default)
    local p = pill(pages, label)
    for i, option in ipairs(options) do
        local b = S.Button(p, width - 2, 24, L(option[2]), function()
            setSetting(field, option[1])
            GP.Render()
        end)
        b:SetPoint("TOPLEFT", p, "TOPLEFT", p.captionWidth + (i - 1) * width, -3)
        b.field, b.value, b.default = field, option[1], default
        p.buttons[#p.buttons + 1] = b
    end
    p:SetWidth(p.captionWidth + #options * width + 4)
    return p
end
segmentPill({ "quests" }, "View", 100, { { "items", "Items" }, { "zones", "Zones" } }, "views.quests", "items")
segmentPill({ "quests" }, "Sort", 90, { { "gain", "Score" }, { "distance", "Distance" }, { "zone", "Zone" } }, "questSort", "gain")
segmentPill({ "quests" }, "Quest chains", 100, { { "all", "All" }, { "started", "Started" } }, "chains", "all")
segmentPill({ "quests" }, "Dungeon quests", 90, { { "show", "Show" }, { "hide", "Hide" }, { "only", "Only" } }, "dungeonQuests", "show")
segmentPill({ "dungeons" }, "View", 110, { { "items", "Items" }, { "overview", "Per dungeon" }, { "togo", "To go" } }, "views.dungeons", "items")
segmentPill({ "raids" }, "Show", 130, { { "forever", "WoW Forever" }, { "all", "All raids" } }, "raidShow", "forever")
local dungeonShow = segmentPill({ "dungeons" }, "Show", 120, { { "all", "All dungeons" }, { "range", "Only in range" } }, "dungeonShow", "all")
dungeonShow.when = function() return (GP.settings.views.dungeons or "items") == "overview" end
local function togoDungeons()
    local _, byName = GP.Catalog()
    local list = {}
    for _, entry in ipairs(GP.Togo.List()) do
        if byName[entry.name] then list[#list + 1] = byName[entry.name] end
    end
    return list
end
local prepare = actionPill({ "dungeons" }, "To go", 150, { { "Prepare all", function() GP.Togo.Prepare(togoDungeons()) end },
    { "Map", function()
        local ids, seen, entrances = {}, {}, {}
        for _, d in ipairs(togoDungeons()) do
            for _, id in ipairs(GP.Togo.NextSteps((GP.Togo.Quests(d)))) do
                if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
            local spot = ForeverDB and GP.Sources.Entrance(ForeverDB, d.name)
            if spot then entrances[#entrances + 1] = { spot = spot, title = GP.Sources.DungeonName(d) } end
        end
        GP.Map.Quests(L("Dungeons to go"), ids, entrances)
    end } })
prepare.when = function() return (GP.settings.views.dungeons or "items") == "togo" end
segmentPill({ "shop" }, "Source", 104, { { "all", "All" }, { "Vendors", "Vendors" }, { "Auction", "Auction house" }, { "Crafted", "Crafting" } }, "shopSource", "all")
segmentPill({ "shop" }, "Sort", 90, { { "gain", "Score" }, { "price", "Price" }, { "value", "Per gold" } }, "shopSort", "gain")
segmentPill({ "shop" }, "Max. price", 58, { { 0, "All" }, { 10000, "1g" }, { 100000, "10g" }, { 500000, "50g" } }, "shopMax", 0)
segmentPill({ "auction" }, "Sort", 90, { { "gain", "Score" }, { "price", "Price" }, { "value", "Per gold" } }, "ahSort", "gain")
segmentPill({ "auction" }, "Seen", 96, { { "all", "Any time" }, { "week", "This week" }, { "today", "Today" } }, "ahAge", "all")
local maxPill = segmentPill({ "auction" }, "Max. price", 56, { { 0, "All" }, { 10000, "1g" }, { 50000, "5g" }, { 200000, "20g" }, { 1000000, "100g" } }, "ahMax", 0)
-- Own amount: type the gold and press Enter.
U.goldBox = CreateFrame("EditBox", nil, maxPill, "InputBoxTemplate")
U.goldBox:SetSize(46, 20)
U.goldBox:SetPoint("TOPLEFT", maxPill, "TOPLEFT", maxPill:GetWidth() + 8, -5)
U.goldBox:SetAutoFocus(false)
U.goldBox:SetNumeric(true)
U.goldBox:SetMaxLetters(6)
U.goldBox:SetScript("OnEnterPressed", function(self)
    local gold = tonumber(self:GetText() or "")
    GP.settings.ahMax = gold and gold > 0 and gold * 10000 or 0
    self:ClearFocus()
    GP.Render()
end)
U.goldBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local goldLabel = S.Text(maxPill, "GameFontHighlightSmall", maxPill:GetWidth() + 58, 9, 20, "g")
goldLabel:SetTextColor(.88, .69, .31)
maxPill:SetWidth(maxPill:GetWidth() + 74)
segmentPill({ "bags" }, "View", 110, { { "upgrades", "Upgrades" }, { "clutter", "Can go" } }, "views.bags", "upgrades")
-- 1.5.0: the route page has views: the route, choosing quests for your own route, your quest log, remembered
-- and skipped quests.
local function routeView() return GP.settings.views.route or "route" end
segmentPill({ "route" }, "View", 96, { { "route", "Route" }, { "pick", "Choose quests" }, { "class", "Class quests" },
    { "log", "Quest log" }, { "later", "Remembered" }, { "skipped", "Skipped" } }, "views.route", "route")
local routeMode = segmentPill({ "route" }, "Route from", 110, { { "auto", "Automatic" }, { "mine", "My quests" } }, "routeMode", "auto")
routeMode.when = function() local v = routeView(); return v == "route" or v == "pick" end
local routeFocus = segmentPill({ "route" }, "Focus", 110, { { "xp", "Experience" }, { "balanced", "Balanced" }, { "gear", "Gear" } }, "routeFocus", "balanced")
routeFocus.when = function() return routeView() == "route" and GP.settings.routeMode ~= "mine" end
local routeDungeon = segmentPill({ "route" }, "Dungeon quests", 110, { { false, "Hide" }, { true, "Show" } }, "routeDungeon", false)
routeDungeon.when = function() local v = routeView(); return v == "route" or v == "pick" end
local routeEscort = segmentPill({ "route" }, "Escort quests", 110, { { false, "Hide" }, { true, "Show" } }, "routeEscort", false)
routeEscort.when = function() return routeView() == "route" end
local pickRange = segmentPill({ "route" }, "Show", 110, { { "near", "Nearby" }, { "all", "All zones" } }, "routePick", "near")
pickRange.when = function() return routeView() == "pick" end
local routeOrder = actionPill({ "route" }, "Own order", 120, { { "Automatic order", function() GP.QuestRoute.ResetOrder() end } })
routeOrder.when = function() return routeView() == "route" and GP.QuestRoute.Ordered() end
local routeActions = actionPill({ "route" }, "Route", 90, {
    { "Go", function()
        GP.QuestRoute.Follow(true, true)
        if GP.Tracker then GP.Tracker.Show() end
    end },
    { "Tracker", function() GP.Tracker.Toggle() end },
    { "Map", function()
        local plan = GP.QuestRoute.Current()
        local points = {}
        for i, t in ipairs(plan and plan.tasks or {}) do
            if not GP.QuestRoute.TaskDone(t) then
                local uiMap, x, y = GP.QuestRoute.MapPoint(t)
                if uiMap and x then
                    points[#points + 1] = { uiMap = uiMap, x = x, y = y, label = tostring(i), questID = t.kind == "accept" and t.quest.id or nil,
                        infoQuest = t.quest.id,
                        kind = t.kind == "accept" and "quest" or t.kind == "turnin" and "active" or "done",
                        title = GP.QuestRoute.Title(t.quest), sub = GP.QuestRoute.TaskText(t) }
                end
            end
        end
        GP.Map.Show(L("Quest route"), points)
    end },
    { "Stop", function() GP.QuestRoute.Follow(false) end },
})
routeActions.when = function() return routeView() == "route" end
segmentPill({ "gear" }, "View", 110, { { "worn", "Equipped" }, { "weapons", "Weapon setup" } }, "views.gear", "worn")
segmentPill({ "gear" }, "Weapons from", 110, { { "own", "Worn & bags" }, { "all", "All sources" } }, "weaponPool", "own")
segmentPill({ "wishlist" }, "View", 130, { { "list", "My wishlist" }, { "bis", "BIS (calculated)" } }, "views.wishlist", "list")
local bisTarget = segmentPill({ "wishlist" }, "BIS for", 110, { { "now", "Your range" }, { "preraid", "60 pre-raid" }, { "raid", "60 with raids" } }, "bisTarget", "now")
bisTarget.when = function() return (GP.settings.views.wishlist or "list") == "bis" end
local share = actionPill({ "wishlist" }, "Share", 90, { { "Export", function() GP.Wish.Dialog("export", P.ExportWishlist(GP.Wish.List())) end },
    { "Import", function() GP.Wish.Dialog("import") end } })
share.when = function() return (GP.settings.views.wishlist or "list") == "list" end
local adopt = actionPill({ "wishlist" }, "List", 190, { { "Take over as goals", function() if GP.AdoptBis then GP.AdoptBis() end end } })
adopt.when = function() return (GP.settings.views.wishlist or "list") == "bis" end

-- Slot filter: a menu button with an arrow, so it reads as a choice list ("Filter: slot").
local slotGroups = {
    { "all", "All slots" }, { "weapons", "Weapons (all)", { 16, 17, 18 } }, { "16", "Main hand", { 16 } },
    { "17", "Off hand", { 17 } }, { "18", "Ranged slot", { 18 } }, { "1", "Head", { 1 } }, { "2", "Neck", { 2 } },
    { "3", "Shoulders", { 3 } }, { "15", "Back", { 15 } }, { "5", "Chest", { 5 } }, { "9", "Wrists", { 9 } },
    { "10", "Hands", { 10 } }, { "6", "Waist", { 6 } }, { "7", "Legs", { 7 } }, { "8", "Feet", { 8 } },
    { "rings", "Rings", { 11, 12 } }, { "trinkets", "Trinkets", { 13, 14 } },
}
local function slotGroup()
    local key = GP.settings and GP.settings.slotFilter or "all"
    for _, group in ipairs(slotGroups) do
        if group[1] == key then return group end
    end
    return slotGroups[1]
end
function GP.SlotAllowed(slot)
    local group = slotGroup()
    if not group[3] then return true end
    for _, value in ipairs(group[3]) do
        if value == slot then return true end
    end
    return false
end
local slotPill = pill({ "upgrades", "quests", "dungeons", "shop", "auction", "bags", "wishlist" }, "Filter: slot")
U.slotButton = S.Button(slotPill, 150, 24, "", function() U.slotMenu:SetShown(not U.slotMenu:IsShown()) end)
U.slotButton:SetPoint("TOPLEFT", slotPill, "TOPLEFT", slotPill.captionWidth, -3)
U.slotArrow = U.slotButton:CreateTexture(nil, "OVERLAY")
U.slotArrow:SetSize(12, 12)
U.slotArrow:SetPoint("RIGHT", U.slotButton, "RIGHT", -8, -2)
U.slotArrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
slotPill:SetWidth(slotPill.captionWidth + 154)
U.slotMenu = S.Surface(frame, "raised")
U.slotMenu:SetFrameStrata("DIALOG")
U.slotMenu:SetPoint("TOPRIGHT", U.slotButton, "BOTTOMRIGHT", 0, -4)
U.slotMenu:SetSize(186, 12 + #slotGroups * 26)
U.slotMenu:Hide()
U.slotItems = {}
for i, group in ipairs(slotGroups) do
    local b = S.Button(U.slotMenu, 170, 24, L(group[2]), function()
        GP.settings.slotFilter = group[1]
        U.slotMenu:Hide()
        GP.Render()
    end)
    b:SetPoint("TOPLEFT", U.slotMenu, "TOPLEFT", 8, -6 - (i - 1) * 26)
    b.key = group[1]
    U.slotItems[i] = b
end

-- 1.7.0: class quests of your class or, to look at, of another class.
local classPill = pill({ "route" }, "Class")
classPill.when = function() return (GP.settings.views.route or "route") == "class" end
U.classButton = S.Button(classPill, 150, 24, "", function() U.classMenu:SetShown(not U.classMenu:IsShown()) end)
U.classButton:SetPoint("TOPLEFT", classPill, "TOPLEFT", classPill.captionWidth, -3)
classPill:SetWidth(classPill.captionWidth + 154)
U.classMenu = S.Surface(frame, "raised")
U.classMenu:SetFrameStrata("DIALOG")
U.classMenu:SetPoint("TOPLEFT", U.classButton, "BOTTOMLEFT", 0, -4)
U.classMenu:SetSize(166, 12 + (#GP.ClassQuests.classes + 1) * 26)
U.classMenu:Hide()
for i, entry in ipairs({ { nil }, unpack(GP.ClassQuests.classes) }) do
    local class = entry[1]
    local b = S.Button(U.classMenu, 150, 24, class and GP.ClassQuests.ClassName(class) or L("Your class"), function()
        GP.settings.classView = class
        GP.selected["routeclassquest"] = nil
        U.classMenu:Hide()
        GP.Render()
    end)
    b:SetPoint("TOPLEFT", U.classMenu, "TOPLEFT", 8, -6 - (i - 1) * 26)
end

local function barRows(page)
    local available = frame:GetWidth() - 36 - 20
    local x, rows = 10, 0
    for _, p in ipairs(U.bar.pills) do
        local on = p.pages[page] == true and (not p.when or p.when())
        p:SetShown(on)
        if on then
            local w = p:GetWidth()
            if rows == 0 then rows = 1 elseif x > 10 and x + w > available + 10 then
                rows = rows + 1
                x = 10
            end
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", U.bar, "TOPLEFT", x, -(8 + (rows - 1) * 36))
            x = x + w + 8
            for _, b in ipairs(p.buttons) do S.Segment(b, (setting(b.field) or b.default) == b.value) end
        end
    end
    if slotPill:IsShown() then
        local group = slotGroup()
        U.slotButton:SetText(L(group[2]))
        if group[1] == "all" then
            U.slotButton:SetBackdropColor(.114, .133, .165, 1)
            local label = U.slotButton:GetFontString()
            if label then label:SetTextColor(.84, .83, .79) end
        else
            S.Primary(U.slotButton)
        end
        for _, b in ipairs(U.slotItems) do S.Segment(b, b.key == group[1]) end
    else
        U.slotMenu:Hide()
    end
    if page == "auction" and not U.goldBox:HasFocus() then
        local max = GP.settings.ahMax or 0
        local preset = max == 0 or max == 10000 or max == 50000 or max == 200000 or max == 1000000
        U.goldBox:SetText(preset and "" or tostring(math.floor(max / 10000)))
    end
    U.bar:SetShown(rows > 0)
    U.bar:SetHeight(rows * 36 + 10)
    return rows
end

-- Full-width scrolling surface for settings and help.
U.page = S.Surface(frame, "panel")
U.page:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, BOTTOM)
U.page:Hide()
U.pageScroll = CreateFrame("ScrollFrame", nil, U.page, "UIPanelScrollFrameTemplate")
U.pageScroll:SetPoint("TOPLEFT", U.page, "TOPLEFT", 6, -6)
U.pageScroll:SetPoint("BOTTOMRIGHT", U.page, "BOTTOMRIGHT", -26, 6)
U.pageContent = CreateFrame("Frame", nil, U.pageScroll)
U.pageContent:SetSize(W - 36 - 32, 10)
U.pageScroll:SetScrollChild(U.pageContent)

-- Rows ------------------------------------------------------------------------------------------------------------
local row, fillRow
-- Fills the row frames with the list entries in view (U.listState from Render).
local function drawRows()
    local st = U.listState
    if not st then return end
    local offset = U.listScroll:GetVerticalScroll() or 0
    local height = U.listScroll:GetHeight() or 400
    if height < 46 then height = 600 end
    local first = math.max(1, math.floor(offset / 46) + 1)
    local last = math.min(#st.list, first + math.ceil(height / 46))
    local used = 0
    for i = first, last do
        used = used + 1
        local r, data = row(used), st.list[i]
        r.key = data.key or data.entry.key
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", U.listContent, "TOPLEFT", 0, -(i - 1) * 46)
        r:SetWidth(st.width)
        local on = data == st.found
        if on then r:SetBackdropColor(.16, .18, .22, 1) else r:SetBackdropColor(0, 0, 0, 0) end
        r.stripe:SetShown(on)
        fillRow(r, st.kind, data, st.width, st.list)
        r:Show()
    end
    for j = used + 1, #U.rows do U.rows[j]:Hide() end
end
U.listScroll:HookScript("OnVerticalScroll", function() drawRows() end)
U.listScroll:HookScript("OnSizeChanged", function() drawRows() end)
function row(i)
    local r = U.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, U.listContent, "BackdropTemplate")
    S.Round(r, true)
    r:SetHeight(44)
    r.stripe = r:CreateTexture(nil, "OVERLAY")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -4)
    r.stripe:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 4)
    r.stripe:SetColorTexture(.91, .68, .31, 1)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.name = S.Text(r, "GameFontHighlight", 44, 6, 170)
    r.name:SetWordWrap(false)
    r.sub = S.Text(r, "GameFontDisableSmall", 44, 24, 170)
    r.sub:SetWordWrap(false)
    r.value = S.Text(r, "GameFontHighlight", 0, 14, 70, "", "RIGHT")
    r.value:ClearAllPoints()
    r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -14)
    r:SetScript("OnClick", function(self)
        GP.selected[GP.settings.page .. (GP.view or "")] = self.key
        GP.Render()
    end)
    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- 1.3.6: the quest icon shows the quest text, Shift-click links it, right-click shares it.
    r.quest = GP.QuestInfo.Hotspot(r, r.icon)
    r.quest.fallthrough = function() r:Click() end
    U.rows[i] = r
    return r
end

-- Detail lines: a pool of font strings placed one after another.
local detailY
local function detailLine(font, value, c, indent)
    local index = #U.lines.used + 1
    local t = U.lines[index]
    if not t then
        t = U.detail:CreateFontString(nil, "OVERLAY")
        t:SetJustifyH("LEFT")
        U.lines[index] = t
    end
    U.lines.used[index] = t
    local width = (U.detail:GetWidth() or 300) - 24 - (indent or 0)
    t:SetFontObject(S.Font(font))
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12 + (indent or 0), -detailY)
    t:SetWidth(width)
    t:SetText(value)
    c = c or C.text
    t:SetTextColor(c[1], c[2], c[3])
    t:Show()
    local h = t:GetStringHeight()
    detailY = detailY + math.max(14, h or 14) + 5
    return t
end
-- Item rows in detail lists: icon, name in its quality color, a second line, a value on the right and the
-- item tooltip on hover.
U.itemLines = {}
local function itemLine(item, sub, right, rightColor)
    U.itemLines.used = (U.itemLines.used or 0) + 1
    local i = U.itemLines.used
    local f = U.itemLines[i]
    if not f then
        f = CreateFrame("Button", nil, U.detail, "BackdropTemplate")
        S.Round(f, true)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(24, 24)
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
        f.name = S.Text(f, "GameFontHighlightSmall", 38, 5, 200)
        f.name:SetWordWrap(false)
        f.sub = S.Text(f, "GameFontDisableSmall", 38, 20, 200)
        f.sub:SetWordWrap(false)
        f.right = S.Text(f, "GameFontHighlightSmall", 0, 11, 90, "", "RIGHT")
        f.right:ClearAllPoints()
        f.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -11)
        f:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        U.itemLines[i] = f
    end
    local width = (U.detail:GetWidth() or 300) - 24
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
    f:SetSize(width, sub and 36 or 30)
    f:SetBackdropColor(.122, .141, .172, 1)
    f.link = item and item.link
    f.icon:SetTexture(item and item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.name:SetWidth(width - 140)
    f.sub:SetWidth(width - 140)
    f.name:SetText(item and (S.QualityColor(item.quality) .. (item.name or "?") .. "|r") or "?")
    f.sub:SetText(sub or "")
    f.right:SetText(right or "")
    f:SetAlpha(1)
    local c = rightColor or C.green
    f.right:SetTextColor(c[1], c[2], c[3])
    f:Show()
    detailY = detailY + (sub and 36 or 30) + 4
    return f
end

-- Source rows (wishlist): icon for the kind, two lines, a button on the right (waypoint, entrance, CraftPilot).
U.sourceLines = {}
local SOURCE_ICONS = {
    quest = "Interface\\GossipFrame\\AvailableQuestIcon", dungeon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    vendor = "Interface\\GossipFrame\\VendorGossipIcon", craft = "Interface\\Icons\\Trade_BlackSmithing",
    mob = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", world = "Interface\\Icons\\INV_Misc_Bag_10",
    auction = "Interface\\Icons\\INV_Misc_Coin_04", questdone = "Interface\\RaidFrame\\ReadyCheck-Ready",
    questactive = "Interface\\GossipFrame\\ActiveQuestIcon",
}
local function sourceLine2(kind, title, sub, buttonText, callback, mapCallback, indent, questID, questTitle)
    U.sourceLines.used = (U.sourceLines.used or 0) + 1
    local i = U.sourceLines.used
    local f = U.sourceLines[i]
    if not f then
        f = CreateFrame("Frame", nil, U.detail, "BackdropTemplate")
        S.Round(f)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(20, 20)
        f.icon:SetPoint("LEFT", f, "LEFT", 8, 0)
        f.title = S.Text(f, "GameFontHighlightSmall", 36, 6, 200)
        f.title:SetWordWrap(false)
        f.sub = S.Text(f, "GameFontDisableSmall", 36, 21, 200)
        f.sub:SetWordWrap(false)
        f.button = S.Button(f, 110, 22, "", nil)
        f.button:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        f.map = S.Button(f, 60, 22, L("Map"), nil)
        f.map:SetPoint("RIGHT", f.button, "LEFT", -6, 0)
        U.sourceLines[i] = f
    end
    indent = indent or 0
    local width = (U.detail:GetWidth() or 300) - 24 - indent
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12 + indent, -detailY)
    f:SetSize(width, 38)
    f:SetBackdropColor(.122, .141, .172, 1)
    f.icon:SetTexture(SOURCE_ICONS[kind] or SOURCE_ICONS.world)
    -- The quest hover only where a line is a quest (fewer frames for long loot lists).
    if questID and not rawget(f, "quest") then f.quest = GP.QuestInfo.Hotspot(f, f.icon) end
    GP.QuestInfo.Set(rawget(f, "quest"), questID, questTitle)
    local reserved = 160 + (mapCallback and 66 or 0)
    f.title:SetWidth(width - reserved)
    f.sub:SetWidth(width - reserved)
    f.title:SetText(title or "")
    f.sub:SetText(sub or "")
    f.button:SetShown(callback ~= nil)
    if callback then
        f.button:SetText(buttonText)
        f.button:SetScript("OnClick", callback)
    end
    f.map:SetShown(mapCallback ~= nil)
    f.map:ClearAllPoints()
    if callback then f.map:SetPoint("RIGHT", f.button, "LEFT", -6, 0) else f.map:SetPoint("RIGHT", f, "RIGHT", -6, 0) end
    if mapCallback then f.map:SetScript("OnClick", mapCallback) end
    f:Show()
    detailY = detailY + 42
end
U.priceBox = CreateFrame("EditBox", nil, U.detail, "InputBoxTemplate")
U.priceBox:SetSize(60, 20)
U.priceBox:SetAutoFocus(false)
U.priceBox:SetNumeric(true)
U.priceBox:SetMaxLetters(6)
U.priceBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
U.priceBox:Hide()

local function section(title)
    detailY = detailY + 8
    detailLine("GameFontNormal", title, C.gold)
end
-- Up to three buttons in a row: the first gold, the others plain (the third is usually "Map").
local function actions(first, second, third)
    detailY = detailY + 4
    U.action:SetText(first[1])
    U.action:SetWidth(first[3] or 170)
    S.Primary(U.action)
    U.action:SetScript("OnClick", first[2])
    U.action:ClearAllPoints()
    U.action:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
    U.action:Show()
    if second then
        U.action2:SetText(second[1])
        U.action2:SetWidth(second[3] or 150)
        U.action2:SetScript("OnClick", second[2])
        U.action2:ClearAllPoints()
        U.action2:SetPoint("LEFT", U.action, "RIGHT", 8, 0)
        U.action2:Show()
    end
    if third then
        U.action3:SetText(third[1])
        U.action3:SetWidth(third[3] or 90)
        U.action3:SetScript("OnClick", third[2])
        U.action3:ClearAllPoints()
        U.action3:SetPoint("LEFT", second and U.action2 or U.action, "RIGHT", 8, 0)
        U.action3:Show()
    end
    detailY = detailY + 34
end

-- A row of small buttons in the details (1.5.0: route order, skip, your own route).
U.tools = {}
local function tools(list)
    local x = 12
    for i, entry in ipairs(list) do
        local b = U.tools[i]
        if not b then b = S.Button(U.detail, 100, 24, "", nil); U.tools[i] = b end
        b:SetText(entry[1])
        b:SetWidth(entry[3] or 100)
        b:SetScript("OnClick", entry[2])
        b:SetEnabled(entry[4] ~= false)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", U.detail, "TOPLEFT", x, -detailY)
        b:Show()
        x = x + (entry[3] or 100) + 6
    end
    detailY = detailY + 32
end

-- Value bars like CraftPilot: each bar grows from the middle, right for a gain and left for a loss; its length
-- is the weighted effect on the score, so the bars show what makes an item better.
U.bars = {}
local function bar(i)
    local b = U.bars[i]
    if b then return b end
    b = {
        label = S.Text(U.detail, "GameFontHighlightSmall", 0, 0, 100),
        value = S.Text(U.detail, "GameFontHighlightSmall", 0, 0, 100, "", "RIGHT"),
        track = U.detail:CreateTexture(nil, "ARTWORK"), fill = U.detail:CreateTexture(nil, "OVERLAY"),
        zero = U.detail:CreateTexture(nil, "OVERLAY"),
    }
    b.track:SetHeight(4)
    b.track:SetColorTexture(.15, .17, .2, 1)
    b.fill:SetHeight(4)
    b.zero:SetSize(1, 8)
    b.zero:SetColorTexture(.30, .34, .40, 1)
    U.bars[i] = b
    return b
end
local function hideBars()
    for _, b in ipairs(U.bars) do
        b.label:Hide(); b.value:Hide(); b.track:Hide(); b.fill:Hide(); b.zero:Hide()
    end
end
local function statLines(diff, profile)
    if #diff == 0 then
        detailLine("GameFontDisableSmall", L("No value differences."), C.muted)
        return
    end
    local most = 0
    for _, d in ipairs(diff) do
        d.points = d.delta * (P.Weight(profile, d.key) or 0)
        most = math.max(most, math.abs(d.points))
    end
    local width = (U.detail:GetWidth() or 300) - 24
    for i, d in ipairs(diff) do
        local b = bar(i)
        local c = d.points > 0 and C.green or d.points < 0 and C.red or C.muted
        b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY); b.label:SetWidth(width)
        b.label:SetText(L(St.names[d.key] or d.key))
        b.value:ClearAllPoints(); b.value:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY); b.value:SetWidth(width)
        local points = d.points ~= 0 and ("  |cff9dabb8(" .. signed(d.points) .. ")|r") or ("  |cff9dabb8" .. L("(not weighted)") .. "|r")
        b.value:SetText(signed(d.delta) .. points)
        b.value:SetTextColor(c[1], c[2], c[3])
        b.track:ClearAllPoints(); b.track:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -(detailY + 16)); b.track:SetWidth(width)
        local half = width / 2
        local frac = most > 0 and math.abs(d.points) / most or 0
        b.fill:ClearAllPoints()
        if d.points >= 0 then b.fill:SetPoint("TOPLEFT", b.track, "TOPLEFT", half, 0)
        else b.fill:SetPoint("TOPRIGHT", b.track, "TOPLEFT", half, 0) end
        b.fill:SetWidth(math.max(1, half * frac))
        b.fill:SetColorTexture(c[1], c[2], c[3], 1)
        b.zero:ClearAllPoints(); b.zero:SetPoint("CENTER", b.track, "LEFT", half, 0)
        b.label:Show(); b.value:Show(); b.track:Show(); b.zero:Show(); b.fill:SetShown(frac > 0)
        detailY = detailY + 28
    end
end

-- Quest chain as steps: game quest icons (green check = done, yellow ? = in your quest log, yellow ! = next,
-- grey ! = later), a connector line, and the next open step highlighted.
U.steps = {}
local ICON_DONE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ICON_ACTIVE = "Interface\\GossipFrame\\ActiveQuestIcon"
local ICON_OPEN = "Interface\\GossipFrame\\AvailableQuestIcon"
local function step(i)
    local f = U.steps[i]
    if f then return f end
    f = CreateFrame("Frame", nil, U.detail, "BackdropTemplate")
    S.Round(f)
    f:SetHeight(40)
    f.stripe = f:CreateTexture(nil, "OVERLAY")
    f.stripe:SetWidth(2)
    f.stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
    f.stripe:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 5)
    f.stripe:SetColorTexture(.91, .68, .31, 1)
    f.line = f:CreateTexture(nil, "BACKGROUND")
    f.line:SetWidth(2)
    f.line:SetColorTexture(C.border[1] + .08, C.border[2] + .08, C.border[3] + .08, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(18, 18)
    f.icon:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.title = S.Text(f, "GameFontHighlightSmall", 36, 6, 200)
    f.title:SetWordWrap(false)
    f.sub = S.Text(f, "GameFontDisableSmall", 36, 22, 200)
    f.sub:SetWordWrap(false)
    f.badge = S.Text(f, "GameFontHighlightSmall", 0, 13, 100, "", "RIGHT")
    f.badge:ClearAllPoints()
    f.badge:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -13)
    f.quest = GP.QuestInfo.Hotspot(f, f.icon)
    U.steps[i] = f
    return f
end
U.progress = { track = U.detail:CreateTexture(nil, "ARTWORK"), fill = U.detail:CreateTexture(nil, "OVERLAY") }
U.progress.track:SetHeight(4)
U.progress.track:SetColorTexture(.15, .17, .2, 1)
U.progress.fill:SetHeight(4)
U.progress.fill:SetColorTexture(.52, .84, .63, 1)
local function hideSteps()
    for _, f in ipairs(U.steps) do f:Hide() end
    U.progress.track:Hide()
    U.progress.fill:Hide()
end
-- Quest chains open in full (by target quest) until the window closes; closed shows the first and the next step.
GP.chainOpen = {}
U.chainToggle = S.Button(U.detail, 220, 22, "", nil)
U.chainToggle:Hide()
local function chainSteps(chain, targetID)
    local done, nextIndex = P.ChainStatus(chain)
    local playerLevel = GP.Player().level
    local width = (U.detail:GetWidth() or 300) - 24
    local ids = {}
    for _, st in ipairs(chain) do ids[#ids + 1] = st.id end
    GP.QuestXP.Request(ids)
    -- Experience still open in this chain.
    local open = {}
    for _, st in ipairs(chain) do
        if not st.done and not st.skipped then open[#open + 1] = { id = st.id, level = st.level } end
    end
    local xp, _, unknown = GP.QuestXP.Sum(open)
    local xpText = (#open > 0 and xp > 0) and ("  ·  " .. (L("%s still open"):format(GP.QuestXP.Text(xp)))
        .. (unknown > 0 and (" " .. (L("(+%d without a value)"):format(unknown))) or "")) or ""
    detailY = detailY + 8
    detailLine("GameFontNormal", L("Quest chain") .. "  |cff9dabb8" .. (L("%d of %d done"):format(done, #chain)) .. xpText .. "|r", C.gold)
    U.progress.track:ClearAllPoints()
    U.progress.track:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
    U.progress.track:SetWidth(width)
    U.progress.fill:ClearAllPoints()
    U.progress.fill:SetPoint("TOPLEFT", U.progress.track, "TOPLEFT", 0, 0)
    U.progress.fill:SetWidth(math.max(1, width * done / #chain))
    U.progress.track:Show()
    U.progress.fill:SetShown(done > 0)
    detailY = detailY + 12
    local expanded = GP.chainOpen[targetID] or #chain <= 2
    local shown = 0
    for i, st in ipairs(chain) do
        if expanded or i == 1 or i == nextIndex then
            shown = shown + 1
            local f = step(shown)
            local isNext = i == nextIndex
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
            f:SetWidth(width)
            if isNext then f:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1) else f:SetBackdropColor(0, 0, 0, 0) end
            f.stripe:SetShown(isNext)
            local finished = st.done or st.skipped
            f.icon:SetTexture(finished and ICON_DONE or st.active and ICON_ACTIVE or ICON_OPEN)
            GP.QuestInfo.Set(f.quest, st.id, st.title)
            f.icon:SetDesaturated(st.skipped or (not st.done and not st.active and not isNext))
            f.icon:SetAlpha((st.done or st.active or isNext) and 1 or .55)
            f.line:ClearAllPoints()
            f.line:SetPoint("TOP", f.icon, "BOTTOM", 0, -2)
            f.line:SetHeight(18)
            f.line:SetShown(expanded and i < #chain)
            f.title:SetWidth(width - 160)
            f.sub:SetWidth(width - 160)
            f.title:SetText(("%d. %s"):format(i, st.title))
            local grey = not finished and P.IsGrey(st.level, playerLevel)
            -- 1.7.0: steps you cannot take yet (level) are greyed out with their level.
            local tooLow = not finished and not st.active and type(st.minLevel) == "number" and st.minLevel > playerLevel
            local c = st.id == targetID and C.gold or finished and { .62, .78, .66 } or (grey or tooLow) and { .62, .62, .62 }
                or (isNext or st.active) and C.text or C.muted
            f.title:SetTextColor(c[1], c[2], c[3])
            local value = GP.QuestXP.Get(st.id, st.level)
            f.sub:SetText((st.giver or "?") .. (st.zone and (", " .. st.zone) or "")
                .. ((not finished and value.xp and value.xp > 0) and (" · " .. GP.QuestXP.Text(value.xp)) or ""))
            local badge, bc = "", C.muted
            if st.done then badge, bc = L("done"), C.green
            elseif st.skipped then badge, bc = L("skipped"), C.muted
            elseif st.active then badge, bc = L("in quest log"), C.gold
            elseif isNext then badge, bc = L("next"), C.gold end
            if grey then badge = (badge ~= "" and (badge .. " · ") or "") .. L("grey") end
            if tooLow then badge = (badge ~= "" and (badge .. " · ") or "") .. (L("from level %d"):format(st.minLevel)) end
            if st.id == targetID and not st.done then badge = (badge ~= "" and (badge .. " · ") or "") .. L("reward") end
            f.badge:SetText(badge)
            f.badge:SetTextColor(bc[1], bc[2], bc[3])
            f:Show()
            detailY = detailY + 42
        end
    end
    if #chain > 2 then
        U.chainToggle:SetText(expanded and L("Show fewer steps") or (L("Show all %d steps"):format(#chain)))
        U.chainToggle:SetScript("OnClick", function()
            GP.chainOpen[targetID] = not GP.chainOpen[targetID]
            GP.Render()
        end)
        U.chainToggle:ClearAllPoints()
        U.chainToggle:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
        U.chainToggle:Show()
        detailY = detailY + 30
    end
end

local function resetDetail()
    for _, t in ipairs(U.lines) do t:Hide() end
    U.lines.used = {}
    S.HideMetrics(U.detail)
    U.action:Hide()
    U.action2:Hide()
    U.action3:Hide()
    for _, b in ipairs(U.tools) do b:Hide() end
    U.chainToggle:Hide()
    U.wishButton:Hide()
    U.togoButton:Hide()
    U.orderUp:Hide()
    U.orderDown:Hide()
    U.detailDungeon = nil
    hideBars()
    hideSteps()
    for _, f in ipairs(U.itemLines) do f:Hide() end
    U.itemLines.used = 0
    for _, f in ipairs(U.sourceLines) do f:Hide() end
    U.sourceLines.used = 0
    U.priceBox:Hide()
    U.detailLink = nil
    detailY = 0
end

-- Data ------------------------------------------------------------------------------------------------------------
GP.selected = {}
local function money(copper)
    if type(copper) ~= "number" or copper <= 0 then return "—" end
    if GetCoinTextureString then return GetCoinTextureString(math.floor(copper)) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), math.floor(copper % 100)
    return (g > 0 and (g .. "g ") or "") .. (s > 0 and (s .. "s ") or "") .. c .. "c"
end
local professionNames = {
    blacksmithing = "Blacksmithing", leatherworking = "Leatherworking", tailoring = "Tailoring",
    engineering = "Engineering", alchemy = "Alchemy", enchanting = "Enchanting",
}
-- Armor type of an armor item (cloth, leather, mail, plate), shown next to the slot; nil for the rest.
local ARMOR_TYPES = { "Cloth", "Leather", "Mail", "Plate" }
local function armorType(item)
    if item and item.classID == 4 and ARMOR_TYPES[item.subclassID or 0] and item.equip ~= "INVTYPE_CLOAK" then
        return L(ARMOR_TYPES[item.subclassID])
    end
    return nil
end
-- "Hands · Leather", or just the slot.
local function slotText(item, slot)
    local name = L(P.slotNames[slot] or "")
    local armor = armorType(item)
    return armor and (name .. " · " .. armor) or name
end
local function sourceLine(entry)
    local row = entry.row
    if entry.source == "Bags" then return L("In your bags") end
    if entry.source == "Quests" then
        local kind = row.dungeonQuest and ("|cffd9a35a" .. L("Dungeon quest") .. "|r") or L("Quest")
        if P.IsGrey(row.level, GP.Player().level) then kind = kind .. " |cff9d9d9d(" .. L("grey") .. ")|r" end
        local distance = entry.distance and (" · " .. (L("%d yd")):format(entry.distance)) or ""
        if GP.settings.questSort == "zone" and row.zone then distance = " · " .. row.zone end
        return ("%s · %s%s"):format(kind, (L("Level %d")):format(entry.level), distance)
    end
    if entry.source == "Vendors" then
        local price = entry.item and entry.item.sellPrice and entry.item.sellPrice > 0 and (" · " .. L("approx.") .. " " .. money(entry.item.sellPrice * 4)) or ""
        return L("Vendor: ") .. (row.name or "?") .. price
    end
    if entry.source == "Auction" then
        local age = row.age and (" · " .. (row.age == 0 and L("today") or (L("%d d ago"):format(row.age)))) or ""
        return L("Auction house") .. " · " .. money(row.price) .. age
    end
    if entry.source == "Crafted" then
        return L(professionNames[row.profession] or row.profession) .. (row.learn and (" " .. row.learn) or "")
    end
    local chance = GP.Sources.ChanceText(row)
    chance = chance and (" · " .. chance) or ""
    return ("%s%s"):format(GP.Sources.DungeonName(row), chance)
end

-- Level windows per source: quests (optionally until they turn grey), dungeons (their own range: read by the
-- dungeon's level range, scored up to its top), everything else your level range.
local function windows(player, low, high)
    local s = GP.settings
    local questLow = s.questsGrey and math.min(low, P.GreyLevel(player.level) + 1) or low
    local dungeonLow, dungeonHigh = GP.DungeonRange()
    return { read = { Quests = { questLow, high }, Dungeons = { dungeonLow, dungeonHigh } },
        score = { Quests = { questLow, high }, Dungeons = { 1, dungeonHigh } } }
end
-- Reads the sources; returns entries, loading flag and the states (missing, nocraftpilot, noauction).
local function collect(sources, low, high, options)
    local all, loading, states = {}, false, {}
    for _, source in ipairs(sources) do
        local window = options and options.read and options.read[source]
        local entries, isLoading, state = GP.ReadCandidates(source, window and window[1] or low, window and window[2] or high, options)
        loading = loading or isLoading
        states[state] = true
        for _, entry in ipairs(entries) do all[#all + 1] = entry end
    end
    return all, loading, states
end
local function recommend(sources, low, high, equipped, profile, player, all)
    local win = windows(player, low, high)
    local candidates, loading, states = collect(sources, low, high, { read = win.read, all = all })
    local s = GP.settings
    local list = P.Recommend(candidates, equipped, { level = player.level, below = s.below, above = s.above, profile = profile,
        class = player.class, slotAllowed = GP.SlotAllowed, windows = win.score })
    return list, loading, states
end

local function gearRows(equipped, profile)
    local list = {}
    for _, slot in ipairs(P.slots) do
        local item = equipped[slot[1]]
        list[#list + 1] = { kind = "gear", key = "slot" .. slot[1], slot = slot[1], item = item,
            score = item and item.stats and P.Score(item, profile) }
    end
    return list
end

-- Detail panels -------------------------------------------------------------------------------------------------------
U.wishButton = S.Button(U.detail, 130, 24, "", function()
    if U.detailLink then GP.Wish.Toggle(U.detailLink) end
end)
U.wishButton:SetPoint("TOPRIGHT", U.detail, "TOPRIGHT", -12, -12)
U.wishButton:Hide()
local function showHead(icon, name, sub, link)
    U.detailIcon:SetTexture(icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    U.detailName:SetText(name or "")
    U.detailSub:SetText(sub or "")
    U.detailLink = link
    U.detailQuest, U.detailQuestTitle = nil, nil
    local onList = link and GP.Wish and GP.Wish.Has(link)
    U.wishButton:SetShown(link ~= nil)
    U.wishButton:SetText(onList and L("On wishlist") or L("+ Wishlist"))
    if onList then S.Primary(U.wishButton) else
        U.wishButton:SetBackdropColor(.114, .133, .165, 1)
        local label = U.wishButton:GetFontString()
        if label then label:SetTextColor(.88, .69, .31) end
    end
    local width = (U.detail:GetWidth() or 300) - 72 - (link and 140 or 0)
    U.detailName:SetWidth(width)
    U.detailSub:SetWidth(width)
    detailY = math.max(58, 40 + (U.detailName:GetStringHeight() or 16))
end
local function showItemHead(item, sub)
    showHead(item and item.icon, item and (S.QualityColor(item.quality) .. (item.name or "?") .. "|r") or L("No item equipped"),
        sub, item and item.link)
end
local function percentText(gain, base)
    if not base or base <= 0 then return "" end
    return signed(gain / base * 100) .. " %"
end

local function questBlock(row)
    detailLine("GameFontHighlight", GP.Sources.QuestTitle(row.sourceID, row.name))
    detailLine("GameFontHighlightSmall", (L("Quest level %d"):format(row.level))
        .. (row.minLevel and row.minLevel > 0 and (" · " .. L("from level %d"):format(row.minLevel)) or ""))
    if row.giver then detailLine("GameFontHighlightSmall", L("Quest giver: ") .. row.giver .. (row.zone and (", " .. row.zone) or "")) end
    GP.QuestXP.Request({ row.sourceID })
    local value = GP.QuestXP.Get(row.sourceID, row.level)
    if (value.xp and value.xp > 0) or value.money then
        local parts = {}
        if value.xp and value.xp > 0 then parts[#parts + 1] = GP.QuestXP.Text(value.xp) end
        if value.money then parts[#parts + 1] = money(value.money) end
        detailLine("GameFontHighlightSmall", L("Reward: ") .. table.concat(parts, " · ")
            .. (value.source == "server" and "" or (" |cff9dabb8" .. L("(ForeverDB)") .. "|r")))
    end
    if row.dungeonQuest then
        detailLine("GameFontHighlightSmall", "|cffd9a35a" .. L("Dungeon quest: ") .. row.dungeonQuest .. "|r")
    end
    if row.choiceGroup then
        detailLine("GameFontDisableSmall", L("Choice reward: you get one item of this quest. GearPilot shows the best one for you."), C.muted)
    end
    local chain = GP.Route.Chain(row.sourceID)
    local map = { L("Map"), function() GP.Map.Chain(row.sourceID) end, 90 }
    if #chain > 1 then
        actions({ L("Waypoint to quest giver"), function() GP.Route.ToGiver(row.sourceID) end },
            { (L("Whole chain (%d)")):format(#chain), function() GP.Route.ToChain(row.sourceID) end }, map)
    else
        actions({ L("Waypoint to quest giver"), function() GP.Route.ToGiver(row.sourceID) end }, map)
    end
    if #chain > 1 then chainSteps(chain, row.sourceID) end
end

local function vendorBlock(row, item)
    local list = {}
    for _, vendor in ipairs(row.vendors or {}) do
        local spot = ForeverDB and GP.Sources.Spot(ForeverDB, vendor.ref)
        list[#list + 1] = { ref = vendor.ref, name = vendor.name, distance = GP.Sources.Distance(spot),
            zone = GP.Sources.MapName((GP.Sources.MapPoint(spot))) }
    end
    table.sort(list, function(a, b) return (a.distance or math.huge) < (b.distance or math.huge) end)
    if item.sellPrice and item.sellPrice > 0 then
        detailLine("GameFontHighlightSmall", L("Price about ") .. money(item.sellPrice * 4) .. " |cff9dabb8" .. L("(estimate)") .. "|r")
    end
    for i, vendor in ipairs(list) do
        if i > 6 then break end
        detailLine("GameFontHighlightSmall", vendor.name .. (vendor.zone and (", " .. vendor.zone) or "")
            .. (vendor.distance and (" · " .. (L("%d yd")):format(math.floor(vendor.distance + .5))) or ""), C.text, 4)
    end
    if list[1] then
        actions({ L("Waypoint to nearest vendor"), function() GP.Route.ToNPC(list[1].ref, item.name) end, 190 })
    end
end

local function craftedBlock(row)
    local known = GP.Professions()[row.profession]
    detailLine("GameFontHighlight", row.name or "")
    detailLine("GameFontHighlightSmall", L(professionNames[row.profession] or row.profession)
        .. (row.learn and (" · " .. (L("skill %d")):format(row.learn)) or ""))
    if known then
        local ready = row.learn and known.rank and known.rank >= row.learn
        detailLine("GameFontHighlightSmall", ready and ("|cff85d6a0" .. L("You have this profession and the skill.") .. "|r")
            or ((L("You have this profession, skill %d."):format(known.rank or 0))), C.text)
    else
        detailLine("GameFontDisableSmall", L("Not one of your professions: ask a crafter or look in the auction house."), C.muted)
    end
    detailLine("GameFontDisableSmall", L("Materials, costs and where to learn it: CraftPilot (/cpp)."), C.muted)
end

local function showUpgrade(result, profile)
    local item, entry, row = result.item, result.entry, result.entry.row
    showItemHead(item, ("%s · %s"):format(slotText(item, result.slot), sourceLine(entry)))
    local width = (U.detail:GetWidth() or 300) - 24
    local replaced = result.current and result.current.name or L("Empty slot")
    if result.second and result.second.name then replaced = replaced .. " + " .. result.second.name end
    local third
    if entry.source == "Dungeons" then
        third = { label = L("Drop chance"), value = GP.Sources.ChanceText(row) or L("unknown") }
    elseif entry.source == "Auction" then
        third = { label = L("Auction price"), value = money(row.price), color = C.text }
    else
        third = { label = L("Required level"), value = tostring(item.minLevel or "?") }
    end
    S.Metrics(U.detail, {
        { label = L("Score gain"), note = percentText(result.gain, result.score - result.gain), value = signed(result.gain),
            color = C.green, emphasis = true },
        { label = L("Replaces"), value = replaced, color = C.text },
        third,
    }, 12, detailY, width)
    detailY = detailY + 60
    local note = GP.Skills.Note(item)
    if note then detailLine("GameFontHighlightSmall", "|cffeba85a" .. note .. "|r") end
    if P.HeavyArmor(item, GP.Player().class) then
        detailLine("GameFontHighlightSmall", "|cffeba85a" .. L("Heavier armor from level 40: learn it at your class trainer first.") .. "|r")
    end
    section(L("Where to get it"))
    if entry.source == "Bags" then
        detailLine("GameFontHighlightSmall", L("Already in your bags."))
        actions({ L("Equip"), function()
            if InCombatLockdown() then return end
            local equip = C_Item.EquipItemByName or EquipItemByName
            if equip then equip(item.link) end
        end, 120 })
    elseif entry.source == "Quests" then
        questBlock(row)
    elseif entry.source == "Vendors" then
        vendorBlock(row, item)
    elseif entry.source == "Auction" then
        detailLine("GameFontHighlightSmall", L("Lowest price from your last Auctionator scan: ") .. money(row.price))
        if row.age then
            detailLine("GameFontHighlightSmall", row.age == 0 and L("Seen in today's scan.") or (L("Last seen %d days ago: it may be sold already."):format(row.age)),
                row.age == 0 and C.green or { .92, .66, .35 })
        end
        if GP.AuctionHouseOpen() then
            actions({ L("Search in the auction house"), function() GP.SearchAuction({ item.name }) end, 220 })
        else
            detailLine("GameFontDisableSmall", L("Open the auction house: then a button searches this item for you."), C.muted)
        end
    elseif entry.source == "Crafted" then
        craftedBlock(row)
    else
        detailLine("GameFontHighlight", GP.Sources.DungeonName(row) .. (row.raid and (" (" .. L("raid") .. ")") or ""))
        if row.boss then detailLine("GameFontHighlightSmall", L("Drops from: ") .. row.boss) end
        detailLine("GameFontHighlightSmall", row.chance and (L("Drop chance about %d %%"):format(math.floor(row.chance * 100 + .5)))
            or (row.estimate and L("Drop chance not recorded yet; estimated from the boss's loot table (AllTheThings): about %d %%."):format(math.floor(row.estimate * 100 + .5)))
            or L("Drop chance not known yet (new in Forever or too few kills recorded)."))
    end
    section(L("Values compared"))
    statLines(P.Diff(item, result.current), profile)
end

local function showGear(data, profile)
    local item = data.item
    showItemHead(item, L(P.slotNames[data.slot] or ""))
    if not item then return end
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Score"), value = data.score and number(data.score) or "…", color = C.gold, emphasis = true },
        { label = L("Required level"), value = tostring(item.minLevel or "?"), color = C.text },
        { label = L("Profile"), value = L(profile.name), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    local note = GP.Skills.Note(item)
    if note then detailLine("GameFontHighlightSmall", "|cffeba85a" .. note .. "|r") end
    section(L("Values"))
    local any = false
    for _, key in ipairs(St.order) do
        local v = item.stats and item.stats[key]
        if v and v ~= 0 then
            any = true
            local weight = P.Weight(profile, key)
            detailLine("GameFontHighlightSmall", ("%s  %s%s"):format(number(v), L(St.names[key]),
                weight and ("  |cff9dabb8× " .. number(weight) .. "|r") or "  |cff9dabb8" .. L("(not weighted)") .. "|r"), C.text, 4)
        end
    end
    if not any then detailLine("GameFontDisableSmall", L("No readable values."), C.muted) end
end

local function combined(set)
    local stats = {}
    for _, item in ipairs({ set.main or false, set.off or false }) do
        if item and item.stats then
            for key, value in pairs(item.stats) do stats[key] = (stats[key] or 0) + value end
        end
    end
    return { stats = stats }
end
local function showWeapons(data, profile)
    local set, sets = data.set, data.sets
    local titles = { current = L("Worn now"), twoHand = L("Best two-hand"), pair = L("Best main + off hand") }
    showHead(set.main and set.main.icon or "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand", titles[data.setKind],
        L("Two-hand weapon against main hand and off hand, with the values of your profile"))
    local width = (U.detail:GetWidth() or 300) - 24
    local other = data.setKind == "twoHand" and sets.pair or data.setKind == "pair" and sets.twoHand or nil
    S.Metrics(U.detail, {
        { label = L("Score"), value = number(set.score), color = C.gold, emphasis = true },
        { label = L("Against worn now"), value = signed(set.score - sets.current.score),
            color = set.score >= sets.current.score and C.green or C.red },
        { label = data.setKind == "twoHand" and L("Against best pair") or data.setKind == "pair" and L("Against best two-hand") or L("Best setup"),
            value = other and signed(set.score - other.score) or (function()
                local best = sets.current
                for _, candidate in ipairs({ sets.twoHand, sets.pair }) do if candidate and candidate.score > best.score then best = candidate end end
                return best == sets.current and L("worn") or best == sets.twoHand and L("two-hand") or L("pair")
            end)(), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    section(L("Weapons"))
    for _, part in ipairs({ { set.main, set.mainEntry, L("Main hand") }, { set.off, set.offEntry, L("Off hand") } }) do
        local item, entry, label = part[1], part[2], part[3]
        if item then
            local where = entry and entry.source and entry.source ~= "Worn" and entry.row and sourceLine(entry)
                or entry and entry.source == "Bags" and L("In your bags") or L("worn")
            itemLine(item, label .. " · " .. where, number(P.SlotScore(item, profile, part[3] == L("Off hand") and 17 or 16) or 0)
                .. " " .. L("points"), C.gold)
        elseif label == L("Off hand") and data.setKind ~= "twoHand" then
            detailLine("GameFontDisableSmall", label .. ": " .. L("Empty slot"), C.muted, 4)
        end
    end
    detailLine("GameFontDisableSmall", L("An off-hand weapon deals half damage: its weapon DPS counts half. Dual wield from level 20 (rogues 10); shields and held items by class."), C.muted)
    if data.setKind ~= "current" then
        section(L("Values compared"))
        statLines(P.Diff(combined(set), combined(sets.current)), profile)
    end
end

local function chanceLabel(src)
    return L("Drop chance") .. " " .. (GP.Sources.ChanceText(src) or L("unknown"))
end
local function showSources(id, item)
    section(L("Where to get it"))
    local sources = GP.Wish.Sources(id)
    local cp = GP.CraftPilot()
    local db = ForeverDB
    for _, src in ipairs(sources) do
        if src.kind == "quest" then
            local chain = GP.Route.Chain(src.questID)
            local title = GP.Sources.QuestTitle(src.questID, src.name)
            sourceLine2("quest", title, L("Quest") .. " · " .. (L("Level %d")):format(src.level or 0)
                .. (src.giver and (" · " .. src.giver) or "") .. (src.zone and (", " .. src.zone) or ""),
                #chain > 1 and (L("Chain (%d)")):format(#chain) or L("Waypoint"),
                function() if #chain > 1 then GP.Route.ToChain(src.questID) else GP.Route.ToGiver(src.questID) end end,
                function() if #chain > 1 then GP.Map.Chain(src.questID) else GP.Map.Quests(title, { src.questID }) end end,
                nil, src.questID, src.name)
        elseif src.kind == "dungeon" then
            local entrance = db and GP.Sources.Entrance(db, src.name)
            local dungeonName = GP.Sources.DungeonName(src)
            sourceLine2("dungeon", dungeonName .. (src.raid and (" (" .. L("raid") .. ")") or ""),
                (src.boss or "?") .. " · " .. chanceLabel(src), entrance and L("Entrance") or nil,
                entrance and function() GP.Route.ToSpot(entrance, dungeonName, src.boss) end or nil,
                entrance and function() GP.Map.Place(dungeonName, dungeonName, L("Entrance"), nil, entrance) end or nil)
        elseif src.kind == "vendor" then
            sourceLine2("vendor", src.name, L("Vendor"), L("Waypoint"), function() GP.Route.ToNPC(src.npcRef, item and item.name or src.name) end,
                function() GP.Map.Place(item and item.name or src.name, src.name, L("Vendor"), src.npcRef) end)
        elseif src.kind == "craft" then
            local known = GP.Professions()[src.profession]
            sourceLine2("craft", src.name, L(professionNames[src.profession] or src.profession)
                .. (src.learn and (" · " .. (L("skill %d")):format(src.learn)) or "") .. (known and (" · " .. L("your profession")) or ""),
                cp and L("Recipe") or nil, cp and function() GP.OpenRecipe(src.profession, src.recipeID, id) end or nil)
            if cp and cp.OpenCostCalculation then
                sourceLine2("craft", L("Materials and cost"), L("CraftPilot works out the materials with the prices of your last auction house scan."),
                    L("Show"), function() pcall(cp.OpenCostCalculation, cp, "recipe", src.profession, src.recipeID, 1) end, nil, 24)
            end
        elseif src.kind == "mob" then
            sourceLine2("mob", src.name, L("Mob") .. (src.level and (" · " .. (L("Level %d")):format(src.level)) or "") .. " · " .. chanceLabel(src),
                L("Waypoint"), function() GP.Route.ToNPC(src.npcRef, item and item.name or src.name) end,
                function() GP.Map.Place(item and item.name or src.name, src.name, L("Mob"), src.npcRef) end)
        elseif src.kind == "world" then
            sourceLine2("world", L("World drop"), (L("from level %d")):format(src.level or 1))
        end
    end
    local price = GP.AuctionPrice(id)
    if price then
        local age = GP.AuctionAge(id)
        sourceLine2("auction", L("Auction house") .. " · " .. money(price), age and (age == 0 and L("today") or (L("%d d ago"):format(age))) or L("last scan"),
            GP.AuctionHouseOpen() and L("Search") or nil, GP.AuctionHouseOpen() and function() GP.SearchAuction({ item and item.name or "" }) end or nil)
    end
    if #sources == 0 and not price then
        detailLine("GameFontDisableSmall", GP.Sources.Database() and L("No known source yet.") or L("ForeverDB missing"), C.muted)
    end
end

local function showWish(data, profile)
    local item, id = data.item, data.id
    local wish = GP.Wish.List()[id] or {}
    showItemHead(item, L(P.slotNames[data.slot] or "") .. (wish.goal and (" · |cffe0b050" .. L("goal") .. "|r") or ""))
    local width = (U.detail:GetWidth() or 300) - 24
    local result = data.result
    local first
    if data.owned then first = { label = L("Status"), value = L("received"), color = C.green, emphasis = true }
    elseif result and result.worn then first = { label = L("Status"), value = L("worn"), color = C.green, emphasis = true }
    elseif result and result.usable == false then first = { label = L("Score gain"), value = L("not usable"), color = C.red, emphasis = true }
    elseif result then first = { label = L("Score gain"), note = percentText(result.gain or 0, result.base), value = signed(result.gain or 0),
        color = (result.gain or 0) >= 0 and C.green or C.red, emphasis = true }
    else first = { label = L("Score gain"), value = "…", color = C.muted, emphasis = true } end
    S.Metrics(U.detail, {
        first,
        { label = data.bis and L("Score") or L("Required level"), value = data.bis and number(data.score or 0) or tostring(item.minLevel or "?"), color = C.text },
        { label = L("Auction price"), value = money(GP.AuctionPrice(id)), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    if data.bis then
        detailLine("GameFontDisableSmall", L("Calculated by GearPilot with your profile's weights; not an official BIS list. Set bonuses and random effects are not scored."), { .92, .66, .35 })
    end
    local note = GP.Skills.Note(item)
    if note then detailLine("GameFontHighlightSmall", "|cffeba85a" .. note .. "|r") end
    if GP.Wish.Has(id) then
        actions({ wish.goal and L("Goal: yes") or L("Goal for this slot"), function() GP.Wish.SetGoal(id, not wish.goal); GP.Render() end, 170 },
            { L("Remove"), function() GP.Wish.Remove(id) end, 110 })
        detailLine("GameFontHighlightSmall", L("Wish price in the auction house (gold, Enter):"), C.text)
        U.priceBox:ClearAllPoints()
        U.priceBox:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 260, -(detailY - 22))
        U.priceBox:SetText(wish.price and tostring(math.floor(wish.price / 10000)) or "")
        U.priceBox:SetScript("OnEnterPressed", function(self)
            local gold = tonumber(self:GetText() or "")
            GP.Wish.SetPrice(id, gold and gold * 10000 or nil)
            self:ClearFocus()
        end)
        U.priceBox:Show()
    else
        actions({ L("+ Wishlist"), function() GP.Wish.Add(id) end, 150 }, { L("As goal"), function() GP.Wish.Add(id, true) end, 120 })
    end
    showSources(id, item)
    if result and result.current then
        section(L("Values compared"))
        statLines(P.Diff(item, result.current), profile)
    end
end

local function showZone(zone)
    showHead("Interface\\Icons\\INV_Misc_Map_01", zone.zone, (L("%d quest upgrades"):format(#zone.results)))
    local width = (U.detail:GetWidth() or 300) - 24
    local nearest
    for _, result in ipairs(zone.results) do
        local d = result.entry.distance
        if d and (not nearest or d < nearest) then nearest = d end
    end
    S.Metrics(U.detail, {
        { label = L("Score gain together"), value = signed(zone.gain), color = C.green, emphasis = true },
        { label = L("Quests"), value = tostring(#zone.results), color = C.text },
        { label = L("Nearest quest giver"), value = nearest and (L("%d yd")):format(nearest) or "—", color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    local ids = {}
    for _, result in ipairs(zone.results) do ids[#ids + 1] = result.entry.row.sourceID end
    actions({ (L("Waypoints to all quest givers (%d)")):format(#ids), function() GP.Route.ToMany(ids) end, 260 },
        { L("Map"), function() GP.Map.Quests(zone.zone, ids) end, 90 })
    section(L("Quests in this zone"))
    for _, result in ipairs(zone.results) do
        local row = result.entry.row
        itemLine(result.item, GP.Sources.QuestTitle(row.sourceID, row.name) .. " · " .. (L("Level %d")):format(row.level)
            .. (row.dungeonQuest and (" · " .. L("Dungeon quest")) or ""), signed(result.gain))
    end
end

-- Dungeon details in GearPilot's own layout: what the dungeon brings you (metrics), what to do before (quests
-- with their chains), and the loot per boss (your upgrades bright, wishlist items marked, the rest dimmed).
U.togoButton = S.Button(U.detail, 130, 24, "", function()
    if U.detailDungeon then GP.Togo.Toggle(U.detailDungeon) end
end)
U.togoButton:SetPoint("TOPRIGHT", U.detail, "TOPRIGHT", -12, -12)
U.togoButton:Hide()
U.orderUp = S.Button(U.detail, 120, 24, L("Move up"), function() if U.detailDungeon then GP.Togo.Move(U.detailDungeon, -1) end end)
U.orderUp:Hide()
U.orderDown = S.Button(U.detail, 120, 24, L("Move down"), function() if U.detailDungeon then GP.Togo.Move(U.detailDungeon, 1) end end)
U.orderDown:Hide()
local questRowsCache
-- Quest rows by quest ID (rewards for your class), for the best reward of a dungeon quest.
local function questRows()
    local player = GP.Player()
    local rows = GP.Sources.Rows(player.class, player.faction, GP.settings.minChance, player.raceBit) or {}
    if not questRowsCache or questRowsCache.rows ~= rows then
        local byQuest = {}
        for _, r in ipairs(rows) do
            if r.source == "Quests" then
                byQuest[r.sourceID] = byQuest[r.sourceID] or {}
                table.insert(byQuest[r.sourceID], r)
            end
        end
        questRowsCache = { rows = rows, byQuest = byQuest }
    end
    return questRowsCache.byQuest
end
local function bestReward(questID, equipped, profile, player)
    local best
    for _, r in ipairs(questRows()[questID] or {}) do
        local item = GP.ItemData(r.itemID)
        if item.name then
            local result = P.Compare(item, equipped, profile, player.class, player.level)
            if result and result.gain and result.gain > 0 and (not best or result.gain > best.gain) then
                best = { item = item, gain = result.gain }
            end
        end
    end
    return best
end
local function showDungeon(dungeon, profile, equipped)
    local row, d = dungeon.row, dungeon.catalog
    local player = GP.Player()
    local name = GP.Sources.DungeonName(row)
    local sub = (L("Level %d–%d"):format(dungeon.low, dungeon.high)) .. " · "
        .. (dungeon.inRange and ("|cff85d6a0" .. L("in your range") .. "|r") or L("outside your range"))
        .. (row.raid and (" · " .. L("raid")) or "")
    showHead("Interface\\Icons\\INV_Misc_Head_Dragon_01", name, sub)
    -- Head button: on your to go list or not.
    U.detailDungeon = d and d.name
    local onList = d and GP.Togo.Has(d.name)
    U.togoButton:SetShown(d ~= nil)
    U.togoButton:SetText(onList and L("On to go list") or L("+ To go"))
    if onList then S.Primary(U.togoButton) else
        U.togoButton:SetBackdropColor(.114, .133, .165, 1)
        local label = U.togoButton:GetFontString()
        if label then label:SetTextColor(.88, .69, .31) end
    end
    U.detailName:SetWidth((U.detail:GetWidth() or 300) - 72 - 140)
    local quests, open = GP.Togo.Quests(d)
    local width = (U.detail:GetWidth() or 300) - 24
    -- Experience: open dungeon quests and the open steps before them (each quest once).
    local chains, openSteps, seenSteps, ask = {}, {}, {}, {}
    for _, info in ipairs(quests) do
        ask[#ask + 1] = info.id
        if not info.done then
            local chain = GP.Route.Chain(info.id)
            P.ChainStatus(chain)
            chains[info.id] = chain
            for _, st in ipairs(chain) do
                ask[#ask + 1] = st.id
                if not st.done and not st.skipped and not seenSteps[st.id] then
                    seenSteps[st.id] = true
                    openSteps[#openSteps + 1] = { id = st.id, level = st.level }
                end
            end
        end
    end
    GP.QuestXP.Request(ask)
    local totalXP, _, withoutXP = GP.QuestXP.Sum(openSteps)
    S.Metrics(U.detail, {
        { label = L("Expected per run"), value = "Ø " .. signed(dungeon.expected), color = C.green, emphasis = true },
        { label = L("Upgrades"), value = tostring(#dungeon.results), color = C.text },
        { label = L("Open quests"), note = totalXP > 0 and GP.QuestXP.Text(totalXP) or nil,
            value = (#quests > 0) and (open .. " / " .. #quests) or "0", color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    if totalXP > 0 then
        detailLine("GameFontHighlightSmall", (L("The open quests give %s, pre-quests included."):format(GP.QuestXP.Text(totalXP)))
            .. (withoutXP > 0 and (" " .. (L("(+%d without a value)"):format(withoutXP))) or ""), C.text)
    end
    if (dungeon.estimated or 0) > 0 then
        detailLine("GameFontDisableSmall", (L("%d drop chances are estimated from the boss's loot table (AllTheThings)."):format(dungeon.estimated)), C.muted)
    end
    if dungeon.unknown > 0 then
        detailLine("GameFontDisableSmall", (L("%d drop chances are unknown and count as %d %%."):format(dungeon.unknown, P.UNKNOWN_CHANCE * 100)), C.muted)
    end
    if dungeon.togo then
        detailLine("GameFontHighlightSmall", (L("On your to go list: %d runs so far."):format(dungeon.togo.runs or 0)), C.gold)
        local position = 0
        for index, entry in ipairs(GP.Togo.List()) do if entry.name == d.name then position = index end end
        local count = #GP.Togo.List()
        if count > 1 then
            U.orderUp:ClearAllPoints()
            U.orderUp:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
            U.orderUp:SetShown(position > 1)
            U.orderDown:ClearAllPoints()
            U.orderDown:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12 + (position > 1 and 128 or 0), -detailY)
            U.orderDown:SetShown(position < count)
            detailY = detailY + 30
        end
    end
    if row.raid and d and not GP.ForeverRaid(d.name) then
        detailLine("GameFontDisableSmall", L("Classic raid: not announced for WoW Forever. Its loot does not count in the BIS lists."), C.muted)
    end
    local opens = row.raid and d and GP.RaidOpens(d.name)
    if opens then
        detailLine("GameFontHighlightSmall", (L("Opens %s (provisional date). You can do the access quests already."):format(opens)), C.gold)
    end
    -- 1.7.0: your class quests that play in this dungeon (the Sunken Temple ones, say).
    for _, chain in ipairs(d and GP.ClassQuests.ForDungeon(d.name) or {}) do
        local steps, cdone, nextStep = GP.ClassQuests.Status(chain)
        if cdone < #steps then
            section(L("Class quest") .. ": " .. GP.QuestInfo.Title(chain.id, chain.title) .. "  |cff9dabb8"
                .. (L("%d of %d done"):format(cdone, #steps)) .. "|r")
            if nextStep then
                sourceLine2(nextStep.active and "questactive" or "quest", nextStep.title,
                    (nextStep.giver or "?") .. (nextStep.zone and (", " .. nextStep.zone) or "")
                    .. ((type(nextStep.minLevel) == "number" and nextStep.minLevel > player.level) and (" · " .. (L("from level %d"):format(nextStep.minLevel))) or ""),
                    L("Waypoint"), function() GP.Route.ToGiver(nextStep.id) end,
                    function() GP.Map.Chain(chain.id) end, nil, nextStep.id, nextStep.title)
            end
        end
    end
    -- 1.6.1: access quests (Drakefire Amulet, dungeon keys): the chain with its status and the next step.
    local access = d and GP.Access.For(d.name) or {}
    for _, a in ipairs(access) do
        section(L("Access") .. ": " .. L(a.entry.label) .. "  |cff9dabb8" .. (a.complete and L("done")
            or (L("%d of %d done"):format(a.done, a.total))) .. "|r")
        if a.entry.required then
            detailLine("GameFontHighlightSmall", L("Every raid member needs it to enter."), C.text)
        end
        if a.entry.confirmed == false then
            detailLine("GameFontDisableSmall", L("Classic key: not confirmed for WoW Forever yet."), C.muted)
        end
        if not a.complete then
            local buttons = {}
            if a.next then buttons[#buttons + 1] = { L("Next step"), function() GP.Route.ToGiver(a.next.id) end, 110 } end
            buttons[#buttons + 1] = { L("Whole chain"), function() GP.Route.ToChain(a.id) end, 110 }
            buttons[#buttons + 1] = { L("Into my route"), function() GP.Access.ToMyRoute(a) end, 130 }
            tools(buttons)
            chainSteps(a.chain, "access:" .. a.id)
        end
    end
    -- Way there and preparation.
    local db = ForeverDB
    local entrance = db and GP.Sources.Entrance(db, d and d.name or row.name)
    local nextSteps = GP.Togo.NextSteps(quests)
    for _, id in ipairs(d and GP.Access.NextSteps(d.name) or {}) do nextSteps[#nextSteps + 1] = id end
    local first = entrance and { L("Waypoint to the entrance"), function() GP.Route.ToSpot(entrance, name) end, 200 } or nil
    local second = #nextSteps > 0 and { (L("Collect quests (%d)")):format(#nextSteps), function() GP.Route.ToMany(nextSteps) end, 170 } or nil
    local map = (entrance or #nextSteps > 0) and { L("Map"), function()
        GP.Map.Quests(name, nextSteps, entrance and { { spot = entrance, title = name } } or nil)
    end, 90 } or nil
    if first then actions(first, second, map) elseif second then actions(second, map) end
    -- Quests
    if #quests > 0 then
        section(L("Quests") .. "  |cff9dabb8" .. (L("%d of %d done"):format(#quests - open, #quests)) .. "|r")
        for _, info in ipairs(quests) do
            local chain = chains[info.id] or {}
            local done = 0
            if #chain > 1 then done = P.ChainStatus(chain) end
            local parts = { (L("Level %d")):format(info.level or 0) }
            if info.giver then parts[#parts + 1] = info.giver end
            if info.done then parts[#parts + 1] = "|cff85d6a0" .. L("done") .. "|r"
            elseif info.active then parts[#parts + 1] = "|cffe0b050" .. L("in quest log") .. "|r"
            elseif #chain > 1 then parts[#parts + 1] = (L("chain %d of %d"):format(done, #chain)) end
            if not info.done then
                local value = GP.QuestXP.Get(info.id, info.level)
                if value.xp and value.xp > 0 then parts[#parts + 1] = GP.QuestXP.Text(value.xp) end
                local reward = bestReward(info.id, equipped, profile, player)
                if reward then parts[#parts + 1] = "|cff85d6a0" .. signed(reward.gain) .. "|r " .. (reward.item.name or "") end
            end
            local kind = info.done and "questdone" or info.active and "questactive" or "quest"
            local title = GP.Sources.QuestTitle(info.id, info.title) or ("#" .. info.id)
            if info.done then title = "|cff9dabb8" .. title .. "|r" end
            -- A chain opens below its quest: every step with status, experience and a waypoint.
            local openKey = "dungeon:" .. info.id
            local expanded = #chain > 1 and GP.chainOpen[openKey]
            local button, callback
            if not info.done then
                if #chain > 1 then
                    button = expanded and L("Close chain") or (L("Chain (%d)")):format(#chain)
                    callback = function()
                        GP.chainOpen[openKey] = not GP.chainOpen[openKey]
                        GP.Render()
                    end
                else
                    button, callback = L("Waypoint"), function() GP.Route.ToGiver(info.id) end
                end
            end
            local mapCallback = not info.done and function()
                if #chain > 1 then GP.Map.Chain(info.id) else GP.Map.Quests(title, { info.id }) end
            end or nil
            sourceLine2(kind, title, table.concat(parts, " · "), button, callback, mapCallback, nil, info.id, info.title)
            if expanded then
                local _, nextIndex = P.ChainStatus(chain)
                for i, st in ipairs(chain) do
                    local finished = st.done or st.skipped
                    local status = st.done and ("|cff85d6a0" .. L("done") .. "|r") or st.skipped and L("skipped")
                        or st.active and ("|cffe0b050" .. L("in quest log") .. "|r") or i == nextIndex and ("|cffe0b050" .. L("next") .. "|r") or nil
                    local stepParts = { (st.giver or "?") .. (st.zone and (", " .. st.zone) or "") }
                    if status then stepParts[#stepParts + 1] = status end
                    local value = GP.QuestXP.Get(st.id, st.level)
                    if not finished and value.xp and value.xp > 0 then stepParts[#stepParts + 1] = GP.QuestXP.Text(value.xp) end
                    local stepTitle = ("%d. %s"):format(i, st.title or ("#" .. st.id))
                    if finished then stepTitle = "|cff9dabb8" .. stepTitle .. "|r" end
                    local stepKind = finished and "questdone" or st.active and "questactive" or "quest"
                    local stepButton, stepCallback
                    if not finished then
                        stepButton, stepCallback = L("Waypoint"), function() GP.Route.ToGiver(st.id) end
                    end
                    sourceLine2(stepKind, stepTitle, table.concat(stepParts, " · "), stepButton, stepCallback, nil, 24, st.id, st.title)
                end
                sourceLine2("quest", L("All open steps"), L("Waypoints to every open step of this chain, in order."),
                    L("Waypoints"), function() GP.Route.ToChain(info.id) end, nil, 24)
            end
        end
    end
    -- Bosses and loot.
    local upgrades = {}
    for _, result in ipairs(dungeon.results) do
        if result.item and result.item.id then upgrades[result.item.id] = result end
    end
    local wishes = GP.Wish.List()
    if d and #d.bosses > 0 then
        for _, boss in ipairs(d.bosses) do
            if #boss.items > 0 then
                section(boss.name or L("Unknown"))
                for _, id in ipairs(boss.items) do
                    local item = GP.ItemData(id)
                    local result = upgrades[id]
                    local wish = wishes[id]
                    local parts = {}
                    if item.equip then parts[#parts + 1] = slotText(item, P.targetSlots[item.equip] and P.targetSlots[item.equip][1]) end
                    if wish then parts[#parts + 1] = "|cffe0b050" .. (wish.got and L("received") or L("on wishlist")) .. "|r" end
                    if result then parts[#parts + 1] = L("Drop chance") .. " " .. (GP.Sources.ChanceText(result.entry.row) or L("unknown")) end
                    local f = itemLine(item.name and item or { name = L("Loading item data …") }, table.concat(parts, " · "),
                        result and signed(result.gain) or "")
                    f:SetAlpha((result or wish) and 1 or .5)
                end
            end
        end
    elseif #dungeon.results > 0 then
        -- No boss list (raids without AllTheThings data): the upgrades by boss as before.
        local bosses, order = {}, {}
        for _, result in ipairs(dungeon.results) do
            local boss = result.entry.row.boss or L("Unknown")
            if not bosses[boss] then bosses[boss] = {}; order[#order + 1] = boss end
            table.insert(bosses[boss], result)
        end
        for _, boss in ipairs(order) do
            section(boss)
            for _, result in ipairs(bosses[boss]) do
                itemLine(result.item, slotText(result.item, result.slot) .. " · " .. L("Drop chance") .. " "
                    .. (GP.Sources.ChanceText(result.entry.row) or L("unknown")), signed(result.gain))
            end
        end
    end
end

-- Details of a route task: the quest, its experience and best reward, where to go, and its chain.
local function showRouteTask(data, profile, equipped)
    local QR = GP.QuestRoute
    if data.travel then
        showHead("Interface\\Icons\\Ability_Mount_Wyvern_01", L("Travel to ") .. (data.zone.name or "?"),
            (L("about %d m away"):format(math.floor(data.zone.distance))))
        detailLine("GameFontHighlightSmall", L("The quests here are worth more than those nearby, even with the way there."))
        if data.flight then detailLine("GameFontHighlightSmall", L("Nearest flight point of your faction: ") .. data.flight) end
        local center = data.zone.center
        if center then
            local spot = { world = true, map = center[1], x = center[2], y = center[3] }
            actions({ L("Waypoint"), function() GP.Route.ToSpot(spot, data.zone.name) end, 140 },
                { L("Map"), function() GP.Map.Place(data.zone.name, data.zone.name, L("Quest route"), nil, spot) end, 90 })
        end
        return
    end
    local t, q = data.task, data.task.quest
    local title = QR.Title(q)
    showHead(t.kind == "accept" and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\GossipFrame\\ActiveQuestIcon",
        title, QR.TaskText(t) .. (q.zoneName and (" · " .. q.zoneName) or ""))
    U.detailQuest, U.detailQuestTitle = q.id, q.title
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Experience"), value = q.xp > 0 and GP.QuestXP.Text(q.xp) or "-", color = C.gold, emphasis = true },
        { label = L("Best reward"), value = (q.gain or 0) > 0 and signed(q.gain) or "-", color = C.green },
        { label = L("Quest level"), value = tostring(q.level or "?"), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    local uiMap, x, y = QR.MapPoint(t)
    local objectiveName = t.kind == "objective" and ((t.item and GP.ItemData(t.item).name) or t.label)
    local place = (t.buy and QR.VendorName(t)) or objectiveName or (t.kind == "accept" and ForeverDB and GP.Sources.GiverName(ForeverDB, q.giverRef))
        or (ForeverDB and GP.Sources.GiverName(ForeverDB, q.enderRef))
    local zoneName = uiMap and GP.Sources.MapName(uiMap)
    if place then detailLine("GameFontHighlightSmall", L("Where: ") .. place .. (zoneName and (", " .. zoneName) or "")) end
    if t.buy then
        detailLine("GameFontDisableSmall", L("This item is sold by a vendor; the route moves on once you have enough of it."), C.muted)
    elseif t.kind == "objective" then
        detailLine("GameFontDisableSmall", L("The route moves on when the quest is complete or when you reach this place."), C.muted)
    end
    actions({ L("Waypoint"), function()
        if uiMap and x then GP.Route.ToSpot({ world = false, map = uiMap, x = x, y = y }, title, QR.TaskText(t)) end
    end, 140 }, { L("Map"), function()
        if uiMap and x then GP.Map.Show(title, { { uiMap = uiMap, x = x, y = y, kind = t.kind == "accept" and "quest" or "active",
            title = title, sub = QR.TaskText(t), questID = t.kind == "accept" and q.id or nil, infoQuest = q.id } }) end
    end, 90 })
    -- 1.5.0: your own order, skip, your own route.
    local mine = GP.settings.routeMode == "mine"
    tools({
        { L("Earlier"), function() QR.Move(q.id, -1) end, 90 },
        { L("Later"), function() QR.Move(q.id, 1) end, 90 },
        { L("Skip"), function() QR.Skip(q.id, true) end, 100 },
        mine and { L("Remove from my route"), function() QR.SetMine(q.id, false) end, 170 } or nil,
    })
    -- The gear on the way: this quest's reward or the one at the end of its chain.
    if q.reward and (q.gain or 0) > 0 then
        section(L("Gear on the way"))
        local via = q.rewardQuest and (L("from the follow-up quest ") .. GP.Sources.QuestTitle(q.rewardQuest, ForeverDB and ForeverDB.quest[q.rewardQuest]
            and ForeverDB.quest[q.rewardQuest][1] or ("#" .. q.rewardQuest))) or L("reward of this quest")
        itemLine(q.reward, via, signed(q.gain))
    end
    local chain = GP.Route.Chain(q.id)
    if #chain > 1 then chainSteps(chain, q.id) end
end

-- 1.5.0 details: a quest to choose, a quest in your log, a remembered and a skipped quest.
local function questHead(id, title, sub)
    local inLog = GP.QuestInfo.LogIndex(id) ~= nil
    title = GP.QuestInfo.Title(id, title)
    showHead(inLog and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon", title, sub)
    U.detailQuest, U.detailQuestTitle = id, title
    return title
end
local function questMetrics(id, level, xp, gain)
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Experience"), value = (xp or 0) > 0 and GP.QuestXP.Text(xp) or "-", color = C.gold, emphasis = true },
        { label = L("Best reward"), value = (gain or 0) > 0 and signed(gain) or "-", color = C.green },
        { label = L("Quest level"), value = tostring(level or "?"), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
end
local function questObjectives(id)
    local targets = GP.QuestInfo.Targets(id)
    if #targets > 0 then detailLine("GameFontHighlightSmall", L("Objective") .. ": " .. table.concat(targets, ", ")) end
end
local function showPick(data)
    local QR, q = GP.QuestRoute, data.q
    local giver = ForeverDB and GP.Sources.GiverName(ForeverDB, q.giverRef)
    local title = questHead(q.id, q.title, (giver or "?") .. (q.zoneName and (", " .. q.zoneName) or ""))
    questMetrics(q.id, q.level, q.xp, q.gain)
    questObjectives(q.id)
    if q.escort then detailLine("GameFontDisableSmall", L("Escort quest."), C.muted) end
    if q.skipped then detailLine("GameFontDisableSmall", L("You skipped this quest; adding it to your route takes it back."), C.muted) end
    local mine = QR.InMine(q.id)
    actions({ mine and L("Remove from my route") or L("Add to my route"), function()
            if not mine and q.skipped then QR.Skip(q.id, false) end
            QR.SetMine(q.id, not mine)
        end, 180 },
        { L("Waypoint"), function() GP.Route.ToGiver(q.id) end, 110 },
        { L("Map"), function() GP.Map.Quests(title, { q.id }) end, 80 })
    if GP.settings.routeMode ~= "mine" then
        detailLine("GameFontDisableSmall", L("Your picks become the route when Route from is set to My quests."), C.muted)
    end
    local chain = GP.Route.Chain(q.id)
    if #chain > 1 then chainSteps(chain, q.id) end
end
local function showLogQuest(data)
    local e = data.entry
    questHead(e.id, e.title, e.reason)
    questMetrics(e.id, e.level, e.xp, e.gain)
    questObjectives(e.id)
    local full, count, max = GP.QuestLog.Full()
    detailLine("GameFontDisableSmall", (L("Quest log %d/%d"):format(count, max)) .. (full and (" · |cffeb786b" .. L("full") .. "|r") or ""), C.muted)
    if not e.complete then
        actions({ L("Remember and abandon"), function() GP.QuestLog.Abandon(e.id, e.title, e.level, true) end, 190 },
            { L("Abandon"), function() GP.QuestLog.Abandon(e.id, e.title, e.level, false) end, 110 })
        detailLine("GameFontDisableSmall", L("Remembered quests stay under Remembered with a waypoint to their quest giver, to take again later."), C.muted)
    end
    local chain = GP.Route.Chain(e.id)
    if #chain > 1 then chainSteps(chain, e.id) end
end
local function showLater(data)
    local e = data.entry
    local title = questHead(e.id, e.title, e.inLog and L("in quest log") or L("remembered"))
    local xp = GP.QuestXP.Get(e.id, e.level).xp
    questMetrics(e.id, e.level, xp, 0)
    questObjectives(e.id)
    actions({ L("Waypoint"), function() GP.Route.ToGiver(e.id) end, 140 },
        { L("Map"), function() GP.Map.Quests(title, { e.id }) end, 90 },
        { L("Remove"), function() GP.QuestLog.Forget(e.id) end, 100 })
    local chain = GP.Route.Chain(e.id)
    if #chain > 1 then chainSteps(chain, e.id) end
end
local function showSkipped(data)
    local db = ForeverDB
    local row = db and db.quest and db.quest[data.id]
    questHead(data.id, row and row[1], L("skipped"))
    questMetrics(data.id, row and row[2], GP.QuestXP.Get(data.id, row and row[2]).xp, 0)
    questObjectives(data.id)
    actions({ L("Back into the route"), function() GP.QuestRoute.Skip(data.id, false) end, 180 },
        { L("Waypoint"), function() GP.Route.ToGiver(data.id) end, 110 })
end

local function showClassChain(data)
    local chain = data.chain
    local steps, done, nextStep = GP.ClassQuests.Status(chain)
    local title = questHead(chain.id, chain.title, (L("from level %d"):format(chain.minLevel))
        .. (chain.dungeon and (" · " .. chain.dungeon) or ""))
    local open = {}
    for _, st in ipairs(steps) do if not st.done and not st.skipped then open[#open + 1] = { id = st.id, level = st.level } end end
    local xp = GP.QuestXP.Sum(open)
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Steps"), value = ("%d/%d"):format(done, #steps), color = C.text, emphasis = true },
        { label = L("Experience"), value = xp > 0 and GP.QuestXP.Text(xp) or "-", color = C.gold },
        { label = L("Quest level"), value = tostring(chain.level or "?"), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    if not data.own then
        detailLine("GameFontDisableSmall", L("Class quests of another class: to look at."), C.muted)
    elseif nextStep and type(nextStep.minLevel) == "number" and nextStep.minLevel > GP.Player().level then
        detailLine("GameFontHighlightSmall", (L("Next step from level %d."):format(nextStep.minLevel)), C.muted)
    end
    if done < #steps then
        local buttons = {}
        if nextStep then buttons[#buttons + 1] = { L("Next step"), function() GP.Route.ToGiver(nextStep.id) end, 110 } end
        buttons[#buttons + 1] = { L("Whole chain"), function() GP.Route.ToChain(chain.id) end, 110 }
        if data.own then buttons[#buttons + 1] = { L("Into my route"), function() GP.ClassQuests.ToMyRoute(chain) end, 130 } end
        buttons[#buttons + 1] = { L("Map"), function() GP.Map.Chain(chain.id) end, 80 }
        tools(buttons)
    end
    chainSteps(steps, chain.id)
end

local function showClutter(data, total)
    local item = data.item
    local reason = data.reason == "unusable" and L("Your class cannot use it.")
        or (L("Worse than what you wear (%s)."):format((data.percent and (signed(data.percent) .. " %")) or signed(data.gain or 0)))
    showItemHead(item, reason)
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Vendor price"), value = money(item.sellPrice), color = C.gold, emphasis = true },
        { label = L("All of the list"), value = money(total), color = C.text },
        { label = L("Required level"), value = tostring(item.minLevel or "?"), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    detailLine("GameFontDisableSmall", L("Only gear is listed. Items CraftPilot reserves for plans are never listed. Check bind-on-equip items for the auction house before you sell."), C.muted)
end

-- Settings and help ---------------------------------------------------------------------------------------------------
local pageLines = {}
local function pageText(i, font, x, y, width, value, c, align)
    local t = pageLines[i] or S.Text(U.pageContent, font, 0, 0, 10)
    pageLines[i] = t
    t:SetFontObject(S.Font(font))
    t:SetJustifyH(align or "LEFT")
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", x, -y)
    t:SetWidth(width)
    t:SetText(value)
    c = c or C.text
    t:SetTextColor(c[1], c[2], c[3])
    t:Show()
    return t
end
local function control(key, width, caption, callback)
    local b = U.controls[key]
    if not b then
        b = S.Button(U.pageContent, width, 26, caption, callback)
        U.controls[key] = b
    end
    b:SetText(caption)
    b:SetWidth(width)
    b:Show()
    return b
end

local function renderSettings()
    local s = GP.settings
    local width = frame:GetWidth() - 36 - 32 - 16
    local y, n = 16, 0
    local function text(font, value, c, xx)
        n = n + 1
        local t = pageText(n, font, xx or 16, y, width - (xx or 0), value, c)
        y = y + math.max(16, t:GetStringHeight() or 16) + 6
        return t
    end
    local function toggle(key, field, on, off)
        for i, option in ipairs({ { true, on or "On" }, { false, off or "Off" } }) do
            local b = control(key .. i, 100, L(option[2]), function() s[field] = option[1]; GP.Render() end)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16 + (i - 1) * 108, -y)
            S.Segment(b, s[field] == option[1])
        end
        y = y + 40
    end
    text("GameFontNormal", L("Level range"), C.gold)
    text("GameFontHighlightSmall", L("Quests, vendors, crafting and the auction house from this many levels below to this many levels above your level are compared. Dungeons have their own range below."))
    local function stepper(key, label, field, xx, max)
        n = n + 1
        pageText(n, "GameFontHighlightSmall", xx, y + 6, 120, label)
        local minus = control(key .. "-", 26, "-", function() s[field] = math.max(0, s[field] - 1); GP.Render() end)
        minus:ClearAllPoints()
        minus:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", xx + 124, -y)
        n = n + 1
        pageText(n, "GameFontHighlight", xx + 154, y + 6, 30, tostring(s[field]), C.gold, "CENTER")
        local plus = control(key .. "+", 26, "+", function() s[field] = math.min(max or 10, s[field] + 1); GP.Render() end)
        plus:ClearAllPoints()
        plus:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", xx + 188, -y)
    end
    stepper("below", L("Levels below"), "below", 16)
    stepper("above", L("Levels above"), "above", 260)
    y = y + 44
    text("GameFontHighlightSmall", L("Quests until they turn grey: also older quests that still give experience."))
    toggle("questsGrey", "questsGrey")

    text("GameFontNormal", L("Dungeon range"), C.gold)
    text("GameFontHighlightSmall", L("A dungeon counts when its level range overlaps this range: from this many levels below to this many levels above your level. The other dungeons stay visible under Per dungeon, dimmed."))
    stepper("dungeonBelow", L("Levels below"), "dungeonBelow", 16, 15)
    stepper("dungeonAbove", L("Levels above"), "dungeonAbove", 260, 15)
    y = y + 44
    text("GameFontHighlightSmall", L("To go list: remove a dungeon by itself once its quests are done and its wishlist items received."))
    toggle("togoAuto", "togoAutoRemove")

    text("GameFontNormal", L("Quest route"), C.gold)
    text("GameFontHighlightSmall", L("Detour: objectives and turn-ins of quests you already have come first when they lie on the way to the next step and make the way at most this much longer (at least 60 m always count). Off: always the nearest step."))
    for i, value in ipairs({ 0, 0.15, 0.3, 0.5 }) do
        local b = control("detour" .. i, 80, value == 0 and L("Off") or ("%d %%"):format(value * 100), function()
            s.routeDetour = value
            GP.QuestRoute.Invalidate()
            GP.Render()
        end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16 + (i - 1) * 88, -y)
        S.Segment(b, s.routeDetour == value)
    end
    y = y + 40

    text("GameFontNormal", L("Stat profile"), C.gold)
    text("GameFontHighlightSmall", L("Automatic picks the profile from your talents. The weights are provisional and will be refined with player feedback."))
    local options = { { key = "auto", name = "Automatic (talents)" } }
    for _, profile in ipairs(P.All()) do options[#options + 1] = profile end
    local per = math.floor((width - 16) / 3)
    for i, option in ipairs(options) do
        local b = control("profile" .. i, per - 8, L(option.name), function()
            if option.key == "auto" then s.autoProfile = true else s.autoProfile = false; s.profile = option.key end
            GP.Render()
        end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16 + ((i - 1) % 3) * per, -(y + math.floor((i - 1) / 3) * 32))
        S.Segment(b, (option.key == "auto" and s.autoProfile) or (not s.autoProfile and s.profile == option.key))
    end
    y = y + math.ceil(#options / 3) * 32 + 8
    local edit = control("weights", 200, L("Edit own profile"), function() GP.EditWeights() end)
    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16, -y)
    n = n + 1
    pageText(n, "GameFontDisableSmall", 228, y + 7, width - 228, L("Own weights or a Pawn / WoWSims scale (paste the Pawn string)."), C.muted)
    y = y + 40

    text("GameFontNormal", L("Sources in best upgrades"), C.gold)
    text("GameFontHighlightSmall", L("Bags, quests and dungeons always count. These sources can be added:"))
    for i, option in ipairs({ { "Vendors", "Vendors" }, { "Auction", "Auction house" }, { "Crafted", "Crafting" } }) do
        local key = option[1]
        local b = control("include" .. i, 150, L(option[2]), function() s.include[key] = not s.include[key]; GP.Render() end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16 + (i - 1) * 158, -y)
        S.Segment(b, s.include[key])
    end
    y = y + 40

    text("GameFontNormal", L("Minimum drop chance"), C.gold)
    text("GameFontHighlightSmall", L("Dungeon items below this chance are left out. Unknown chances from new Forever dungeons and bosses are always shown."))
    for i, value in ipairs({ 0.01, 0.02, 0.05, 0.1 }) do
        local b = control("chance" .. i, 80, ("%d %%"):format(value * 100), function() s.minChance = value; GP.Render() end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", 16 + (i - 1) * 88, -y)
        S.Segment(b, s.minChance == value)
    end
    y = y + 40

    text("GameFontNormal", L("Item tooltip"), C.gold)
    text("GameFontHighlightSmall", L("Shows in every item tooltip how much better or worse the item is than what you wear."))
    toggle("tooltip", "tooltip")
    text("GameFontNormal", L("Quest rewards"), C.gold)
    text("GameFontHighlightSmall", L("Marks the best reward in the quest window. Without an upgrade, the reward with the highest vendor price."))
    toggle("reward", "rewardHelp")
    text("GameFontNormal", L("Need and greed"), C.gold)
    text("GameFontHighlightSmall", L("A chat line for every roll: upgrade for you, how much, or not usable."))
    toggle("roll", "rollHelp")
    text("GameFontNormal", L("Wishlist hints"), C.gold)
    text("GameFontHighlightSmall", L("Chat hints when a wishlist item is in the auction house (at or below your wish price), when your target or the dungeon you enter can drop one, and when you receive it."))
    toggle("wish", "wishAlerts")
    text("GameFontNormal", L("Minimap button"), C.gold)
    text("GameFontHighlightSmall", L("Left click opens GearPilot, right click the settings. Drag it around the minimap. GearPilot is also in the addon list button of the minimap."))
    toggle("minimap", "minimap")
    if GP.UpdateMinimapButton then GP.UpdateMinimapButton() end

    text("GameFontNormal", L("Addons"), C.gold)
    local build = GP.Sources.BuildDate()
    text("GameFontHighlightSmall", "ForeverDB: " .. (build and (L("installed, data from ") .. build) or L("missing (quests, dungeons and vendors need it)")))
    text("GameFontHighlightSmall", "Auctionator: " .. (GP.HasAuctionPrices() and L("prices available") or L("not installed")))
    text("GameFontHighlightSmall", "CraftPilot: " .. (GP.CraftPilot() and L("recipe catalog available") or L("not installed")))
    text("GameFontHighlightSmall", "TomTom: " .. ((type(TomTom) == "table") and L("arrows for every waypoint") or L("not installed (the game's map waypoint is used)")))

    text("GameFontNormal", L("Data sources"), C.gold)
    text("GameFontHighlightSmall", L("Quest rewards and dungeon drops come from ForeverDB (GPL-3.0, github.com/foreverfraddons/forever-db)."))
    text("GameFontHighlightSmall", L("Bosses and loot of the new Forever dungeons come from AllTheThings (MIT, github.com/ATTWoWAddon/AllTheThings)."))
    U.pageContent:SetHeight(y + 16)
end

local function renderHelp()
    local width = frame:GetWidth() - 36 - 32 - 16
    local y, n = 16, 0
    local function text(font, value, c)
        n = n + 1
        local t = pageText(n, font, 16, y, width, value, c)
        y = y + math.max(16, t:GetStringHeight() or 16) + 8
    end
    text("GameFontNormal", L("How GearPilot works"), C.gold)
    text("GameFontHighlightSmall", L("GearPilot scores every item with the values of your stat profile and compares it with what you wear in the same slot. The score gain is the difference."))
    text("GameFontHighlightSmall", L("Best upgrades lists bag items, quest rewards and dungeon drops together. Quests count inside your level range, dungeons inside the dungeon range; quests you have done are hidden."))
    text("GameFontHighlightSmall", L("Quest choice rewards: you can take one item per quest, so only the best one is shown."))
    text("GameFontNormal", L("Views"), C.gold)
    text("GameFontHighlightSmall", L("Quests by zone: where questing pays most, with waypoints to every quest giver. Dungeons per dungeon: the expected gain of one run (score gain times drop chance) plus the dungeon quests."))
    text("GameFontHighlightSmall", L("Quest route: the quests worth most at your level (experience plus the upgrade value of their rewards) in the zone that pays most for the way there, in an order: accept, objectives, turn in, nearest first. Go sets the waypoint to the next step and moves on by itself; the route follows your level and shows the next zone when this one runs dry."))
    text("GameFontHighlightSmall", L("Dungeon details: your upgrades and the expected gain of one run, every quest of the dungeon with its chain and best reward, and the loot of every boss (your upgrades bright, wishlist items marked). Dungeons outside your range stay visible, dimmed."))
    text("GameFontHighlightSmall", L("To go: your own list of dungeons to run. Order it, collect every quest you need before the runs in one go (nearest first), and see how often you have been there."))
    text("GameFontHighlightSmall", L("Buy & craft: vendor gear, the auction house (Auctionator prices) and recipes from CraftPilot. Bags: upgrades, and gear that can go."))
    text("GameFontHighlightSmall", L("Wishlist: add items with the button in any item details or with Ctrl+Alt-click (Alt-click stays with CraftPilot). Every source is listed with a waypoint, the dungeon entrance or the hand-over to CraftPilot. One goal per slot gives your own BIS list; share it as text."))
    text("GameFontHighlightSmall", L("BIS (calculated): GearPilot works out the best item per slot from quests, dungeons, vendors and crafting with your profile's weights. It is not an official BIS list: set bonuses and random effects are not scored and the weights are provisional."))
    text("GameFontHighlightSmall", L("Auction house: upgrades from your last Auctionator scan, with how old each price is, a maximum price (presets or your own amount) and a search button while the auction house is open."))
    text("GameFontHighlightSmall", L("Quest chains: steps you skipped (optional or breadcrumb quests) count as done, grey quests are marked, and quests whose alternative you have done are hidden. A Classic quest and its Forever replacement count as one."))
    text("GameFontHighlightSmall", L("Equipped gear, weapon setup: your best two-hand weapon against your best main hand and off hand, from what you wear and carry or from every source in your level range."))
    text("GameFontNormal", L("Limits"), C.gold)
    text("GameFontHighlightSmall", L("Weights are provisional. Random proc effects and set bonuses are not scored. Items the game has not loaded yet appear a moment later."))
    text("GameFontNormal", L("Commands"), C.gold)
    text("GameFontHighlightSmall", "/gpp · /gearpilotpro")
    U.pageContent:SetHeight(y + 16)
end

-- Render ------------------------------------------------------------------------------------------------------------
local titles = {
    upgrades = { "Best upgrades", "Bags, quests and dungeons in your level range, best first" },
    quests = { "Quests", "Quest rewards that improve your gear" },
    dungeons = { "Dungeons", "Dungeon drops that improve your gear" },
    raids = { "Raids", "Raids, their loot for you and the quests to get in" },
    shop = { "Buy & craft", "Vendors, auction house and crafting" },
    auction = { "Auction house", "Upgrades from your last Auctionator scan" },
    wishlist = { "Wishlist", "Items you want, where they come from and the way there" },
    bags = { "Bags", "Items in your bags that beat what you wear" },
    gear = { "Equipped gear", "Your equipment and its score" },
    route = { "Quest route", "The quests worth most at your level, in an order to do them" },
    settings = { "Settings", "Level range, stat profile, sources and helpers" },
    help = { "Help", "How GearPilot works" },
}

-- Best in slot, calculated: pool of quest rewards, dungeon drops (with or without raids), vendor items and
-- CraftPilot recipes up to the target level. Cached until the item data is complete.
local bisCache = {}
local function sourceShort(row)
    if not row then return "" end
    if row.source == "Quests" then return L("Quest") .. " " .. (row.name or "") end
    if row.source == "Dungeons" then return GP.Sources.DungeonName(row) end
    if row.source == "Vendors" then return L("Vendor: ") .. (row.name or "") end
    if row.source == "Crafted" then return L(professionNames[row.profession] or row.profession or "") end
    return ""
end
-- " · opens 09.12.2026 (provisional)" for loot of a raid that is not open yet.
local function raidOpensText(row)
    local name = row and ((row.raid and row.name) or (row.raidQuest and row.dungeonQuest))
    local opens = name and GP.RaidOpens(name)
    return opens and (" · " .. (L("opens %s (provisional)"):format(opens))) or ""
end
function GP.BisList(s, low, high, profile, player, equipped)
    local target = s.bisTarget or "now"
    local maxLevel = target == "now" and high or 60
    local minLevel = target == "now" and math.max(1, player.level - 10) or 45
    -- The pick depends on the weights (own profile included); owned and the comparison are worked out fresh.
    local key = table.concat({ target, P.Signature(profile), player.level, maxLevel }, ":")
    local cached = bisCache[key]
    local function build(picks)
        local list = {}
        for _, best in ipairs(picks) do
            if GP.SlotAllowed(best.slot) then
                local id = best.item.id
                local worn = equipped[best.slot] and equipped[best.slot].id == id
                list[#list + 1] = { kind = "bis", bis = true, key = "bis:" .. best.slot, id = id, item = best.item, slot = best.slot,
                    score = best.score, owned = worn or GP.Wish.Owned(id),
                    result = P.Compare(best.item, equipped, profile, player.class, player.level),
                    sourceText = sourceShort(best.entry and best.entry.row) .. raidOpensText(best.entry and best.entry.row) }
            end
        end
        return list
    end
    if cached and not cached.loading then return build(cached.picks), false, {}, "bis" end
    local db = GP.Sources.Database()
    if not db then return {}, false, { missing = true }, "bis" end
    local rows = {}
    for _, row in ipairs(GP.Sources.Rows(player.class, player.faction, s.minChance, player.raceBit) or {}) do rows[#rows + 1] = row end
    local cp = GP.CraftPilot()
    if cp then
        GP.craftedRows = GP.craftedRows or GP.Sources.Crafted(cp.CatalogData, db, player.class)
        for _, row in ipairs(GP.craftedRows) do rows[#rows + 1] = row end
    end
    local pool, loading, seen = {}, false, {}
    for _, row in ipairs(rows) do
        local info = db.item[row.itemID]
        local required = info and info[3] or 0
        local wanted = required <= maxLevel and required >= minLevel and not seen[row.itemID]
            and (target == "raid" or not (row.raid or row.raidQuest))
            -- 1.6.1: raid loot only from raids confirmed for WoW Forever (not the Classic ones in the data).
            and not (row.raid and not GP.ForeverRaid(row.name)) and not (row.raidQuest and not GP.ForeverRaid(row.dungeonQuest))
        if wanted then
            -- Cheap check before loading the item: armor type and weapon class from ForeverDB.
            local light = { classID = info[5], subclassID = info[6], equip = P.inventoryTypes[info[7]], minLevel = required }
            if light.equip and P.CanUse(light, player.class, math.max(player.level, required)) then
                seen[row.itemID] = true
                local item = GP.ItemData(row.itemID)
                if item.name then
                    pool[#pool + 1] = { item = item, key = row.itemID, entry = { source = row.source, row = row, choiceGroup = row.choiceGroup } }
                else
                    loading = true
                end
            end
        end
    end
    local picks = P.BestInSlot(pool, profile, player.class, player.level, maxLevel)
    bisCache[key] = { picks = picks, loading = loading }
    return build(picks), loading, {}, "bis"
end
function GP.AdoptBis()
    local s = GP.settings
    local player = GP.Player()
    local low, high = P.Range(player.level, s.below, s.above)
    local list = GP.BisList(s, low, high, GP.ActiveProfile(), player, GP.ReadGear())
    local count = 0
    for _, data in ipairs(list) do
        if not data.owned then
            GP.Wish.List()[data.id] = GP.Wish.List()[data.id] or { added = time and time() or 0 }
            GP.Wish.SetGoal(data.id, true)
            count = count + 1
        end
    end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. (L("%d BIS items taken over as goals."):format(count))) end
    GP.Render()
end

-- What the list of a page shows: kind and data.
-- Quest route: the open tasks of the plan (a travel row first when the zone is far away), and the summary.
-- 1.5.0 views of the route page.
local function routeViewData(view)
    local QR = GP.QuestRoute
    local plan = QR.Current()
    if not plan then return {}, false, { missing = true }, "route" end
    local list = {}
    if view == "pick" then
        -- Every quest you can take (or have), nearby or in all zones, best first; your picks marked.
        local here = QR.Position()
        local near = (GP.settings.routePick or "near") == "near"
        for _, q in ipairs(plan.candidates or {}) do
            local p = q.giver or q.ender
            if not near or not here or (p and QR.Distance(here, p) < 2500) then
                list[#list + 1] = { key = "pick:" .. q.id, q = q, mine = QR.InMine(q.id) }
            end
        end
        table.sort(list, function(a, b)
            if a.mine ~= b.mine then return a.mine end
            if (a.q.zoneName or "") ~= (b.q.zoneName or "") then return (a.q.zoneName or "") < (b.q.zoneName or "") end
            return a.q.value > b.q.value
        end)
        local count, max = #GP.QuestLog.Quests(), GP.QuestLog.Max()
        GP.routeSummary = (L("%d quests to choose from"):format(#list)) .. "  ·  " .. (L("quest log %d/%d"):format(count, max))
        return list, false, {}, "routepick"
    elseif view == "class" then
        local player = GP.Player()
        local class = GP.settings.classView or player.class
        U.classButton:SetText(class == player.class and (L("Your class") .. " (" .. GP.ClassQuests.ClassName(class) .. ")")
            or GP.ClassQuests.ClassName(class))
        for _, chain in ipairs(GP.ClassQuests.Chains(class)) do
            list[#list + 1] = { key = "class:" .. chain.id, chain = chain, own = class == player.class }
        end
        GP.routeSummary = (L("%d class quest chains"):format(#list)) .. "  ·  " .. GP.ClassQuests.ClassName(class)
            .. (class ~= player.class and ("  ·  " .. L("to look at")) or "")
        return list, false, {}, "classquest"
    elseif view == "log" then
        for _, entry in ipairs(GP.QuestLog.Ranked()) do list[#list + 1] = { key = "log:" .. entry.id, entry = entry } end
        local count, max = #GP.QuestLog.Quests(), GP.QuestLog.Max()
        GP.routeSummary = (L("Quest log %d/%d"):format(count, max)) .. "  ·  " .. L("best to abandon first")
        return list, false, {}, "questlog"
    elseif view == "later" then
        for _, entry in ipairs(GP.QuestLog.LaterList()) do list[#list + 1] = { key = "later:" .. entry.id, entry = entry } end
        GP.routeSummary = L("Quests you abandoned to take again later")
        return list, false, {}, "questlater"
    else
        for _, id in ipairs(QR.Skipped()) do list[#list + 1] = { key = "skip:" .. id, id = id } end
        GP.routeSummary = L("Quests you took out of the route")
        return list, false, {}, "routeskip"
    end
end

local function routeData(player)
    local QR = GP.QuestRoute
    local view = GP.settings.views.route or "route"
    if view ~= "route" then return routeViewData(view) end
    local plan = QR.Current()
    if not plan then return {}, false, { missing = true }, "route" end
    local list = {}
    local zone = plan.zone
    if zone and zone.distance > 1500 then
        local _, _, node = QR.FlightPoint(ForeverDB, zone.center, player.faction)
        local flight = QR.FlightName(node)
        list[#list + 1] = { key = "route:travel", travel = true, zone = zone, flight = flight }
    end
    for _, entry in ipairs(QR.OpenTasks(plan)) do
        local i, t = entry.index, entry.t
        list[#list + 1] = { key = ("route:%d:%s:%d"):format(i, t.kind, t.quest.id), task = t, index = i }
    end
    -- Summary: zone, quests, experience and how far it gets you.
    local parts = {}
    if plan.mine then parts[#parts + 1] = L("My route") end
    if zone then parts[#parts + 1] = zone.name or "?" end
    parts[#parts + 1] = (L("%d quests"):format(#plan.quests))
    if plan.xp > 0 then
        local text = GP.QuestXP.Text(plan.xp)
        local current, max = UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player")
        if current and max and max > 0 and player.level < 60 then
            local total = current + plan.xp
            local levels = math.floor(total / max)
            local rest = math.floor((total % max) / max * 100 + .5)
            -- Every level needs more than this one; past the next level this is a rough guide, capped at 60.
            if player.level + levels >= 60 then levels, rest = 60 - player.level, 0 end
            text = text .. " · " .. (levels > 0 and (L("enough for level %d + %d %%"):format(player.level + levels, rest))
                or (L("%d %% of this level"):format(math.floor(plan.xp / max * 100 + .5))))
        end
        parts[#parts + 1] = text
    end
    if plan.next then parts[#parts + 1] = L("then: ") .. (plan.next.name or "?") end
    GP.routeSummary = table.concat(parts, "  ·  ")
    return list, false, {}, "route"
end

local function pageData(page, s, low, high, equipped, profile, player)
    if page == "route" then return routeData(player) end
    if page == "gear" then
        if (s.views.gear or "worn") ~= "weapons" then return gearRows(equipped, profile), false, {}, "gear" end
        -- Weapon setups: worn weapons and bags, optionally every source in the level range.
        local sources = { "Bags" }
        if s.weaponPool == "all" then
            sources = { "Bags", "Quests", "Dungeons" }
            for _, key in ipairs({ "Vendors", "Auction", "Crafted" }) do
                if s.include[key] then sources[#sources + 1] = key end
            end
        end
        local entries, loading, states = collect(sources, low, high)
        local pool = {}
        for slot = 16, 17 do
            if equipped[slot] and equipped[slot].stats then
                pool[#pool + 1] = { item = equipped[slot], key = "worn" .. slot, entry = { source = "Worn" } }
            end
        end
        for _, entry in ipairs(entries) do pool[#pool + 1] = { item = entry.item, key = entry.key, entry = entry } end
        local maxLevel = s.weaponPool == "all" and high or player.level
        local sets = P.WeaponSets(pool, equipped, profile, player.class, player.level, maxLevel)
        local list = { { key = "set:current", setKind = "current", set = sets.current, sets = sets } }
        if sets.twoHand then list[#list + 1] = { key = "set:2h", setKind = "twoHand", set = sets.twoHand, sets = sets } end
        if sets.pair then list[#list + 1] = { key = "set:pair", setKind = "pair", set = sets.pair, sets = sets } end
        return list, loading, states, "weapons"
    end
    if page == "upgrades" then
        local sources = { "Bags", "Quests", "Dungeons" }
        for _, key in ipairs({ "Vendors", "Auction", "Crafted" }) do
            if s.include[key] then sources[#sources + 1] = key end
        end
        local list, loading, states = recommend(sources, low, high, equipped, profile, player)
        return list, loading, states, "upgrade"
    end
    if page == "quests" then
        local list, loading, states = recommend({ "Quests" }, low, high, equipped, profile, player)
        for _, result in ipairs(list) do
            local spot = ForeverDB and GP.Sources.Spot(ForeverDB, result.entry.row.giverRef)
            local distance = GP.Sources.Distance(spot)
            result.entry.distance = distance and math.floor(distance + .5) or nil
        end
        -- Chains you have started (a step done or in the quest log) and quests already in the log.
        local started, inLog = 0, 0
        local kept = {}
        for _, result in ipairs(list) do
            local id = result.entry.row.sourceID
            local chain = GP.Route.Chain(id)
            local _, _, begun = P.ChainStatus(chain)
            local active = GP.Route.Step and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false
            result.entry.started = begun or active
            if begun and #chain > 1 then started = started + 1 end
            if active then inLog = inLog + 1 end
            if s.chains ~= "started" or result.entry.started then kept[#kept + 1] = result end
        end
        list = kept
        GP.questSummary = (L("%d quest chains started · %d quests with an upgrade in your quest log")):format(started, inLog)
        if (s.views.quests or "items") == "zones" then return P.ByZone(list), loading, states, "zone" end
        if s.questSort == "distance" then
            table.sort(list, function(a, b)
                local da, db = a.entry.distance or math.huge, b.entry.distance or math.huge
                if da ~= db then return da < db end
                return a.gain > b.gain
            end)
        elseif s.questSort == "zone" then
            table.sort(list, function(a, b)
                local za, zb = a.entry.row.zone or "~", b.entry.row.zone or "~"
                if za ~= zb then return za < zb end
                return a.gain > b.gain
            end)
        end
        return list, loading, states, "upgrade"
    end
    if page == "dungeons" or page == "raids" then
        -- 1.6.1: raids have their own page (per raid); the dungeon page lists dungeons only.
        local raids = page == "raids"
        local view = raids and "overview" or (s.views.dungeons or "items")
        if view == "items" then
            local list, loading, states = recommend({ "Dungeons" }, low, high, equipped, profile, player)
            return list, loading, states, "upgrade"
        end
        -- Per dungeon and to go: every dungeon of the catalog, upgrades from all of them.
        local drops, loading, states = recommend({ "Dungeons" }, low, high, equipped, profile, player, true)
        local quests = recommend({ "Quests" }, low, high, equipped, profile, player)
        local byName = {}
        for _, entry in ipairs(P.ByDungeon(drops, quests)) do byName[entry.name] = entry end
        local catalog = GP.Catalog()
        local dLow, dHigh = GP.DungeonRange()
        local function entryFor(d)
            local entry = byName[d.name] or { key = "dungeon:" .. d.name, name = d.name, row = { name = d.name }, results = {},
                quests = {}, expected = 0, unknown = 0 }
            entry.row.mapID = entry.row.mapID or d.mapID
            entry.row.raid = entry.row.raid or d.raid
            entry.catalog = d
            entry.low, entry.high = d.low, d.high
            entry.inRange = GP.DungeonInRange(d, dLow, dHigh)
            local quests, open = GP.Togo.Quests(d)
            entry.openQuests = open
            local openList = {}
            for _, info in ipairs(quests) do if not info.done then openList[#openList + 1] = info end end
            entry.openXP = GP.QuestXP.Sum(openList)
            return entry
        end
        local list = {}
        if view == "togo" then
            local _, cat = GP.Catalog()
            local finished = {}
            for _, saved in ipairs(GP.Togo.List()) do
                local d = cat[saved.name]
                if d then
                    if s.togoAutoRemove and GP.Togo.Finished(d) then
                        finished[#finished + 1] = d.name
                    else
                        local entry = entryFor(d)
                        entry.togo = saved
                        entry.wishCount = #GP.Togo.WishItems(d)
                        list[#list + 1] = entry
                    end
                end
            end
            for _, name in ipairs(finished) do GP.Togo.Remove(name) end
            return list, loading, states, "dungeon"
        end
        for _, d in ipairs(catalog) do
            if raids then
                if d.raid and (s.raidShow == "all" or GP.ForeverRaid(d.name)) then list[#list + 1] = entryFor(d) end
            elseif not d.raid then
                local entry = entryFor(d)
                if entry.inRange or s.dungeonShow ~= "range" then list[#list + 1] = entry end
            end
        end
        local level = player.level
        table.sort(list, function(a, b)
            if a.inRange ~= b.inRange then return a.inRange end
            if a.inRange then
                if a.expected ~= b.expected then return a.expected > b.expected end
                return a.low < b.low
            end
            local da = math.min(math.abs(a.low - level), math.abs(a.high - level))
            local db = math.min(math.abs(b.low - level), math.abs(b.high - level))
            if da ~= db then return da < db end
            return a.low < b.low
        end)
        return list, loading, states, "dungeon"
    end
    if page == "shop" then
        local sources = s.shopSource == "all" and { "Vendors", "Auction", "Crafted" } or { s.shopSource }
        local all, loading, states = recommend(sources, low, high, equipped, profile, player)
        -- Price: auction = Auctionator price, vendor = estimate from the vendor sell price, crafted = unknown.
        local list, cap = {}, s.shopMax or 0
        for _, result in ipairs(all) do
            local entry = result.entry
            local price = entry.source == "Auction" and entry.row.price
                or entry.source == "Vendors" and result.item.sellPrice and result.item.sellPrice > 0 and result.item.sellPrice * 4 or nil
            result.price = price
            if cap == 0 or (price and price <= cap) then list[#list + 1] = result end
        end
        if s.shopSort == "price" then
            table.sort(list, function(a, b)
                local pa, pb = a.price or math.huge, b.price or math.huge
                if pa ~= pb then return pa < pb end
                return a.gain > b.gain
            end)
        elseif s.shopSort == "value" then
            local function value(r) return r.price and r.price > 0 and r.gain / (r.price / 10000) or -1 end
            table.sort(list, function(a, b)
                local va, vb = value(a), value(b)
                if va ~= vb then return va > vb end
                return a.gain > b.gain
            end)
        end
        return list, loading, states, "upgrade"
    end
    if page == "wishlist" then
        local itemSlot = function(item)
            local slots = item and item.equip and P.targetSlots[item.equip]
            return slots and slots[1]
        end
        if (s.views.wishlist or "list") == "bis" then
            return GP.BisList(s, low, high, profile, player, equipped)
        end
        local list, loading = {}, false
        for id, wish in pairs(GP.Wish.List()) do
            local item = GP.ItemData(id)
            if item.name then
                local slot = itemSlot(item)
                if not slot or GP.SlotAllowed(slot) then
                    local result = P.Compare(item, equipped, profile, player.class, player.level)
                    local first = GP.Wish.Sources(id)[1]
                    local sourceText = first and (first.kind == "quest" and (L("Quest") .. " " .. (first.name or ""))
                        or first.kind == "dungeon" and GP.Sources.DungeonName(first) or first.kind == "vendor" and (L("Vendor: ") .. first.name)
                        or first.kind == "craft" and L(professionNames[first.profession] or first.profession)
                        or first.kind == "mob" and first.name or first.kind == "world" and L("World drop")) or nil
                    list[#list + 1] = { kind = "wish", key = "wish:" .. id, id = id, item = item, wish = wish, slot = result and result.slot or slot,
                        result = result, owned = wish.got or GP.Wish.Owned(id), sourceText = sourceText }
                end
            else
                loading = true
            end
        end
        table.sort(list, function(a, b)
            if (a.wish.goal and true or false) ~= (b.wish.goal and true or false) then return a.wish.goal == true end
            if a.owned ~= b.owned then return not a.owned end
            local ga, gb = a.result and a.result.gain or -math.huge, b.result and b.result.gain or -math.huge
            if ga ~= gb then return ga > gb end
            return a.id < b.id
        end)
        local reached, goals = GP.Wish.Progress()
        GP.wishSummary = goals > 0 and (L("Goals: %d of %d reached")):format(reached, goals) or nil
        return list, loading, {}, "wish"
    end
    if page == "auction" then
        -- Every item with a price from your last scan: required level from 10 below your level to the top of the range.
        local entries, loading, state = GP.AuctionCandidates(player.level - 10, high)
        local all = P.Recommend(entries, equipped, { level = player.level, below = 10, above = s.above, profile = profile,
            class = player.class, slotAllowed = GP.SlotAllowed })
        local list, cap = {}, s.ahMax or 0
        for _, result in ipairs(all) do
            local row = result.entry.row
            local fresh = s.ahAge == "all" or (row.age and (s.ahAge == "today" and row.age == 0 or s.ahAge == "week" and row.age <= 7))
            result.price = row.price
            if GP.SlotAllowed(result.slot) and fresh and (cap == 0 or row.price <= cap) then list[#list + 1] = result end
        end
        if s.ahSort == "price" then
            table.sort(list, function(a, b)
                if a.price ~= b.price then return a.price < b.price end
                return a.gain > b.gain
            end)
        elseif s.ahSort == "value" then
            local function value(r) return r.gain / math.max(1, r.price / 10000) end
            table.sort(list, function(a, b)
                local va, vb = value(a), value(b)
                if va ~= vb then return va > vb end
                return a.gain > b.gain
            end)
        end
        local states = {}
        states[state] = true
        return list, loading, states, "upgrade"
    end
    -- bags
    if (s.views.bags or "upgrades") == "clutter" then
        local entries, loading = collect({ "Bags" }, low, high)
        local list = {}
        for _, data in ipairs(P.Clutter(entries, equipped, profile, player.class, player.level, GP.Reserved())) do
            if not data.slot or GP.SlotAllowed(data.slot) then list[#list + 1] = data end
        end
        local total = 0
        for _, data in ipairs(list) do total = total + (data.item.sellPrice or 0) end
        list.total = total
        return list, loading, {}, "clutter"
    end
    local list, loading, states = recommend({ "Bags" }, low, high, equipped, profile, player)
    return list, loading, states, "upgrade"
end

local function emptyMessage(page, kind, loading, states)
    if states.missing and page ~= "bags" and page ~= "gear" then
        return L("ForeverDB is not installed. Quests and dungeons need it; the CurseForge app installs it with GearPilot. Bag upgrades work without it.")
    end
    if loading then return L("Loading item data …") end
    if page == "wishlist" then
        if kind == "bis" then
            if loading then return L("Calculating … item data is still loading.") end
            return GP.Sources.Database() and L("No items found for this target.") or L("ForeverDB missing")
        end
        if (GP.settings.slotFilter or "all") ~= "all" then return L("No wishlist items for this slot.") end
        return L("Your wishlist is empty. Add items with the button in any item details or with Ctrl+Alt-click on an item.")
    end
    if page == "auction" then
        if states.noauction then return L("Auctionator is not installed. The auction house page uses its scan prices.") end
        if states.noprices then return L("No prices yet: open the auction house and let Auctionator scan it.") end
        if loading then return L("Loading item data …") end
        return L("No upgrades in the auction house with these filters. Try a higher price or any time.")
    end
    if page == "shop" and (states.noauction or states.nocraftpilot) then
        return L("No upgrades here. The auction house needs Auctionator with a scan, crafting needs CraftPilot.")
    end
    if (GP.settings.slotFilter or "all") ~= "all" then return L("No upgrades for this slot. Choose all slots or another slot.") end
    if kind == "clutter" then return L("Nothing to get rid of: all gear in your bags is useful.") end
    if kind == "routepick" then return L("No quests you can take here. Try All zones.") end
    if kind == "questlog" then return L("Your quest log is empty.") end
    if kind == "questlater" then return L("No remembered quests. Abandon a quest with Remember under Quest log to find it here again.") end
    if kind == "routeskip" then return L("No skipped quests.") end
    if page == "route" and GP.settings.routeMode == "mine" then
        return L("Your own route is empty. Choose quests under Choose quests and add them with Add to my route.")
    end
    if page == "route" then return L("No quests worth doing found near your level. Grey quests and quests you have done are left out.") end
    if page == "raids" then return L("No raids in the data yet. New raids come with the weekly dungeon data.") end
    if page == "dungeons" and (GP.settings.views.dungeons or "items") == "togo" then
        return L("Your to go list is empty. Open a dungeon under Per dungeon and add it with + To go.")
    end
    return L("No upgrades in this selection. Try a wider level range in the settings.")
end

function fillRow(r, kind, data, width, list)
    local item = data.item
    r.link = item and item.link
    GP.QuestInfo.Set(r.quest, nil)
    r.icon:SetDesaturated(false)
    r.icon:SetAlpha(1)
    color(r.name, C.text)
    r.name:SetWidth(width - 120)
    r.sub:SetWidth(width - 120)
    if kind == "gear" then
        r.icon:SetTexture(item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        r.name:SetText(item and (S.QualityColor(item.quality) .. (item.name or L("Loading item data …")) .. "|r")
            or ("|cff9dabb8" .. L("Empty slot") .. "|r"))
        r.sub:SetText(L(P.slotNames[data.slot] or ""))
        r.value:SetText(data.score and number(data.score) or "")
        color(r.value, C.gold)
    elseif kind == "weapons" then
        local set = data.set
        r.link = set.main and set.main.link
        r.icon:SetTexture(set.main and set.main.icon or "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand")
        local names = { current = L("Worn now"), twoHand = L("Best two-hand"), pair = L("Best main + off hand") }
        r.name:SetText(names[data.setKind])
        local parts = {}
        if set.main then parts[#parts + 1] = set.main.name end
        if set.off then parts[#parts + 1] = set.off.name end
        r.sub:SetText(#parts > 0 and table.concat(parts, " + ") or L("Empty slot"))
        if data.setKind == "current" then
            r.value:SetText(number(set.score))
            color(r.value, C.gold)
        else
            local diff = set.score - data.sets.current.score
            r.value:SetText(signed(diff))
            color(r.value, diff > 0 and C.green or diff < 0 and C.red or C.muted)
        end
    elseif kind == "wish" or kind == "bis" then
        r.icon:SetTexture(item.icon)
        r.name:SetText(S.QualityColor(item.quality) .. item.name .. "|r")
        local wish = GP.Wish.List()[data.id]
        local status = data.owned and ("|cff85d6a0" .. L("received") .. "|r") or (wish and wish.goal and ("|cffe0b050" .. L("goal") .. "|r"))
            or (kind == "bis" and wish and L("on wishlist")) or nil
        local where = data.sourceText or ""
        r.sub:SetText(slotText(item, data.slot) .. (status and (" · " .. status) or "") .. (where ~= "" and (" · " .. where) or ""))
        local result = data.result
        if data.owned or (result and result.worn) then
            r.value:SetText(L("worn"))
            color(r.value, C.muted)
        elseif result and result.usable == false then
            r.value:SetText("-")
            color(r.value, C.red)
        elseif result and result.gain then
            r.value:SetText(signed(result.gain))
            color(r.value, result.gain >= 0 and C.green or C.red)
        else
            r.value:SetText("")
        end
    elseif kind == "zone" then
        r.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
        r.name:SetText(data.zone)
        r.sub:SetText((L("%d quest upgrades"):format(#data.results)))
        r.value:SetText(signed(data.gain))
        color(r.value, C.green)
    elseif kind == "dungeon" then
        r.icon:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
        r.icon:SetDesaturated(not data.inRange)
        r.icon:SetAlpha(data.inRange and 1 or .5)
        r.name:SetText(GP.Sources.DungeonName(data.row) .. (data.row.raid and (" (" .. L("raid") .. ")") or ""))
        color(r.name, data.inRange and C.text or C.muted)
        local parts = { (L("Level %d–%d"):format(data.low, data.high)) }
        if not data.inRange then parts[#parts + 1] = L("outside your range") end
        -- 1.6.1: an open access chain (attunement or key).
        local missing = data.catalog and GP.Access.Missing(data.catalog.name)
        if missing then parts[#parts + 1] = "|cffe0b050" .. L("access open") .. "|r" end
        if data.row.raid and data.catalog and not GP.ForeverRaid(data.catalog.name) then parts[#parts + 1] = L("Classic") end
        local opens = data.row.raid and data.catalog and GP.RaidOpens(data.catalog.name)
        if opens then parts[#parts + 1] = "|cffe0b050" .. (L("opens %s (provisional)"):format(opens)) .. "|r" end
        if #data.results > 0 then parts[#parts + 1] = (L("%d upgrades"):format(#data.results)) end
        if (data.openQuests or 0) > 0 then
            parts[#parts + 1] = (L("%d open quests"):format(data.openQuests))
                .. (((data.openXP or 0) > 0) and (" (" .. GP.QuestXP.Text(data.openXP) .. ")") or "")
        end
        if data.togo then
            parts[#parts + 1] = (L("%d runs"):format(data.togo.runs or 0))
            if (data.wishCount or 0) > 0 then parts[#parts + 1] = (L("%d wishlist items"):format(data.wishCount)) end
        end
        r.sub:SetText(table.concat(parts, " · "))
        r.value:SetText(data.expected > 0 and ("Ø " .. signed(data.expected)) or "")
        color(r.value, data.inRange and C.green or C.muted)
    elseif kind == "route" then
        if data.travel then
            r.icon:SetTexture("Interface\\Icons\\Ability_Mount_Wyvern_01")
            r.name:SetText(L("Travel to ") .. (data.zone.name or "?"))
            r.sub:SetText((L("about %d m away"):format(math.floor(data.zone.distance)))
                .. (data.flight and (" · " .. L("flight point: ") .. data.flight) or ""))
            r.value:SetText("")
        else
            local t = data.task
            local icons = { accept = "Interface\\GossipFrame\\AvailableQuestIcon", objective = "Interface\\Icons\\Ability_Hunter_SniperShot",
                turnin = "Interface\\GossipFrame\\ActiveQuestIcon" }
            r.icon:SetTexture(t.buy and "Interface\\GossipFrame\\VendorGossipIcon" or icons[t.kind])
            r.name:SetText(("%d. %s"):format(data.index, GP.QuestRoute.Title(t.quest)))
            GP.QuestInfo.Set(r.quest, t.quest.id, t.quest.title)
            local sub = { GP.QuestRoute.TaskText(t) }
            local here = GP.QuestRoute.Position()
            if t.p and here then
                local d = GP.QuestRoute.Distance(here, t.p)
                if d < 5000 then sub[#sub + 1] = (L("%d m"):format(math.floor(d))) end
            end
            -- The gear it brings: on accepting (what you go for) and on turning in (where you get it).
            local q = t.quest
            if (q.gain or 0) > 0 and q.reward and (t.kind == "accept" or (t.kind == "turnin" and not q.rewardQuest)) then
                sub[#sub + 1] = "|cff85d6a0" .. signed(q.gain) .. "|r " .. S.QualityColor(q.reward.quality) .. (q.reward.name or "") .. "|r"
                    .. (q.rewardQuest and (" " .. L("(chain)")) or "")
            end
            r.sub:SetText(table.concat(sub, " · "))
            r.value:SetText((t.kind == "turnin" and t.quest.xp > 0) and GP.QuestXP.Text(t.quest.xp) or "")
            color(r.value, C.gold)
        end
    elseif kind == "classquest" then
        local chain = data.chain
        local steps, done = GP.ClassQuests.Status(chain)
        local level = GP.Player().level
        local early = chain.minLevel > level
        GP.QuestInfo.Set(r.quest, chain.id, chain.title)
        r.icon:SetTexture(done >= #steps and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\GossipFrame\\AvailableQuestIcon")
        r.icon:SetDesaturated(early)
        r.icon:SetAlpha(early and .5 or 1)
        r.name:SetText(GP.QuestInfo.Title(chain.id, chain.title))
        color(r.name, early and C.muted or C.text)
        local parts = { (L("from level %d"):format(chain.minLevel)) }
        if #steps > 1 then parts[#parts + 1] = (L("%d steps"):format(#steps)) end
        if chain.dungeon then parts[#parts + 1] = chain.dungeon end
        r.sub:SetText(table.concat(parts, " · "))
        r.value:SetText(done >= #steps and L("done") or ("%d/%d"):format(done, #steps))
        color(r.value, done >= #steps and C.green or early and C.muted or C.gold)
    elseif kind == "routepick" or kind == "questlog" or kind == "questlater" or kind == "routeskip" then
        local id, title, level
        if kind == "routepick" then id, title, level = data.q.id, data.q.title, data.q.level
        elseif kind == "routeskip" then id = data.id
        else id, title, level = data.entry.id, data.entry.title, data.entry.level end
        local db = ForeverDB
        local row = db and db.quest and db.quest[id]
        title = GP.QuestInfo.Title(id, title or (row and row[1]))
        level = level or (row and row[2])
        GP.QuestInfo.Set(r.quest, id, title)
        local inLog = GP.QuestInfo.LogIndex(id) ~= nil
        r.icon:SetTexture((kind == "routepick" and data.mine) and "Interface\\RaidFrame\\ReadyCheck-Ready"
            or inLog and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon")
        r.name:SetText(title)
        local sub = {}
        if level and level > 0 then sub[#sub + 1] = (L("Level %d")):format(level) end
        local value = ""
        if kind == "routepick" then
            local q = data.q
            if q.zoneName then sub[#sub + 1] = q.zoneName end
            if q.active then sub[#sub + 1] = "|cffe0b050" .. L("in quest log") .. "|r" end
            if q.escort then sub[#sub + 1] = L("escort") end
            if q.skipped then sub[#sub + 1] = L("skipped") end
            value = q.xp > 0 and GP.QuestXP.Text(q.xp) or ""
        elseif kind == "questlog" then
            local e = data.entry
            local c = e.advice == "abandon" and "|cffeb786b" or e.advice == "remember" and "|cffe0b050" or "|cff9dabb8"
            sub[#sub + 1] = c .. e.reason .. "|r"
            value = e.xp > 0 and GP.QuestXP.Text(e.xp) or ""
        elseif kind == "questlater" then
            sub[#sub + 1] = data.entry.inLog and ("|cffe0b050" .. L("in quest log") .. "|r") or L("remembered")
        else
            sub[#sub + 1] = L("skipped")
        end
        r.sub:SetText(table.concat(sub, " · "))
        r.value:SetText(value)
        color(r.value, C.gold)
    elseif kind == "clutter" then
        r.icon:SetTexture(item.icon)
        r.name:SetText(S.QualityColor(item.quality) .. item.name .. "|r")
        r.sub:SetText(data.reason == "unusable" and L("Not usable for your class")
            or (data.percent and (L("%d %% worse"):format(math.floor(-data.percent + .5))) or L("Worse than worn")))
        r.value:SetText(money(item.sellPrice))
        color(r.value, C.gold)
    else
        r.icon:SetTexture(item.icon)
        r.name:SetText(S.QualityColor(item.quality) .. item.name .. "|r")
        r.sub:SetText(slotText(item, data.slot) .. " · " .. sourceLine(data.entry))
        r.value:SetText(signed(data.gain))
        color(r.value, C.green)
    end
end

function GP.Render()
    if not frame:IsShown() or not GP.settings then return end
    -- Profile or settings may have changed: tooltip lines are worked out again.
    if GP.TooltipChanged then GP.TooltipChanged() end
    local s = GP.settings
    local page = s.page
    local player = GP.Player()
    local profile = GP.ActiveProfile()
    local low, high = P.Range(player.level, s.below, s.above)
    U.pageTitle:SetText(L(titles[page][1]))
    U.pageSub:SetText(L(titles[page][2]))
    GP.questSummary = nil
    for _, b in ipairs(U.nav) do
        local on = b.key == page
        b.iconBox:SetShown(on)
        if on then b.bg:SetColorTexture(C.raised[1], C.raised[2], C.raised[3], 1) else b.bg:SetColorTexture(1, 1, 1, 0) end
        if on then b.label:SetTextColor(.95, .94, .91) else b.label:SetTextColor(.72, .74, .76) end
        b.badge:SetText("")
    end
    U.profileButton:SetText(L(profile.name) .. (s.autoProfile and (" · " .. L("auto")) or ""))
    if U.profileMenu:IsShown() then U.renderProfileMenu() end
    local className = UnitClass("player")
    U.character:SetText(("%s · %s"):format(className or "", (L("Level %d")):format(player.level)))
    U.sideFoot:SetText("GearPilot " .. tostring(GP.version or ""))
    U.rangeChip.label:SetText((L("Level %d · range %d–%d")):format(player.level, low, high))
    U.rangeChip.dot:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
    local dLow, dHigh = GP.DungeonRange()
    U.dungeonChip.label:SetText((L("Dungeons %d–%d")):format(dLow, dHigh))
    U.dungeonChip.dot:SetVertexColor(.53, .66, .86)
    local build = GP.Sources.BuildDate()
    if not build and GP.Sources.state == "unknown" then GP.Sources.Database(); build = GP.Sources.BuildDate() end
    U.dataChip.label:SetText(build and ("ForeverDB " .. build:sub(9, 10) .. "." .. build:sub(6, 7) .. ".") or L("ForeverDB missing"))
    if build then U.dataChip.dot:SetVertexColor(C.green[1], C.green[2], C.green[3]) else U.dataChip.dot:SetVertexColor(C.red[1], C.red[2], C.red[3]) end
    U.footer:SetText(L("Provisional weights · weapon DPS counts, random proc effects do not · data: ForeverDB, AllTheThings"))

    for _, c in pairs(U.controls) do c:Hide() end
    for _, t in ipairs(pageLines) do t:Hide() end
    local rows = barRows(page)
    local top = TOP + (rows > 0 and (rows * 36 + 20) or 0)
    local listW = listWidth()
    U.listPanel:ClearAllPoints()
    U.listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -top)
    U.listPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, BOTTOM)
    U.listPanel:SetWidth(listW)
    U.pageContent:SetWidth(frame:GetWidth() - 36 - 32)
    U.footer:SetWidth(frame:GetWidth() - 36)
    if page == "settings" or page == "help" then
        U.listPanel:Hide()
        U.detailPanel:Hide()
        U.page:Show()
        if page == "settings" then renderSettings() else renderHelp() end
        return
    end
    U.page:Hide()
    U.listPanel:Show()
    U.detailPanel:Show()

    local equipped = GP.ReadGear()
    local list, loading, states, kind = pageData(page, s, low, high, equipped, profile, player)
    if page == "quests" and GP.questSummary then U.pageSub:SetText(L(titles[page][2]) .. "  ·  " .. GP.questSummary) end
    if page == "route" and GP.routeSummary then U.pageSub:SetText(GP.routeSummary) end
    if page == "wishlist" then
        if kind == "bis" then
            U.pageSub:SetText(L("Best in slot calculated by GearPilot with your profile (not an official list)"))
        elseif GP.wishSummary then
            U.pageSub:SetText(L(titles[page][2]) .. "  ·  " .. GP.wishSummary)
        end
    end
    GP.view = kind
    local selectKey = page .. kind

    -- List
    local width = listW - 32
    U.listContent:SetWidth(width)
    local selected = GP.selected[selectKey]
    local found
    for _, data in ipairs(list) do
        if (data.key or data.entry.key) == selected then found = data end
    end
    if not found then
        found = list[1]
        GP.selected[selectKey] = found and (found.key or found.entry.key) or nil
    end
    -- 1.6.2: only the visible rows exist (plus one); scrolling fills them with the entries now in view. Long lists
    -- used to build one row per entry (hundreds of frames).
    U.listState = { list = list, kind = kind, found = found, width = width }
    U.listContent:SetHeight(math.max(10, #list * 46))
    if (U.listScroll:GetVerticalScroll() or 0) > math.max(0, #list * 46 - (U.listScroll:GetHeight() or 0)) then
        U.listScroll:SetVerticalScroll(0)
    end
    drawRows()
    U.empty:SetWidth(listW - 28)
    if #list == 0 then
        U.empty:SetText(emptyMessage(page, kind, loading, states))
        U.empty:Show()
    else
        U.empty:Hide()
    end
    for _, b in ipairs(U.nav) do
        if b.key == page and page ~= "gear" and #list > 0 then b.badge:SetText(tostring(#list)) end
    end

    -- Detail
    U.detail:SetWidth(math.max(200, frame:GetWidth() - 36 - listW - 10 - 32))
    resetDetail()
    if not found then
        U.detailIcon:SetTexture(nil)
        U.detailName:SetText("")
        U.detailSub:SetText("")
        detailY = 12
        detailLine("GameFontDisableSmall", loading and L("Loading item data …") or L("Select an item for details."), C.muted)
    elseif kind == "gear" then
        showGear(found, profile)
    elseif kind == "weapons" then
        showWeapons(found, profile)
    elseif kind == "wish" or kind == "bis" then
        showWish(found, profile)
    elseif kind == "zone" then
        showZone(found)
    elseif kind == "dungeon" then
        showDungeon(found, profile, equipped)
    elseif kind == "clutter" then
        showClutter(found, list.total)
    elseif kind == "route" then
        showRouteTask(found, profile, equipped)
    elseif kind == "classquest" then
        showClassChain(found)
    elseif kind == "routepick" then
        showPick(found)
    elseif kind == "questlog" then
        showLogQuest(found)
    elseif kind == "questlater" then
        showLater(found)
    elseif kind == "routeskip" then
        showSkipped(found)
    else
        showUpgrade(found, profile)
    end
    U.detail:SetHeight(detailY + 16)
end

local scheduled = false
function GP.ScheduleRefresh(delay)
    if scheduled or not frame:IsShown() then return end
    scheduled = true
    C_Timer.After(delay or 0.2, function()
        scheduled = false
        GP.Render()
    end)
end

local restored = false
function GP.Open(page)
    if not restored then restored = true; GP.RestoreWindow() end
    if page then GP.settings.page = page end
    U.profileMenu:Hide()
    frame:Show()
    GP.Render()
end

function GP.Toggle()
    if frame:IsShown() then frame:Hide() else GP.Open() end
end

-- 1.6.2: after two minutes with the window closed, the big lists are let go (item rows, dungeon catalog, BIS): a few MB less while you play. Opening the window builds them again (a fraction of a second).
local closedAt = 0
function GP.ReleaseCaches()
    GP.Sources.rows, GP.Sources.signature = nil, nil
    GP.catalogList, GP.catalogByName, GP.catalogRows = nil, nil, nil
    GP.craftedRows, GP.equipIndex = nil, nil
    bisCache = {}
    U.listState = nil
    -- The stat cache stays: building it again means reading thousands of item tooltips (1.7.1).
    -- The route keeps its own rewards built from those rows: let them go too (built again on its next update).
    GP.QuestRoute.own = nil
    GP.QuestRoute.Invalidate()
end
frame:SetScript("OnHide", function()
    U.profileMenu:Hide(); U.slotMenu:Hide(); GP.chainOpen = {}
    local at = (GetTime and GetTime()) or 0
    closedAt = at
    if C_Timer then
        C_Timer.After(120, function()
            if not frame:IsShown() and closedAt == at then GP.ReleaseCaches() end
        end)
    end
end)
frame:SetScript("OnSizeChanged", function() if GP.ScheduleRefresh then GP.ScheduleRefresh() end end)
-- Saved position and size.
function GP.RestoreWindow()
    local saved = GP.settings and GP.settings.window
    if type(saved) ~= "table" or not saved.point then return end
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, UIParent, saved.relative or saved.point, saved.x or 0, saved.y or 0)
    if saved.w and saved.h then frame:SetSize(math.max(W, saved.w), math.max(H, saved.h)) end
end
