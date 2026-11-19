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
logo:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
logo:SetTexCoord(.08, .92, .08, .92)
S.Text(side, "GameFontNormalLarge", 52, 14, SIDE - 60, "GearPilot")
S.Text(side, "GameFontDisableSmall", 52, 33, SIDE - 60, L("Gear companion"))

-- Profile menu, like CraftPilot's profession menu.
U.profileButton = S.Button(side, SIDE - 16, 30, "", function()
    U.profileMenu:SetShown(not U.profileMenu:IsShown())
end)
U.profileButton:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -54)
tooltip(U.profileButton, function() return L("Stat profile") end, function()
    return { L("Which values count. Provisional weights; weapon DPS is included, random proc effects are not.") }
end)
U.character = S.Text(side, "GameFontDisableSmall", 14, 90, SIDE - 28)
U.profileMenu = S.Surface(frame, "raised")
U.profileMenu:SetFrameStrata("DIALOG")
U.profileMenu:SetPoint("TOPLEFT", U.profileButton, "TOPRIGHT", 6, 0)
U.profileMenu:SetSize(214, 16 + #P.profiles * 30)
U.profileMenu:Hide()
for i, profile in ipairs(P.profiles) do
    local b = S.Button(U.profileMenu, 198, 26, L(profile.name), function()
        GP.settings.profile = profile.key
        U.profileMenu:Hide()
        GP.Render()
    end)
    b:SetPoint("TOPLEFT", U.profileMenu, "TOPLEFT", 8, -8 - (i - 1) * 30)
    b.profile = profile.key
    U.profileItems[i] = b
end

local navIcons = {
    upgrades = "Interface\\Icons\\INV_Sword_04", quests = "Interface\\Icons\\INV_Misc_Note_01",
    dungeons = "Interface\\Icons\\INV_Misc_Head_Dragon_01", bags = "Interface\\Icons\\INV_Misc_Bag_08",
    gear = "Interface\\Icons\\INV_Chest_Cloth_17", settings = "Interface\\Icons\\INV_Misc_Gear_01",
    help = "Interface\\Icons\\INV_Misc_QuestionMark",
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
    { key = "dungeons", label = L("Dungeons") }, { key = "bags", label = L("Bags") },
    { key = "gear", label = L("Equipped gear") },
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

-- Filter bar above the quest list: sort order and dungeon quests.
U.bar = CreateFrame("Frame", nil, frame)
U.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -TOP)
U.bar:SetHeight(28)
U.bar.segments = {}
local function segmentGroup(x, label, width, options, field)
    local caption = S.Text(U.bar, "GameFontDisableSmall", x, 8, 0, L(label))
    caption:SetWidth(0)
    local group = S.Surface(U.bar, "raised")
    local captionWidth = math.max(60, math.floor((caption:GetStringWidth() or 60) + 10))
    group:SetPoint("TOPLEFT", U.bar, "TOPLEFT", x + captionWidth, 0)
    group:SetSize(#options * width + 6, 28)
    for i, option in ipairs(options) do
        local b = S.Button(group, width - 2, 22, L(option[2]), function()
            GP.settings[field] = option[1]
            GP.Render()
        end)
        b:SetPoint("TOPLEFT", group, "TOPLEFT", 4 + (i - 1) * width, -3)
        b.field, b.value = field, option[1]
        U.bar.segments[#U.bar.segments + 1] = b
    end
    return x + captionWidth + #options * width + 24
end
local barX = segmentGroup(0, "Sort", 82, { { "gain", "Score" }, { "distance", "Distance" }, { "zone", "Zone" } }, "questSort")
segmentGroup(barX, "Dungeon quests", 82, { { "show", "Show" }, { "hide", "Hide" }, { "only", "Only" } }, "dungeonQuests")

-- Full-width surface for settings and help.
U.page = S.Surface(frame, "panel")
U.page:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -TOP)
U.page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, BOTTOM)
U.page:Hide()

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
    r.value = S.Text(r, "GameFontHighlight", 0, 14, 60, "", "RIGHT")
    r.value:ClearAllPoints()
    r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -14)
    r:SetScript("OnClick", function(self)
        GP.selected[GP.settings.page] = self.key
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
local function resetDetail()
    for _, t in ipairs(U.lines) do t:Hide() end
    U.lines.used = {}
    S.HideMetrics(U.detail)
    U.action:Hide()
    U.action2:Hide()
    if U.hideBars then U.hideBars() end
    U.detailLink = nil
    detailY = 0
end

-- Data ------------------------------------------------------------------------------------------------------------
GP.selected = {}
local sourceLabels = { Bags = "Bags", Quests = "Quest", Dungeons = "Dungeon" }
local function sourceLine(entry)
    local row = entry.row
    if entry.source == "Bags" then return L("In your bags") end
    if entry.source == "Quests" then
        local kind = row.dungeonQuest and ("|cffd9a35a" .. L("Dungeon quest") .. "|r") or L("Quest")
        local distance = entry.distance and (" · " .. (L("%d yd")):format(entry.distance)) or ""
        if GP.settings.questSort == "zone" and row.zone then distance = " · " .. row.zone end
        return ("%s · %s%s"):format(kind, (L("Level %d")):format(entry.level), distance)
    end
    local chance = row and row.chance and (" · %d %%"):format(math.floor(row.chance * 100 + .5)) or ""
    return ("%s%s"):format(GP.Sources.DungeonName(row), chance)
end

local function collect(page, low, high)
    local sources = page == "upgrades" and { "Bags", "Quests", "Dungeons" }
        or { page == "quests" and "Quests" or page == "dungeons" and "Dungeons" or "Bags" }
    local all, loading, missing = {}, false, false
    for _, source in ipairs(sources) do
        local entries, isLoading, state = GP.ReadCandidates(source, low, high)
        loading = loading or isLoading
        missing = missing or state == "missing"
        for _, entry in ipairs(entries) do all[#all + 1] = entry end
    end
    return all, loading, missing
end

local function gearRows(equipped, profile)
    local list = {}
    for _, slot in ipairs(P.slots) do
        local item = equipped[slot[1]]
        list[#list + 1] = { key = "slot" .. slot[1], slot = slot[1], item = item, score = item and P.Score(item, profile) }
    end
    return list
end

-- Detail panels -------------------------------------------------------------------------------------------------------
local function showItemHead(item, sub)
    U.detailIcon:SetTexture(item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    U.detailName:SetText(item and (S.QualityColor(item.quality) .. (item.name or "?") .. "|r") or L("No item equipped"))
    U.detailSub:SetText(sub or "")
    U.detailLink = item and item.link
    local width = (U.detail:GetWidth() or 300) - 72
    U.detailName:SetWidth(width)
    U.detailSub:SetWidth(width)
    detailY = math.max(58, 40 + (U.detailName:GetStringHeight() or 16))
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
U.hideBars = hideBars
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

local function showUpgrade(result)
    local item, entry, row = result.item, result.entry, result.entry.row
    showItemHead(item, ("%s · %s"):format(L(P.slotNames[result.slot] or ""), sourceLine(entry)))
    local width = (U.detail:GetWidth() or 300) - 24
    local replaced = result.current and result.current.name or L("Empty slot")
    if result.second and result.second.name then replaced = replaced .. " + " .. result.second.name end
    local third
    if entry.source == "Dungeons" then
        third = { label = L("Drop chance"), value = row.chance and (("%d %%"):format(math.floor(row.chance * 100 + .5))) or L("unknown") }
    else
        third = { label = L("Required level"), value = tostring(item.minLevel or "?") }
    end
    S.Metrics(U.detail, {
        { label = L("Score gain"), value = signed(result.gain) .. (result.score - result.gain > 0
            and ("  |cff9dabb8" .. signed(result.gain / (result.score - result.gain) * 100) .. " %|r") or ""), color = C.green, emphasis = true },
        { label = L("Replaces"), value = replaced, color = C.text },
        third,
    }, 12, detailY, width)
    detailY = detailY + 60
    section(L("Where to get it"))
    if entry.source == "Bags" then
        detailLine("GameFontHighlightSmall", L("Already in your bags."))
        U.action:SetText(L("Equip"))
        S.Primary(U.action)
        U.action:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            local equip = C_Item.EquipItemByName or EquipItemByName
            if equip then equip(item.link) end
        end)
        U.action:ClearAllPoints()
        U.action:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
        U.action:Show()
        detailY = detailY + 34
    elseif entry.source == "Quests" then
        detailLine("GameFontHighlight", GP.Sources.QuestTitle(row.sourceID, row.name))
        detailLine("GameFontHighlightSmall", (L("Quest level %d"):format(row.level))
            .. (row.minLevel and row.minLevel > 0 and (" · " .. L("from level %d"):format(row.minLevel)) or ""))
        if row.giver then detailLine("GameFontHighlightSmall", L("Quest giver: ") .. row.giver .. (row.zone and (", " .. row.zone) or "")) end
        if #row.prerequisites > 0 then
            local parts = {}
            for _, id in ipairs(row.prerequisites) do
                local title = GP.Sources.QuestTitle(id, ForeverDB and ForeverDB.quest[id] and ForeverDB.quest[id][1] or ("#" .. id))
                parts[#parts + 1] = (GP.Sources.QuestDone(id) and "|cff85d6a0✓ " or "|cffd9a35a• ") .. title .. "|r"
            end
            detailLine("GameFontHighlightSmall", L("Prerequisites: ") .. table.concat(parts, ", "))
        end
        if row.dungeonQuest then
            detailLine("GameFontHighlightSmall", "|cffd9a35a" .. L("Dungeon quest: ") .. row.dungeonQuest .. "|r")
        end
        if row.choiceGroup then
            detailLine("GameFontDisableSmall", L("Choice reward: you get one item of this quest. GearPilot shows the best one for you."), C.muted)
        end
        local chain = GP.Route.Chain(row.sourceID)
        detailY = detailY + 4
        U.action:SetText(L("Waypoint to quest giver"))
        S.Primary(U.action)
        U.action:SetWidth(170)
        U.action:SetScript("OnClick", function() GP.Route.ToGiver(row.sourceID) end)
        U.action:ClearAllPoints()
        U.action:SetPoint("TOPLEFT", U.detail, "TOPLEFT", 12, -detailY)
        U.action:Show()
        if #chain > 1 then
            U.action2:SetText((L("Whole chain (%d)")):format(#chain))
            U.action2:SetWidth(150)
            U.action2:SetScript("OnClick", function() GP.Route.ToChain(row.sourceID) end)
            U.action2:ClearAllPoints()
            U.action2:SetPoint("LEFT", U.action, "RIGHT", 8, 0)
            U.action2:Show()
        end
        detailY = detailY + 34
        if #chain > 1 then
            section(L("Quest chain"))
            for i, step in ipairs(chain) do
                local mark = step.done and "|cff85d6a0✓|r" or step.active and "|cffe0b050▶|r" or "|cff9dabb8•|r"
                local where = (step.giver or "?") .. (step.zone and (", " .. step.zone) or "")
                detailLine("GameFontHighlightSmall", ("%s %d. %s"):format(mark, i, step.title), step.id == row.sourceID and C.gold or C.text, 4)
                detailLine("GameFontDisableSmall", where, C.muted, 22)
            end
        end
    else
        detailLine("GameFontHighlight", GP.Sources.DungeonName(row) .. (row.raid and (" (" .. L("raid") .. ")") or ""))
        if row.boss then detailLine("GameFontHighlightSmall", L("Drops from: ") .. row.boss) end
        detailLine("GameFontHighlightSmall", row.chance and (L("Drop chance about %d %%"):format(math.floor(row.chance * 100 + .5)))
            or L("Drop chance not known yet (new in Forever or too few kills recorded)."))
    end
    section(L("Values compared"))
    statLines(P.Diff(item, result.current), P.Profile(GP.settings.profile))
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

-- Settings and help ---------------------------------------------------------------------------------------------------
local pageLines = {}
local function pageText(i, font, x, y, width, value, c, align)
    local t = pageLines[i] or S.Text(U.page, font, 0, 0, 10)
    pageLines[i] = t
    t:SetFontObject(S.Font(font))
    t:SetJustifyH(align or "LEFT")
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", U.page, "TOPLEFT", x, -y)
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
        b = S.Button(U.page, width, 26, caption, callback)
        U.controls[key] = b
    end
    b:SetText(caption)
    b:Show()
    return b
end

local function renderSettings()
    local s = GP.settings
    local width = W - 36 - 32
    local y = 16
    local n = 0
    local function text(font, value, c, x)
        n = n + 1
        local t = pageText(n, font, x or 16, y, width - (x or 0), value, c)
        y = y + math.max(16, t:GetStringHeight() or 16) + 6
        return t
    end
    text("GameFontNormal", L("Level range"), C.gold)
    text("GameFontHighlightSmall", L("Quests and dungeons from this many levels below to this many levels above your level are compared."))
    local function stepper(key, label, field, x)
        n = n + 1
        pageText(n, "GameFontHighlightSmall", x, y + 6, 120, label)
        control(key .. "-", 26, "−", function() s[field] = math.max(0, s[field] - 1); GP.Render() end)
            :SetPoint("TOPLEFT", U.page, "TOPLEFT", x + 124, -y)
        n = n + 1
        pageText(n, "GameFontHighlight", x + 154, y + 6, 30, tostring(s[field]), C.gold, "CENTER")
        control(key .. "+", 26, "+", function() s[field] = math.min(10, s[field] + 1); GP.Render() end)
            :SetPoint("TOPLEFT", U.page, "TOPLEFT", x + 188, -y)
    end
    stepper("below", L("Levels below"), "below", 16)
    stepper("above", L("Levels above"), "above", 260)
    y = y + 44
    text("GameFontNormal", L("Stat profile"), C.gold)
    text("GameFontHighlightSmall", L("Choose what your character needs. The weights are provisional and will be refined with player feedback."))
    local per = math.floor((width - 16) / 3)
    for i, profile in ipairs(P.profiles) do
        local b = control("profile" .. i, per - 8, L(profile.name), function() s.profile = profile.key; GP.Render() end)
        b:SetPoint("TOPLEFT", U.page, "TOPLEFT", 16 + ((i - 1) % 3) * per, -(y + math.floor((i - 1) / 3) * 32))
        S.Segment(b, s.profile == profile.key)
    end
    y = y + 74
    text("GameFontNormal", L("Minimum drop chance"), C.gold)
    text("GameFontHighlightSmall", L("Dungeon items below this chance are left out. Unknown chances from new Forever dungeons and bosses are always shown."))
    for i, value in ipairs({ 0.01, 0.02, 0.05, 0.1 }) do
        local b = control("chance" .. i, 80, ("%d %%"):format(value * 100), function() s.minChance = value; GP.Render() end)
        b:SetPoint("TOPLEFT", U.page, "TOPLEFT", 16 + (i - 1) * 88, -y)
        S.Segment(b, s.minChance == value)
    end
    y = y + 40
    text("GameFontNormal", L("Item tooltip"), C.gold)
    text("GameFontHighlightSmall", L("Shows in every item tooltip how much better or worse the item is than what you wear."))
    for i, option in ipairs({ { true, "On" }, { false, "Off" } }) do
        local b = control("tooltip" .. i, 80, L(option[2]), function() s.tooltip = option[1]; GP.Render() end)
        b:SetPoint("TOPLEFT", U.page, "TOPLEFT", 16 + (i - 1) * 88, -y)
        S.Segment(b, s.tooltip == option[1])
    end
    y = y + 40
    text("GameFontNormal", "ForeverDB", C.gold)
    local build = GP.Sources.BuildDate()
    text("GameFontHighlightSmall", build and (L("Installed, data from ") .. build .. ". " .. L("Quest rewards and dungeon drops come from ForeverDB (GPL-3.0, github.com/foreverfraddons/forever-db)."))
        or L("Not installed. Install ForeverDB with the CurseForge app; bag upgrades work without it."))
    return n
end

local function renderHelp()
    local width = W - 36 - 32
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
    text("GameFontNormal", L("Limits"), C.gold)
    text("GameFontHighlightSmall", L("Weights are provisional. Random proc effects and set bonuses are not scored. Items the game has not loaded yet appear a moment later."))
    text("GameFontNormal", L("Commands"), C.gold)
    text("GameFontHighlightSmall", "/gpp · /gearpilotpro")
    return n
end

-- Render ------------------------------------------------------------------------------------------------------------
local titles = {
    upgrades = { "Best upgrades", "Bags, quests and dungeons in your level range, best first" },
    quests = { "Quests", "Quest rewards that improve your gear" },
    dungeons = { "Dungeons", "Dungeon drops that improve your gear" },
    bags = { "Bags", "Items in your bags that beat what you wear" },
    gear = { "Equipped gear", "Your equipment and its score" },
    settings = { "Settings", "Level range, stat profile and data" },
    help = { "Help", "How GearPilot works" },
}

function GP.Render()
    if not frame:IsShown() or not GP.settings then return end
    local s = GP.settings
    local page = s.page
    local player = GP.Player()
    local profile = P.Profile(s.profile)
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
    U.profileButton:SetText(L(profile.name))
    for _, b in ipairs(U.profileItems) do S.Segment(b, b.profile == profile.key) end
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
    U.bar:SetShown(page == "quests")
    for _, b in ipairs(U.bar.segments) do S.Segment(b, s[b.field] == b.value) end
    local top = page == "quests" and TOP + 38 or TOP
    U.listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -top)
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
    local list, loading, missing = {}, false, false
    if page == "gear" then
        list = gearRows(equipped, profile)
    else
        local candidates
        candidates, loading, missing = collect(page, low, high)
        list = P.Recommend(candidates, equipped, {
            level = player.level, below = s.below, above = s.above, profile = profile, class = player.class,
        })
        if page == "quests" then
            for _, result in ipairs(list) do
                local row = result.entry.row
                local spot = ForeverDB and GP.Sources.Spot(ForeverDB, row.giverRef)
                local distance = GP.Sources.Distance(spot)
                result.entry.distance = distance and math.floor(distance + .5) or nil
            end
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
        end
    end

    -- List
    local width = (U.listScroll:GetWidth() or (LIST - 32))
    if width <= 0 then width = LIST - 32 end
    U.listContent:SetWidth(width)
    local selected = GP.selected[page]
    local found
    for _, data in ipairs(list) do
        if (data.key or data.entry.key) == selected then found = data end
    end
    if not found then
        found = list[1]
        GP.selected[page] = found and (found.key or found.entry.key) or nil
    end
    for _, r in ipairs(U.rows) do r:Hide() end
    for i, data in ipairs(list) do
        local r = row(i)
        local key = data.key or data.entry.key
        local item = data.item
        r.key = key
        r.link = item and item.link
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", U.listContent, "TOPLEFT", 0, -(i - 1) * 46)
        r:SetWidth(width)
        local on = data == found
        if on then r:SetBackdropColor(.16, .18, .22, 1) else r:SetBackdropColor(0, 0, 0, 0) end
        r.stripe:SetShown(on)
        r.icon:SetTexture(item and item.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        r.name:SetWidth(width - 112)
        r.sub:SetWidth(width - 112)
        if page == "gear" then
            r.name:SetText(item and (S.QualityColor(item.quality) .. (item.name or L("Loading item data …")) .. "|r")
                or ("|cff9dabb8" .. L("Empty slot") .. "|r"))
            r.sub:SetText(L(P.slotNames[data.slot] or ""))
            r.value:SetText(data.score and number(data.score) or "")
            color(r.value, C.gold)
        else
            r.name:SetText(S.QualityColor(item.quality) .. item.name .. "|r")
            r.sub:SetText(L(P.slotNames[data.slot] or "") .. " · " .. sourceLine(data.entry))
            r.value:SetText(signed(data.gain))
            color(r.value, C.green)
        end
        r:Show()
    end
    U.listContent:SetHeight(math.max(10, #list * 46))
    if #list == 0 then
        local message
        if missing and page ~= "bags" then
            message = L("ForeverDB is not installed. Quests and dungeons need it; the CurseForge app installs it with GearPilot. Bag upgrades work without it.")
        elseif loading then
            message = L("Loading item data …")
        else
            message = L("No upgrades in this selection. Try a wider level range in the settings.")
        end
        U.empty:SetText(message)
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
    elseif page == "gear" then
        showGear(found, profile)
    else
        showUpgrade(found)
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
