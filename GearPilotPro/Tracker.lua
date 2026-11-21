-- Quest tracker (1.4.0): a small window you can leave open while questing. It shows the quest route compactly:
-- zone and experience, the current step with its objectives, the next steps with distance and experience.
-- Click a step for its waypoint; hover for the quest text, Shift-click links, right-click shares.
local _, GP = ...
local L, S = GP.L, GP.Style
local C = S.palette
local T = {}
GP.Tracker = T

local WIDTH, ROW, MAXROWS = 270, 34, 6
local ICONS = {
    accept = "Interface\\GossipFrame\\AvailableQuestIcon", turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
    objective = "Interface\\Icons\\Ability_Hunter_SniperShot",
}

local function settings()
    local s = GP.settings
    if not s then return {} end
    s.tracker = type(s.tracker) == "table" and s.tracker or {}
    return s.tracker
end

local frame = CreateFrame("Frame", "GearPilotProTracker", UIParent, "BackdropTemplate")
S.Round(frame)
frame:SetBackdropColor(C.window[1], C.window[2], C.window[3], .92)
frame:SetSize(WIDTH, 80)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
local function save()
    local point, _, relative, x, y = frame:GetPoint(1)
    local s = settings()
    s.point, s.relative, s.x, s.y = point, relative, x, y
end
frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); save() end)

local title = S.Text(frame, "GameFontNormalSmall", 12, 10, WIDTH - 120, L("Quest route"))
title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
title:SetWordWrap(false)
local close = S.Button(frame, 20, 18, "x", function() T.Hide() end)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
local fold = S.Button(frame, 20, 18, "-", function()
    local s = settings()
    s.collapsed = not s.collapsed
    T.Refresh()
end)
fold:SetPoint("RIGHT", close, "LEFT", -4, 0)
local go = S.Button(frame, 46, 18, "", function()
    local QR = GP.QuestRoute
    if QR.following then QR.Follow(false) else QR.Follow(true, true) end
    T.Refresh()
end)
go:SetPoint("RIGHT", fold, "LEFT", -4, 0)
local summary = S.Text(frame, "GameFontDisableSmall", 12, 26, WIDTH - 24)
summary:SetWordWrap(false)

-- Quest log full: a red line under the summary; a click opens the quest log view with the suggestions.
local warning = CreateFrame("Button", nil, frame)
warning:SetHeight(14)
warning:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
warning:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -40)
warning.text = S.Text(warning, "GameFontNormalSmall", 0, 0, WIDTH - 24)
warning.text:SetTextColor(C.red[1], C.red[2], C.red[3])
warning.text:SetWordWrap(false)
warning:SetScript("OnClick", function()
    GP.settings.views = GP.settings.views or {}
    GP.settings.views.route = "log"
    GP.Open("route")
end)
warning:Hide()

-- Right-click menu of a step: share, skip, earlier, later.
local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
S.Round(menu)
menu:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1)
menu:SetFrameStrata("DIALOG")
menu:SetSize(150, 4 * 26 + 10)
menu:Hide()
menu.buttons = {}
local function menuButton(i, label, fn)
    local b = menu.buttons[i]
    if not b then
        b = S.Button(menu, 138, 22, "", nil)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * 26)
        menu.buttons[i] = b
    end
    b:SetText(label)
    b:SetScript("OnClick", function() menu:Hide(); fn() end)
    b:Show()
end
local function openMenu(owner, t)
    local QR, id, title = GP.QuestRoute, t.quest.id, t.quest.title
    local n = 0
    local function add(label, fn) n = n + 1; menuButton(n, label, fn) end
    if GP.QuestInfo.LogIndex(id) then add(L("Share with group"), function() GP.QuestInfo.Share(id, title) end) end
    add(L("Skip"), function() QR.Skip(id, true) end)
    add(L("Earlier"), function() QR.Move(id, -1) end)
    add(L("Later"), function() QR.Move(id, 1) end)
    for i = n + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:SetHeight(n * 26 + 10)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 4, 0)
    menu:Show()
end
menu:SetScript("OnUpdate", function(self)
    -- Closes when the mouse leaves it for a moment (no global click catcher needed).
    if self:IsMouseOver(8, -8, -8, 8) or (self.owner and self.owner:IsMouseOver()) then self.away = 0; return end
    self.away = (self.away or 0) + 1
    if self.away > 90 then self:Hide() end
end)

local rows = {}
local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, frame, "BackdropTemplate")
    S.Round(r, true)
    r:SetWidth(WIDTH - 16)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.stripe = r:CreateTexture(nil, "OVERLAY")
    r.stripe:SetWidth(2)
    r.stripe:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -4)
    r.stripe:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 4)
    r.stripe:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 7, -5)
    r.name = S.Text(r, "GameFontHighlightSmall", 28, 5, WIDTH - 100)
    r.name:SetWordWrap(false)
    r.value = S.Text(r, "GameFontNormalSmall", 0, 5, 64, "", "RIGHT")
    r.value:ClearAllPoints()
    r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -5)
    r.sub = S.Text(r, "GameFontDisableSmall", 28, 19, WIDTH - 52)
    r.sub:SetWordWrap(true)
    r:SetScript("OnEnter", function(self)
        if self.task then
            GP.QuestInfo.Show(self, self.task.quest.id, self.task.quest.title,
                { hint = L("Click: waypoint"), right = L("Right-click: share, skip, order") })
        end
    end)
    r:SetScript("OnLeave", function(self) GP.QuestInfo.Hide(self) end)
    r:SetScript("OnClick", function(self, button)
        local t = self.task
        if not t then return end
        if button == "RightButton" then menu.owner = self; openMenu(self, t); return end
        if GP.QuestInfo.Click(t.quest.id, t.quest.title, button) then return end
        local QR = GP.QuestRoute
        if QR.following and (t.kind == "accept" or t.quest.active) and not QR.Blocked(t) then
            QR.Follow(true, false, QR.TaskKey(t))
            return
        end
        local uiMap, x, y = QR.MapPoint(t)
        if uiMap and x then GP.Route.ToSpot({ world = false, map = uiMap, x = x, y = y }, QR.Title(t.quest), QR.TaskText(t)) end
    end)
    rows[i] = r
    return r
end

-- Objectives of a quest in your quest log as one short line each ("Kobold Vermin slain: 3/10").
local function objectiveLines(questID)
    local lines = {}
    for _, o in ipairs(GP.QuestInfo.Objectives(questID)) do
        lines[#lines + 1] = (o.finished and "|cff85d6a0" or "|cffd8d4cc") .. o.text .. "|r"
        if #lines >= 3 then break end
    end
    return lines
end

function T.Refresh()
    if not frame:IsShown() then return end
    local QR = GP.QuestRoute
    local s = settings()
    fold:SetText(s.collapsed and "+" or "-")
    go:SetText(QR.following and L("Stop") or L("Go"))
    if QR.following then go:SetBackdropColor(.114, .133, .165, 1) else S.Primary(go) end
    local plan = QR.Current()
    title:SetText(plan and plan.mine and L("My route") or L("Quest route"))
    local open = QR.OpenTasks(plan)
    -- Summary: zone, open quests, experience still in the route.
    local quests, xp = {}, 0
    for _, entry in ipairs(open) do
        local q = entry.t.quest
        if not quests[q.id] then quests[q.id] = true; quests[#quests + 1] = q.id; xp = xp + (q.xp or 0) end
    end
    local parts = {}
    if plan and plan.zone and plan.zone.name then parts[#parts + 1] = plan.zone.name end
    parts[#parts + 1] = (L("%d quests"):format(#quests))
    if xp > 0 then parts[#parts + 1] = GP.QuestXP.Text(xp) end
    summary:SetText(table.concat(parts, " · "))
    local here = QR.Position()
    local y = 42
    local full, count, max = GP.QuestLog.Full()
    warning:SetShown(full)
    if full then
        warning.text:SetText((L("Quest log full (%d/%d)."):format(count, max)) .. " " .. L("Click: suggestions"))
        y = y + 16
    end
    local count = s.collapsed and math.min(1, #open) or math.min(MAXROWS, #open)
    for i = 1, count do
        local t, index = open[i].t, open[i].index
        local r = row(i)
        r.task = t
        local current = i == 1
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -y)
        if current then r:SetBackdropColor(C.raised[1], C.raised[2], C.raised[3], 1) else r:SetBackdropColor(0, 0, 0, 0) end
        r.stripe:SetShown(current)
        r.icon:SetTexture(t.buy and "Interface\\GossipFrame\\VendorGossipIcon" or ICONS[t.kind])
        r.name:SetText(("%d. %s"):format(index, QR.Title(t.quest)))
        local c = current and C.text or C.muted
        r.name:SetTextColor(c[1], c[2], c[3])
        r.value:SetText((t.kind == "turnin" and (t.quest.xp or 0) > 0) and GP.QuestXP.Text(t.quest.xp) or "")
        local sub = { QR.TaskText(t) }
        if t.p and here then
            local d = QR.Distance(here, t.p)
            if d < 5000 then sub[#sub + 1] = (L("%d m"):format(math.floor(d))) end
        end
        local text = table.concat(sub, " · ")
        -- The current step shows the quest's objectives with your progress.
        local lines = (current and t.kind ~= "accept") and objectiveLines(t.quest.id) or {}
        if #lines > 0 then text = text .. "\n" .. table.concat(lines, "\n") end
        r.sub:SetText(text)
        local height = math.max(ROW, 24 + (r.sub:GetStringHeight() or 12))
        r:SetHeight(height)
        r:Show()
        y = y + height + 2
    end
    for i = count + 1, #rows do rows[i]:Hide() end
    if #open == 0 then
        summary:SetText(plan and L("Quest route: nothing left here. Open the route for the next zone.") or L("Quest route"))
        summary:SetWordWrap(true)
        y = y + 2 + (summary:GetStringHeight() or 12)
    else
        summary:SetWordWrap(false)
    end
    frame:SetHeight(y + 8)
end

function T.Show()
    local s = settings()
    s.shown = true
    if s.point and not frame.placed then
        frame:ClearAllPoints()
        frame:SetPoint(s.point, UIParent, s.relative or s.point, s.x or 0, s.y or 0)
        frame.placed = true
    end
    frame:Show()
    T.Refresh()
end
function T.Hide()
    settings().shown = false
    frame:Hide()
end
function T.Toggle()
    if frame:IsShown() then T.Hide() else T.Show() end
end
function T.IsShown() return frame:IsShown() end

-- 1.6.2: drawn again right after quest log, bag or route changes, otherwise every 5 seconds for the distances
-- (was every second: a steady stream of garbage while questing).
local elapsed, dirty = 0, true
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < (dirty and .5 or 5) then return end
    elapsed, dirty = 0, false
    T.Refresh()
end)
local changes = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED",
    "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA" }) do
    changes:RegisterEvent(event)
end
changes:SetScript("OnEvent", function() dirty = true end)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    events:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if C_Timer then C_Timer.After(2, function() if settings().shown then T.Show() end end) end
end)
