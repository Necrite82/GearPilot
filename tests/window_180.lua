-- Exercise the native UI callbacks through the addon load order. WoW rendering is outside this test.
local function noop() end
local frames, methods = {}, {}
local frameAPI = { __index = function(_, key)
    return methods[key] or (key:match("^[A-Z]") and noop or nil)
end }
function CreateFrame(_, name, parent)
    local frame = setmetatable({ text = "", width = 300, height = 360, parent = parent, scripts = {}, events = {} }, frameAPI)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
methods.CreateTexture = methods.CreateFontString
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetFrameLevel() return 1 end
function methods:GetStringHeight() return 15 end
function methods:GetStringWidth() return #self.text * 6 end
function methods:SetText(value) self.text = value end
function methods:SetFontString(font) self.font = font end
function methods:GetFontString() return self.font end
function methods:SetShown(on) self.hidden = not on end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:IsShown() return not self.hidden end
function methods:IsEnabled() return self.enabled ~= false end
function methods:SetEnabled(on) self.enabled = on end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetVerticalScroll(offset) self.offset = offset end
function methods:Click() self.scripts.OnClick(self, "LeftButton") end
function CreateFont() return setmetatable({}, frameAPI) end

local tipLink
GameTooltip = { SetOwner = noop, Show = noop, Hide = noop, SetHyperlink = function(_, link) tipLink = link end }
UIParent = CreateFrame("Frame")
Minimap = CreateFrame("Frame")
UISpecialFrames, SlashCmdList = {}, {}
tinsert = table.insert
unpack = unpack or table.unpack
function GetLocale() return "enUS" end
function UnitLevel() return 30 end
function UnitClass() return "Rogue", "ROGUE" end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return "Alliance" end
C_Timer = { After = noop }
C_QuestLog = { IsOnQuest = function() return true end, IsComplete = function() return true end }
GearPilotProSettings = { page = "route", views = { route = "zones" } }

local GP = {}
for line in io.lines("GearPilotPro/GearPilotPro.toc") do
    local file = line:match("^([^#]+%.lua)%s*$")
    if file then assert(loadfile("GearPilotPro/" .. file:gsub("\\", "/")))("GearPilotPro", GP) end
end
for _, frame in ipairs(frames) do
    if frame.events.ADDON_LOADED and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "ADDON_LOADED", "GearPilotPro")
    end
end

local function visible(frame)
    return frame:IsShown() and (not frame.parent or visible(frame.parent))
end
local function button(label)
    for _, frame in ipairs(frames) do
        if frame.text == label and frame.scripts.OnClick and visible(frame) then return frame end
    end
end
local function hasText(label)
    for _, frame in ipairs(frames) do
        if frame.text == label and visible(frame) then return true end
    end
    return false
end
local function click(label)
    local target = assert(button(label), "Missing button: " .. label)
    assert(target:IsEnabled(), "Disabled button: " .. label)
    target:Click()
end

local quest = { id = 11, title = "A route task", level = 30, xp = 1000 }
local first = { zone = 1, name = "Recommended area", quests = { quest }, xp = 1000 }
local second = { zone = 2, name = "My destination", quests = {}, xp = 0 }
ForeverDB = { quest = {}, qx = {}, area = {} }
GP.Sources.state = "ready"
local QR = GP.QuestRoute
QR.Current = function()
    local chosen = GP.settings.routeZone
    local zone = chosen == second.zone and second or first
    local tasks = zone == first and { { kind = "turnin", quest = quest } } or {}
    return { zone = zone, zones = { first, second }, chosenZone = chosen, recommended = first,
        quests = zone.quests, xp = zone.xp, tasks = tasks }
end
local point
QR.MapPoint = function() return 7, .35, .45 end
GP.Route.ToSpot = function(spot) point = spot end
GP.Tracker.Refresh = noop
local bagItem
GP.ReadGear = function() return {} end
GP.ReadCandidates = function(source)
    local rows = {}
    if source == "Bags" and bagItem then
        rows[1] = { key = "bag:42", source = source, item = bagItem }
    end
    return rows, false, "ready"
end
GP.Open("route")
assert(GP.settings.views.route == "route", "obsolete zone view must reopen as the route")
assert(hasText("Recommended area") and hasText("Tasks in this zone"))
click("Set waypoint")
assert(point.map == 7 and point.x == .35 and point.y == .45, "waypoint must use the selected task's coordinates")
assert(not button("Automatic"), "route settings start collapsed")
click("Route options")
assert(button("Automatic"), "route settings are still accessible")
click("Route options")

click("Choose zone")
click("Recommended area")
click("My destination  ·  0")
assert(not GP.settings.routeZone, "pending selection must leave the route alone")
click("Quest in this zone")
assert(GP.settings.routeZone == 2 and hasText("My destination") and hasText("Your choice"))
GP.Render()
assert(hasText("My destination"), "re-rendering must preserve a manual destination")
click("Use recommendation")
assert(not GP.settings.routeZone and hasText("Recommended area"))
click("Choose zone")
GP.Open("upgrades")
assert(not button("Quest in this zone"), "picker closes when leaving the route")

local item = { id = 42, name = "Bag upgrade", link = "item:42", quality = 2, minLevel = 20,
    equip = "INVTYPE_CHEST", classID = 4, subclass = 2, stats = { AGI = 7 } }
GP.ReadGear = function()
    return { [5] = { id = 12, name = "Old vest", equip = "INVTYPE_CHEST", stats = { AGI = 4 } } }
end
bagItem = item
GP.ItemData = function() return item end
GP.Render()
assert(hasText("Replaces") and hasText("Old vest"), "the new detail shows the replaced item")
local rowHover, detailHover = 0, 0
for _, frame in ipairs(frames) do
    if visible(frame) and frame.scripts.OnEnter then
        tipLink = nil
        frame.scripts.OnEnter(frame)
        if tipLink == item.link then
            if frame.link then rowHover = rowHover + 1 else detailHover = detailHover + 1 end
        end
    end
end
assert(rowHover == 1 and detailHover == 1, "row and detail icon must both pass the item link to GameTooltip")
print("PASS: 1.8.0 TOC, route picker, route options and item tooltips")
