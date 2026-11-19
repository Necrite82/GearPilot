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
local function signed(v) return (v >= 0 and "+" or "−") .. number(math.abs(v)) end
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
frame:EnableMouse(true)
frame:Hide()
tinsert(UISpecialFrames, "GearPilotProWindow")

local function startMove() frame:StartMoving() end
local function stopMove() frame:StopMovingOrSizing() end
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
local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -12)
local line = frame:CreateTexture(nil, "ARTWORK")
line:SetHeight(1)
line:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -94)
line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -94)
line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

-- Header chips: level window and data status. A click opens the settings.
local function chip(width)
    local b = CreateFrame("Button", nil, header, "BackdropTemplate")
    S.Round(b, true)
    b:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1)
    b:SetFrameLevel(header:GetFrameLevel() + 5)
    b:RegisterForClicks("LeftButtonUp")
    b:SetSize(width, 22)
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetSize(7, 7)
    b.dot:SetPoint("LEFT", b, "LEFT", 9, 0)
    b.dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    b.label = S.Text(b, "GameFontHighlightSmall", 21, 5, width - 28)
    b.label:SetWordWrap(false)
    b:SetScript("OnClick", function() GP.Open("settings") end)
    return b
end
U.dataChip = chip(130)
U.dataChip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, -30)
U.rangeChip = chip(184)
U.rangeChip:SetPoint("RIGHT", U.dataChip, "LEFT", -8, 0)
tooltip(U.rangeChip, function() return L("Level range") end, function()
    return { L("Quests and dungeons in this range are compared. Bag items are always compared."), L("Click: settings") }
end)
tooltip(U.dataChip, "ForeverDB", function()
    local build = GP.Sources.BuildDate()
    if build then return { L("Quest rewards and dungeon drops from ForeverDB (GPL-3.0)."), L("Data from ") .. build, L("Click: settings") } end
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
    bags = "Interface\\Icons\\INV_Misc_Bag_08", gear = "Interface\\Icons\\INV_Chest_Cloth_17",
    settings = "Interface\\Icons\\INV_Misc_Gear_01", help = "Interface\\Icons\\INV_Misc_QuestionMark",
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
    { key = "upgrades", label = L("Best upgrades") }, { key = "quests", label = L("Quests") },
    { key = "dungeons", label = L("Dungeons") }, { key = "shop", label = L("Buy & craft") },
    { key = "bags", label = L("Bags") }, { key = "gear", label = L("Equipped gear") },
}
for i, page in ipairs(mainPages) do
    navButton(page.key, page.label):SetPoint("TOPLEFT", side, "TOPLEFT", 8, -124 - (i - 1) * 36)
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
U.detailIconHover = CreateFrame("Frame", nil, U.detail)
U.detailIconHover:SetAllPoints(U.detailIcon)
U.detailIconHover:EnableMouse(true)
U.detailIconHover:SetScript("OnEnter", function(self)
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

-- Filter bar above the list: one or two rows of segment groups, depending on the page.
U.bar = CreateFrame("Frame", nil, frame)
U.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -TOP)
U.bar:SetHeight(64)
U.bar.groups = {}
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
local function segmentGroup(page, rowIndex, x, label, width, options, field, default)
    local holder = CreateFrame("Frame", nil, U.bar)
    holder:SetPoint("TOPLEFT", U.bar, "TOPLEFT", x, -(rowIndex - 1) * 34)
    holder:SetSize(10, 28)
    local caption = S.Text(holder, "GameFontDisableSmall", 0, 8, 0, L(label))
    caption:SetWidth(0)
    local captionWidth = math.max(56, math.floor((caption:GetStringWidth() or 56) + 10))
    local group = S.Surface(holder, "raised")
    group:SetPoint("TOPLEFT", holder, "TOPLEFT", captionWidth, 0)
    group:SetSize(#options * width + 6, 28)
    holder.page, holder.row, holder.buttons = page, rowIndex, {}
    for i, option in ipairs(options) do
        local b = S.Button(group, width - 2, 22, L(option[2]), function()
            setSetting(field, option[1])
            GP.Render()
        end)
        b:SetPoint("TOPLEFT", group, "TOPLEFT", 4 + (i - 1) * width, -3)
        b.field, b.value, b.default = field, option[1], default
        holder.buttons[#holder.buttons + 1] = b
    end
    U.bar.groups[#U.bar.groups + 1] = holder
    return x + captionWidth + #options * width + 24
end
local x = segmentGroup("quests", 1, 0, "View", 96, { { "items", "Items" }, { "zones", "Zones" } }, "views.quests", "items")
segmentGroup("quests", 1, x, "Sort", 82, { { "gain", "Score" }, { "distance", "Distance" }, { "zone", "Zone" } }, "questSort", "gain")
segmentGroup("quests", 2, 0, "Dungeon quests", 82, { { "show", "Show" }, { "hide", "Hide" }, { "only", "Only" } }, "dungeonQuests", "show")
segmentGroup("dungeons", 1, 0, "View", 110, { { "items", "Items" }, { "overview", "Per dungeon" } }, "views.dungeons", "items")
segmentGroup("shop", 1, 0, "Source", 104, { { "all", "All" }, { "Vendors", "Vendors" }, { "Auction", "Auction house" }, { "Crafted", "Crafting" } }, "shopSource", "all")
segmentGroup("bags", 1, 0, "View", 110, { { "upgrades", "Upgrades" }, { "clutter", "Can go" } }, "views.bags", "upgrades")
local function barRows(page)
    local rows = 0
    for _, holder in ipairs(U.bar.groups) do
        local on = holder.page == page
        holder:SetShown(on)
        if on then
            rows = math.max(rows, holder.row)
            for _, b in ipairs(holder.buttons) do S.Segment(b, (setting(b.field) or b.default) == b.value) end
        end
    end
    U.bar:SetShown(rows > 0)
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
local function row(i)
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
local function section(title)
    detailY = detailY + 8
    detailLine("GameFontNormal", title, C.gold)
end
local function actions(first, second)
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
    detailY = detailY + 34
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
        d.points = d.delta * (profile and profile[d.key] or 0)
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

local function resetDetail()
    for _, t in ipairs(U.lines) do t:Hide() end
    U.lines.used = {}
    S.HideMetrics(U.detail)
    U.action:Hide()
    U.action2:Hide()
    hideBars()
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
local function sourceLine(entry)
    local row = entry.row
    if entry.source == "Bags" then return L("In your bags") end
    if entry.source == "Quests" then
        local kind = row.dungeonQuest and ("|cffd9a35a" .. L("Dungeon quest") .. "|r") or L("Quest")
        local distance = entry.distance and (" · " .. (L("%d yd")):format(entry.distance)) or ""
        if GP.settings.questSort == "zone" and row.zone then distance = " · " .. row.zone end
        return ("%s · %s%s"):format(kind, (L("Level %d")):format(entry.level), distance)
    end
    if entry.source == "Vendors" then return L("Vendor: ") .. (row.name or "?") end
    if entry.source == "Auction" then return L("Auction house") .. " · " .. money(row.price) end
    if entry.source == "Crafted" then
        return L(professionNames[row.profession] or row.profession) .. (row.learn and (" " .. row.learn) or "")
    end
    local chance = row and row.chance and (" · %d %%"):format(math.floor(row.chance * 100 + .5)) or ""
    return ("%s%s"):format(GP.Sources.DungeonName(row), chance)
end

-- Reads the sources; returns entries, loading flag and the states (missing, nocraftpilot, noauction).
local function collect(sources, low, high)
    local all, loading, states = {}, false, {}
    for _, source in ipairs(sources) do
        local entries, isLoading, state = GP.ReadCandidates(source, low, high)
        loading = loading or isLoading
        states[state] = true
        for _, entry in ipairs(entries) do all[#all + 1] = entry end
    end
    return all, loading, states
end
local function recommend(sources, low, high, equipped, profile, player)
    local candidates, loading, states = collect(sources, low, high)
    local s = GP.settings
    return P.Recommend(candidates, equipped, { level = player.level, below = s.below, above = s.above, profile = profile,
        class = player.class }), loading, states
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
local function showHead(icon, name, sub, link)
    U.detailIcon:SetTexture(icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    U.detailName:SetText(name or "")
    U.detailSub:SetText(sub or "")
    U.detailLink = link
    local width = (U.detail:GetWidth() or 300) - 72
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
    return "  |cff9dabb8" .. signed(gain / base * 100) .. " %|r"
end

local function questBlock(row)
    detailLine("GameFontHighlight", GP.Sources.QuestTitle(row.sourceID, row.name))
    detailLine("GameFontHighlightSmall", (L("Quest level %d"):format(row.level))
        .. (row.minLevel and row.minLevel > 0 and (" · " .. L("from level %d"):format(row.minLevel)) or ""))
    if row.giver then detailLine("GameFontHighlightSmall", L("Quest giver: ") .. row.giver .. (row.zone and (", " .. row.zone) or "")) end
    if row.dungeonQuest then
        detailLine("GameFontHighlightSmall", "|cffd9a35a" .. L("Dungeon quest: ") .. row.dungeonQuest .. "|r")
    end
    if row.choiceGroup then
        detailLine("GameFontDisableSmall", L("Choice reward: you get one item of this quest. GearPilot shows the best one for you."), C.muted)
    end
    local chain = GP.Route.Chain(row.sourceID)
    actions({ L("Waypoint to quest giver"), function() GP.Route.ToGiver(row.sourceID) end },
        #chain > 1 and { (L("Whole chain (%d)")):format(#chain), function() GP.Route.ToChain(row.sourceID) end } or nil)
    if #chain > 1 then
        section(L("Quest chain"))
        for i, step in ipairs(chain) do
            local mark = step.done and "|cff85d6a0✓|r" or step.active and "|cffe0b050▶|r" or "|cff9dabb8•|r"
            local where = (step.giver or "?") .. (step.zone and (", " .. step.zone) or "")
            detailLine("GameFontHighlightSmall", ("%s %d. %s"):format(mark, i, step.title), step.id == row.sourceID and C.gold or C.text, 4)
            detailLine("GameFontDisableSmall", where, C.muted, 22)
        end
    end
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
    showItemHead(item, ("%s · %s"):format(L(P.slotNames[result.slot] or ""), sourceLine(entry)))
    local width = (U.detail:GetWidth() or 300) - 24
    local replaced = result.current and result.current.name or L("Empty slot")
    if result.second and result.second.name then replaced = replaced .. " + " .. result.second.name end
    local third
    if entry.source == "Dungeons" then
        third = { label = L("Drop chance"), value = row.chance and (("%d %%"):format(math.floor(row.chance * 100 + .5))) or L("unknown") }
    elseif entry.source == "Auction" then
        third = { label = L("Auction price"), value = money(row.price), color = C.text }
    else
        third = { label = L("Required level"), value = tostring(item.minLevel or "?") }
    end
    S.Metrics(U.detail, {
        { label = L("Score gain"), value = signed(result.gain) .. percentText(result.gain, result.score - result.gain),
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
    elseif entry.source == "Crafted" then
        craftedBlock(row)
    else
        detailLine("GameFontHighlight", GP.Sources.DungeonName(row) .. (row.raid and (" (" .. L("raid") .. ")") or ""))
        if row.boss then detailLine("GameFontHighlightSmall", L("Drops from: ") .. row.boss) end
        detailLine("GameFontHighlightSmall", row.chance and (L("Drop chance about %d %%"):format(math.floor(row.chance * 100 + .5)))
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
            local weight = profile[key]
            detailLine("GameFontHighlightSmall", ("%s  %s%s"):format(number(v), L(St.names[key]),
                weight and ("  |cff9dabb8× " .. number(weight) .. "|r") or "  |cff9dabb8" .. L("(not weighted)") .. "|r"), C.text, 4)
        end
    end
    if not any then detailLine("GameFontDisableSmall", L("No readable values."), C.muted) end
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
    actions({ (L("Waypoints to all quest givers (%d)")):format(#ids), function() GP.Route.ToMany(ids) end, 260 })
    section(L("Quests in this zone"))
    for _, result in ipairs(zone.results) do
        local row = result.entry.row
        detailLine("GameFontHighlightSmall", ("%s%s|r  |cff85d6a0%s|r"):format(S.QualityColor(result.item.quality), result.item.name, signed(result.gain)), C.text, 4)
        detailLine("GameFontDisableSmall", GP.Sources.QuestTitle(row.sourceID, row.name) .. " · " .. (L("Level %d")):format(row.level)
            .. (row.dungeonQuest and (" · " .. L("Dungeon quest")) or ""), C.muted, 22)
    end
end

local function showDungeon(dungeon)
    local row = dungeon.row
    showHead("Interface\\Icons\\INV_Misc_Head_Dragon_01", GP.Sources.DungeonName(row) .. (row.raid and (" (" .. L("raid") .. ")") or ""),
        (L("Level %d–%d"):format(dungeon.low, dungeon.high)))
    local width = (U.detail:GetWidth() or 300) - 24
    S.Metrics(U.detail, {
        { label = L("Expected per run"), value = "≈ " .. signed(dungeon.expected), color = C.green, emphasis = true },
        { label = L("Upgrades"), value = tostring(#dungeon.results), color = C.text },
        { label = L("Dungeon quests"), value = tostring(#dungeon.quests), color = C.text },
    }, 12, detailY, width)
    detailY = detailY + 60
    if dungeon.unknown > 0 then
        detailLine("GameFontDisableSmall", (L("%d drop chances are unknown and count as %d %%."):format(dungeon.unknown, P.UNKNOWN_CHANCE * 100)), C.muted)
    end
    -- Items by boss.
    local bosses, order = {}, {}
    for _, result in ipairs(dungeon.results) do
        local boss = result.entry.row.boss or L("Unknown")
        if not bosses[boss] then bosses[boss] = {}; order[#order + 1] = boss end
        table.insert(bosses[boss], result)
    end
    for _, boss in ipairs(order) do
        section(boss)
        for _, result in ipairs(bosses[boss]) do
            local chance = result.entry.row.chance
            detailLine("GameFontHighlightSmall", ("%s%s|r  |cff85d6a0%s|r  |cff9dabb8%s|r"):format(S.QualityColor(result.item.quality),
                result.item.name, signed(result.gain), chance and ("%d %%"):format(math.floor(chance * 100 + .5)) or "?"), C.text, 4)
        end
    end
    if #dungeon.quests > 0 then
        section(L("Dungeon quests"))
        local ids = {}
        for _, result in ipairs(dungeon.quests) do
            local qrow = result.entry.row
            ids[#ids + 1] = qrow.sourceID
            detailLine("GameFontHighlightSmall", ("%s%s|r  |cff85d6a0%s|r"):format(S.QualityColor(result.item.quality), result.item.name, signed(result.gain)), C.text, 4)
            detailLine("GameFontDisableSmall", GP.Sources.QuestTitle(qrow.sourceID, qrow.name) .. (qrow.giver and (" · " .. qrow.giver) or ""), C.muted, 22)
        end
        actions({ (L("Waypoints to the quest givers (%d)")):format(#ids), function() GP.Route.ToMany(ids) end, 250 })
    end
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
    local width = W - 36 - 32 - 16
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
    text("GameFontHighlightSmall", L("Quests and dungeons from this many levels below to this many levels above your level are compared."))
    local function stepper(key, label, field, xx)
        n = n + 1
        pageText(n, "GameFontHighlightSmall", xx, y + 6, 120, label)
        local minus = control(key .. "-", 26, "−", function() s[field] = math.max(0, s[field] - 1); GP.Render() end)
        minus:ClearAllPoints()
        minus:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", xx + 124, -y)
        n = n + 1
        pageText(n, "GameFontHighlight", xx + 154, y + 6, 30, tostring(s[field]), C.gold, "CENTER")
        local plus = control(key .. "+", 26, "+", function() s[field] = math.min(10, s[field] + 1); GP.Render() end)
        plus:ClearAllPoints()
        plus:SetPoint("TOPLEFT", U.pageContent, "TOPLEFT", xx + 188, -y)
    end
    stepper("below", L("Levels below"), "below", 16)
    stepper("above", L("Levels above"), "above", 260)
    y = y + 44

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

    text("GameFontNormal", L("Addons"), C.gold)
    local build = GP.Sources.BuildDate()
    text("GameFontHighlightSmall", "ForeverDB: " .. (build and (L("installed, data from ") .. build) or L("missing (quests, dungeons and vendors need it)")))
    text("GameFontHighlightSmall", "Auctionator: " .. (GP.HasAuctionPrices() and L("prices available") or L("not installed")))
    text("GameFontHighlightSmall", "CraftPilot: " .. (GP.CraftPilot() and L("recipe catalog available") or L("not installed")))
    text("GameFontHighlightSmall", "TomTom: " .. ((type(TomTom) == "table") and L("arrows for every waypoint") or L("not installed (the game's map waypoint is used)")))
    U.pageContent:SetHeight(y + 16)
end

local function renderHelp()
    local width = W - 36 - 32 - 16
    local y, n = 16, 0
    local function text(font, value, c)
        n = n + 1
        local t = pageText(n, font, 16, y, width, value, c)
        y = y + math.max(16, t:GetStringHeight() or 16) + 8
    end
    text("GameFontNormal", L("How GearPilot works"), C.gold)
    text("GameFontHighlightSmall", L("GearPilot scores every item with the values of your stat profile and compares it with what you wear in the same slot. The score gain is the difference."))
    text("GameFontHighlightSmall", L("Best upgrades lists bag items, quest rewards and dungeon drops together. Quests and dungeons only count inside your level range; quests you have done are hidden."))
    text("GameFontHighlightSmall", L("Quest choice rewards: you can take one item per quest, so only the best one is shown."))
    text("GameFontNormal", L("Views"), C.gold)
    text("GameFontHighlightSmall", L("Quests by zone: where questing pays most, with waypoints to every quest giver. Dungeons per dungeon: the expected gain of one run (score gain times drop chance) plus the dungeon quests."))
    text("GameFontHighlightSmall", L("Buy & craft: vendor gear, the auction house (Auctionator prices) and recipes from CraftPilot. Bags: upgrades, and gear that can go."))
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
    shop = { "Buy & craft", "Vendors, auction house and crafting" },
    bags = { "Bags", "Items in your bags that beat what you wear" },
    gear = { "Equipped gear", "Your equipment and its score" },
    settings = { "Settings", "Level range, stat profile, sources and helpers" },
    help = { "Help", "How GearPilot works" },
}

-- What the list of a page shows: kind and data.
local function pageData(page, s, low, high, equipped, profile, player)
    if page == "gear" then return gearRows(equipped, profile), false, {}, "gear" end
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
    if page == "dungeons" then
        local list, loading, states = recommend({ "Dungeons" }, low, high, equipped, profile, player)
        if (s.views.dungeons or "items") == "overview" then
            local quests = recommend({ "Quests" }, low, high, equipped, profile, player)
            return P.ByDungeon(list, quests), loading, states, "dungeon"
        end
        return list, loading, states, "upgrade"
    end
    if page == "shop" then
        local sources = s.shopSource == "all" and { "Vendors", "Auction", "Crafted" } or { s.shopSource }
        local list, loading, states = recommend(sources, low, high, equipped, profile, player)
        return list, loading, states, "upgrade"
    end
    -- bags
    if (s.views.bags or "upgrades") == "clutter" then
        local entries, loading = collect({ "Bags" }, low, high)
        local list = P.Clutter(entries, equipped, profile, player.class, player.level, GP.Reserved())
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
    if page == "shop" and (states.noauction or states.nocraftpilot) then
        return L("No upgrades here. The auction house needs Auctionator with a scan, crafting needs CraftPilot.")
    end
    if kind == "clutter" then return L("Nothing to get rid of: all gear in your bags is useful.") end
    return L("No upgrades in this selection. Try a wider level range in the settings.")
end

local function fillRow(r, kind, data, width, list)
    local item = data.item
    r.link = item and item.link
    r.name:SetWidth(width - 120)
    r.sub:SetWidth(width - 120)
    if kind == "gear" then
        r.icon:SetTexture(item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        r.name:SetText(item and (S.QualityColor(item.quality) .. (item.name or L("Loading item data …")) .. "|r")
            or ("|cff9dabb8" .. L("Empty slot") .. "|r"))
        r.sub:SetText(L(P.slotNames[data.slot] or ""))
        r.value:SetText(data.score and number(data.score) or "")
        color(r.value, C.gold)
    elseif kind == "zone" then
        r.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
        r.name:SetText(data.zone)
        r.sub:SetText((L("%d quest upgrades"):format(#data.results)))
        r.value:SetText(signed(data.gain))
        color(r.value, C.green)
    elseif kind == "dungeon" then
        r.icon:SetTexture("Interface\\Icons\\INV_Misc_Head_Dragon_01")
        r.name:SetText(GP.Sources.DungeonName(data.row))
        r.sub:SetText((L("Level %d–%d"):format(data.low, data.high)) .. " · " .. (L("%d upgrades"):format(#data.results))
            .. (#data.quests > 0 and (" · " .. (L("%d quests"):format(#data.quests))) or ""))
        r.value:SetText("≈ " .. signed(data.expected))
        color(r.value, C.green)
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
        r.sub:SetText(L(P.slotNames[data.slot] or "") .. " · " .. sourceLine(data.entry))
        r.value:SetText(signed(data.gain))
        color(r.value, C.green)
    end
end

function GP.Render()
    if not frame:IsShown() or not GP.settings then return end
    local s = GP.settings
    local page = s.page
    local player = GP.Player()
    local profile = GP.ActiveProfile()
    local low, high = P.Range(player.level, s.below, s.above)
    U.pageTitle:SetText(L(titles[page][1]))
    U.pageSub:SetText(L(titles[page][2]))
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
    local build = GP.Sources.BuildDate()
    if not build and GP.Sources.state == "unknown" then GP.Sources.Database(); build = GP.Sources.BuildDate() end
    U.dataChip.label:SetText(build and ("ForeverDB " .. build:sub(9, 10) .. "." .. build:sub(6, 7) .. ".") or L("ForeverDB missing"))
    if build then U.dataChip.dot:SetVertexColor(C.green[1], C.green[2], C.green[3]) else U.dataChip.dot:SetVertexColor(C.red[1], C.red[2], C.red[3]) end
    U.footer:SetText(L("Provisional weights · weapon DPS counts, random proc effects do not · data: ForeverDB"))

    for _, c in pairs(U.controls) do c:Hide() end
    for _, t in ipairs(pageLines) do t:Hide() end
    local rows = barRows(page)
    local top = TOP + rows * 34 + (rows > 0 and 4 or 0)
    U.listPanel:ClearAllPoints()
    U.listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -top)
    U.listPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, BOTTOM)
    U.listPanel:SetWidth(LIST)
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
    GP.view = kind
    local selectKey = page .. kind

    -- List
    local width = (U.listScroll:GetWidth() or (LIST - 32))
    if width <= 0 then width = LIST - 32 end
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
    for _, r in ipairs(U.rows) do r:Hide() end
    for i, data in ipairs(list) do
        local r = row(i)
        r.key = data.key or data.entry.key
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", U.listContent, "TOPLEFT", 0, -(i - 1) * 46)
        r:SetWidth(width)
        local on = data == found
        if on then r:SetBackdropColor(.16, .18, .22, 1) else r:SetBackdropColor(0, 0, 0, 0) end
        r.stripe:SetShown(on)
        fillRow(r, kind, data, width, list)
        r:Show()
    end
    U.listContent:SetHeight(math.max(10, #list * 46))
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
    U.detail:SetWidth(math.max(200, (U.detailScroll:GetWidth() or (W - LIST - 82))))
    resetDetail()
    if not found then
        U.detailIcon:SetTexture(nil)
        U.detailName:SetText("")
        U.detailSub:SetText("")
        detailY = 12
        detailLine("GameFontDisableSmall", loading and L("Loading item data …") or L("Select an item for details."), C.muted)
    elseif kind == "gear" then
        showGear(found, profile)
    elseif kind == "zone" then
        showZone(found)
    elseif kind == "dungeon" then
        showDungeon(found)
    elseif kind == "clutter" then
        showClutter(found, list.total)
    else
        showUpgrade(found, profile)
    end
    U.detail:SetHeight(detailY + 16)
end

local scheduled = false
function GP.ScheduleRefresh()
    if scheduled or not frame:IsShown() then return end
    scheduled = true
    C_Timer.After(0.2, function()
        scheduled = false
        GP.Render()
    end)
end

function GP.Open(page)
    if page then GP.settings.page = page end
    U.profileMenu:Hide()
    frame:Show()
    GP.Render()
end

function GP.Toggle()
    if frame:IsShown() then frame:Hide() else GP.Open() end
end

frame:SetScript("OnHide", function() U.profileMenu:Hide() end)
