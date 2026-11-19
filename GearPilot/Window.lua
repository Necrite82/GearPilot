local _, GP = ...
local P, L = GP.Planner, GP.L

local colors = {
    window = {0.078, 0.090, 0.110}, panel = {0.098, 0.114, 0.137},
    raised = {0.122, 0.141, 0.172}, selected = {0.19, 0.17, 0.12}, gold = {0.88, 0.69, 0.31},
    muted = {0.65, 0.69, 0.73}, green = {0.52, 0.84, 0.63},
    text = {0.91, 0.90, 0.87}, dark = {0.11, 0.08, 0.02},
}

local function fill(frame, shade)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame:SetBackdropColor(unpack(colors[shade]))
    return frame
end

local function panel(parent, x, y, width, height, shade)
    local frame = fill(CreateFrame("Frame", nil, parent, "BackdropTemplate"), shade)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetSize(width, height)
    return frame
end

local function label(parent, x, y, width, font, shade, value)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(colors[shade]))
    text:SetText(value or "")
    return text
end

local function button(parent, x, y, width, height, caption, callback)
    local control = CreateFrame("Button", nil, parent, "BackdropTemplate")
    fill(control, "raised")
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    control:SetSize(width, height)
    local text = control:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetAllPoints()
    text:SetText(caption)
    control.caption = text
    control:SetScript("OnClick", callback)
    return control
end

local function selectButton(control, selected)
    control:SetBackdropColor(unpack(colors[selected and "gold" or "raised"]))
    control.caption:SetTextColor(unpack(colors[selected and "dark" or "text"]))
end

local frame = fill(CreateFrame("Frame", "GearPilotWindow", UIParent, "BackdropTemplate"), "window")
frame:SetSize(744, 568)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:Hide()
tinsert(UISpecialFrames, "GearPilotWindow")

local header = panel(frame, 0, 0, 744, 50, "panel")
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
label(header, 17, 16, 190, "GameFontNormalLarge", "gold", "GearPilot")
local summary = label(header, 228, 19, 387, "GameFontHighlightSmall", "muted")
button(header, 697, 10, 30, 30, "×", function() frame:Hide() end)

local refresh
local view = "Find upgrades"
local offset, selectedKey = 0, nil
local tabs, sources = {}, {}
local rangeLabel, profileLabel
local results = {}

for index, key in ipairs({"Find upgrades", "Equipped gear"}) do
    local tab = key
    tabs[tab] = button(frame, 16 + (index - 1) * 145, 60, 137, 28, L(tab), function()
        view, offset, selectedKey = tab, 0, nil
        GameTooltip:Hide()
        refresh()
    end)
end

local filter = panel(frame, 16, 97, 712, 72, "panel")
for index, key in ipairs({"Bags", "Quests", "Dungeons"}) do
    local source = key
    sources[source] = button(filter, 10 + (index - 1) * 87, 11, 79, 25, L(source), function()
        GP.settings.source, offset, selectedKey = source, 0, nil
        refresh()
    end)
end
rangeLabel = label(filter, 10, 48, 286, "GameFontHighlightSmall", "muted")
local offsets = {}
for index, spec in ipairs({
    {"below", 1, "−"}, {"below", -1, "+"}, {"above", -1, "−"}, {"above", 1, "+"},
}) do
    local key, delta = spec[1], spec[2]
    offsets[index] = button(filter, 300 + (index - 1) * 43, 36, 38, 24, spec[3], function()
        GP.settings[key] = math.max(0, math.min(10, GP.settings[key] + delta))
        offset, selectedKey = 0, nil
        refresh()
    end)
end
local filterCaption = label(filter, 300, 15, 180, "GameFontDisableSmall", "muted", "MIN                  MAX")
local profiles = P.profiles
label(filter, 503, 15, 192, "GameFontDisableSmall", "muted", L("Profile"))
button(filter, 503, 35, 26, 25, "<", function()
    GP.settings.profile = (GP.settings.profile - 2) % #profiles + 1
    refresh()
end)
profileLabel = label(filter, 540, 42, 115, "GameFontHighlightSmall", "gold")
profileLabel:SetJustifyH("CENTER")
button(filter, 674, 35, 26, 25, ">", function()
    GP.settings.profile = GP.settings.profile % #profiles + 1
    refresh()
end)

local list = panel(frame, 16, 179, 400, 347, "panel")
local detail = panel(frame, 426, 179, 302, 347, "panel")
local listMessage = label(list, 15, 17, 368, "GameFontHighlight", "muted")
local pageLabel = label(list, 10, 322, 380, "GameFontDisableSmall", "muted")
pageLabel:SetJustifyH("CENTER")
local heading = label(detail, 14, 15, 274, "GameFontNormal", "gold")
local body = label(detail, 14, 62, 274, "GameFontHighlight", "text")
body:SetSpacing(5)
label(frame, 16, 539, 712, "GameFontDisableSmall", "muted",
    L("Preview stat profiles; weapon damage and item effects are not scored."))

local slotNames = {}
for _, slot in ipairs(P.slots) do slotNames[slot[1]] = L(slot[2]) end
local rows = {}
local ROWS = 9
local function showItemTooltip(owner, item)
    if not item or not item.link then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(item.link)
    GameTooltip:Show()
end

for index = 1, ROWS do
    local row = button(list, 10, 10 + (index - 1) * 34, 380, 30, "", function(control)
        if not control.data then return end
        selectedKey = control.data.key
        refresh()
    end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetSize(20, 20)
    row.title = label(row, 32, 8, 263, "GameFontHighlightSmall", "text")
    row.title:SetWordWrap(false)
    row.value = label(row, 300, 8, 72, "GameFontHighlightSmall", "green")
    row.value:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", function(self)
        if self.data then showItemTooltip(self, self.data.item) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
end

local function scroll(delta)
    local nextOffset = math.max(0, math.min(#results - ROWS, offset + delta))
    if nextOffset ~= offset then
        offset = nextOffset
        GameTooltip:Hide()
        refresh()
    end
end
list:EnableMouseWheel(true)
list:SetScript("OnMouseWheel", function(_, delta) scroll(-delta * 3) end)
local prev = button(list, 10, 315, 36, 24, "<", function() scroll(-ROWS) end)
local nextPage = button(list, 354, 315, 36, 24, ">", function() scroll(ROWS) end)

local oldGear = button(detail, 14, 298, 274, 32, L("Current gear"), function() end)
oldGear:SetScript("OnEnter", function(self) showItemTooltip(self, self.item) end)
oldGear:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function showDetails(row, level)
    heading:SetText(row and row.title or L("Select an item for details."))
    oldGear:Hide()
    oldGear.item = nil
    if not row then body:SetText(""); return end
    if view == "Equipped gear" then
        local item = row.item
        if item and item.name then
            body:SetText(item.link .. "\n\n" .. L("Requires level %d"):format(item.minLevel or 0))
        else
            body:SetText(L(item and (item.loading and "Pending item data" or "Unknown") or "No item equipped"))
        end
        return
    end
    local entry, item = row.entry, row.item
    local source = entry.name or L(entry.source)
    if not entry.name and entry.sourceID then
        source = L(entry.source == "Quests" and "Quest %d" or "Dungeon %d"):format(entry.sourceID)
    end
    local lines = {
        slotNames[row.slot], L("Score gain") .. ("   +%.1f"):format(row.gain),
        "", L("Source") .. "   " .. source,
    }
    if item.minLevel > level then lines[#lines + 1] = L("Requires level %d"):format(item.minLevel) end
    if entry.provenance then lines[#lines + 1] = L(entry.provenance) end
    local prerequisites = {}
    for _, questID in ipairs(entry.prerequisites or {}) do
        if not C_QuestLog.IsQuestFlaggedCompleted(questID) then
            prerequisites[#prerequisites + 1] = C_QuestLog.GetTitleForQuestID(questID) or L("Quest %d"):format(questID)
        end
    end
    if #prerequisites > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = L("Prerequisites")
        for _, title in ipairs(prerequisites) do lines[#lines + 1] = title end
    end
    body:SetText(table.concat(lines, "\n"))
    oldGear.item = row.current
    oldGear.caption:SetText(row.current and (row.current.name or L("Unknown")) or L("No item equipped"))
    oldGear:Show()
end

refresh = function()
    if not frame:IsShown() or not GP.settings then return end
    local settings = GP.settings
    local level = UnitLevel("player")
    local className, class = UnitClass("player")
    local profile = profiles[settings.profile]
    local low, high = P.Range(level, settings.below, settings.above)
    local gear = GP.ReadGear()
    local empty, loading
    summary:SetText((className or "") .. "   ·   " .. L("Level %d"):format(level))
    profileLabel:SetText(L(profile.key))
    local search = view == "Find upgrades"
    local ranged = search and settings.source ~= "Bags"
    rangeLabel:SetShown(ranged)
    rangeLabel:SetText(("%s  %d–%d  ·  −%d / +%d"):format(L("Level range"), low, high, settings.below, settings.above))
    filterCaption:SetShown(ranged)
    for _, control in ipairs(offsets) do control:SetShown(ranged) end
    for key, control in pairs(tabs) do selectButton(control, key == view) end
    for key, control in pairs(sources) do
        control:SetShown(search)
        selectButton(control, key == settings.source)
    end

    if search then
        local candidates
        candidates, loading = GP.ReadCandidates(settings.source, low, high)
        results = P.Recommend(candidates, gear, {
            level = level, below = settings.below, above = settings.above, profile = profile, class = class,
        })
        empty = (settings.source ~= "Bags" and #GP.catalog.rows == 0) and "No quest or dungeon catalog installed yet."
            or (loading and "Pending item data" or "No upgrades in this selection.")
        for _, result in ipairs(results) do
            result.key, result.title = result.entry.key, result.item.name
            result.value = ("+%.1f"):format(result.gain)
        end
    else
        results = {}
        for _, slot in ipairs(P.slots) do
            local item = gear[slot[1]]
            local title = item and (item.name or L(item.loading and "Pending item data" or "Unknown")) or L("No item equipped")
            results[#results + 1] = { key = slot[1], title = slotNames[slot[1]] .. " · " .. title, item = item }
        end
    end

    offset = math.min(offset, math.max(0, #results - ROWS))
    local selected
    for _, result in ipairs(results) do
        if result.key == selectedKey then selected = result; break end
    end
    selected = selected or results[offset + 1]
    selectedKey = selected and selected.key
    for index, row in ipairs(rows) do
        local data = results[offset + index]
        row.data = data
        row:SetShown(data ~= nil)
        if data then
            row.icon:SetTexture(data.item and data.item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.title:SetText(data.title)
            row.value:SetText(data.value or "")
            row:SetBackdropColor(unpack(colors[data == selected and "selected" or "raised"]))
            row.title:SetTextColor(unpack(colors[data == selected and "gold" or "text"]))
        end
    end
    listMessage:SetText(#results == 0 and L(empty) or "")
    pageLabel:SetText(#results > 0 and ("%d–%d / %d"):format(offset + 1, math.min(#results, offset + ROWS), #results) or "")
    prev:SetShown(offset > 0)
    nextPage:SetShown(offset + ROWS < #results)
    showDetails(selected, level)
end

local scheduled = false
function GP.ScheduleRefresh()
    if not frame:IsShown() or scheduled then return end
    scheduled = true
    C_Timer.After(0, function()
        scheduled = false
        refresh()
    end)
end

frame:SetScript("OnShow", refresh)
frame:SetScript("OnHide", function() GameTooltip:Hide() end)
SLASH_GEARPILOT1, SLASH_GEARPILOT2 = "/gearpilot", "/gp"
SlashCmdList.GEARPILOT = function()
    frame:SetShown(not frame:IsShown())
end
