-- Quest info on hover (1.3.6): the quest's text where the game has it, Shift-click links it in chat, right-click
-- shares it with your group. The long story text only exists for quests in your quest log; for the others the
-- game's quest link shows title and objectives.
local _, GP = ...
local L = GP.L
local QI = {}
GP.QuestInfo = QI

local function readable(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end
local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end

function QI.Level(questID)
    local row = type(ForeverDB) == "table" and ForeverDB.quest and ForeverDB.quest[questID]
    local level = row and row[2]
    if type(level) ~= "number" or level <= 0 then level = row and row[3] end
    return type(level) == "number" and level > 0 and level or nil
end
function QI.Title(questID, fallback)
    return GP.Sources.QuestTitle(questID, fallback) or fallback or ("#" .. questID)
end
function QI.LogIndex(questID)
    if not (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then return nil end
    local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    return ok and type(index) == "number" and index > 0 and index or nil
end

-- Selects a quest in the quest log for the old (index) and the new (questID) interface; returns a function
-- that restores the previous selection.
local function select(questID, index)
    if SelectQuestLogEntry and GetQuestLogSelection then
        local old = GetQuestLogSelection()
        SelectQuestLogEntry(index)
        return function() if old and old > 0 then SelectQuestLogEntry(old) end end
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        local old = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(questID)
        return function() if old and old ~= 0 then C_QuestLog.SetSelectedQuest(old) end end
    end
end

-- Story and objective text of a quest in your quest log.
function QI.LogText(questID)
    local index = QI.LogIndex(questID)
    if not index or not GetQuestLogQuestText then return nil end
    local restore = select(questID, index)
    if not restore then return nil end
    local ok, story, objectives = pcall(GetQuestLogQuestText, index)
    restore()
    if not ok then return nil end
    return readable(story) and story ~= "" and story or nil, readable(objectives) and objectives ~= "" and objectives or nil
end

function QI.Objectives(questID)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return {} end
    local ok, list = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(list) ~= "table" then return {} end
    local result = {}
    for _, o in ipairs(list) do
        if type(o) == "table" and readable(o.text) and o.text ~= "" then result[#result + 1] = o end
    end
    return result
end

function QI.Link(questID, fallback)
    return ("|cffffff00|Hquest:%d:%d|h[%s]|h|r"):format(questID, QI.Level(questID) or 0, QI.Title(questID, fallback))
end

-- What a quest asks for, by ForeverDB (when the game's quest link stays empty): items, creatures, objects.
function QI.Targets(questID)
    local db = type(ForeverDB) == "table" and ForeverDB or nil
    local detail = db and db.qx and db.qx[questID]
    local out = {}
    if type(detail) ~= "table" then return out end
    for _, itemID in ipairs(type(detail[10]) == "table" and detail[10] or {}) do
        local item = GP.ItemData and GP.ItemData(itemID)
        local name = item and item.name or (db.item and db.item[itemID] and db.item[itemID][1])
        if name then out[#out + 1] = name end
    end
    for _, npcID in ipairs(type(detail[8]) == "table" and detail[8] or {}) do
        local name = (GP.Names and GP.Names.Get(npcID)) or (db.npc and db.npc[npcID] and db.npc[npcID][1])
        if name then out[#out + 1] = name end
    end
    for _, objectID in ipairs(type(detail[9]) == "table" and detail[9] or {}) do
        local name = db.obj and db.obj[objectID] and db.obj[objectID][1]
        if name then out[#out + 1] = name end
    end
    return out
end

-- Long story texts are cut after a few sentences, the tooltip should not cover the screen.
local function shorten(text, limit)
    text = text:gsub("\r", ""):gsub("\n\n+", "\n")
    if #text <= limit then return text end
    local cut = text:sub(1, limit)
    local stop = cut:match("^.*()[%.!%?]")
    return (stop and stop > limit / 2 and cut:sub(1, stop) or cut) .. " …"
end

function QI.CanShare(questID)
    if not QI.LogIndex(questID) then return false, L("Only quests in your quest log can be shared.") end
    if not (IsInGroup and IsInGroup()) then return false, L("You are not in a group.") end
    if C_QuestLog and C_QuestLog.IsPushableQuest then
        local ok, pushable = pcall(C_QuestLog.IsPushableQuest, questID)
        if ok and pushable == false then return false, L("This quest cannot be shared.") end
    end
    return true
end
function QI.Share(questID, fallback)
    local ok, why = QI.CanShare(questID)
    if not ok then say(why); return false end
    local restore = select(questID, QI.LogIndex(questID))
    if QuestLogPushQuest then QuestLogPushQuest() end
    if restore then restore() end
    say((L("Shared: %s")):format(QI.Title(questID, fallback)))
    return true
end

-- Puts the quest link into the chat line (opens it when closed).
function QI.Insert(questID, fallback)
    local link = QI.Link(questID, fallback)
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return true end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
    return true
end

-- Shift-click and right-click; returns true when it handled the click.
function QI.Click(questID, fallback, button)
    if not questID then return false end
    if button == "RightButton" then QI.Share(questID, fallback); return true end
    local chatLink = (IsModifiedClick and IsModifiedClick("CHATLINK")) or (IsShiftKeyDown and IsShiftKeyDown())
    if chatLink then return QI.Insert(questID, fallback) end
    return false
end

-- Tooltip: title, level, objectives (with progress for your own quests), story, experience, hints.
-- opts: prefix (before the title), lines (extra grey lines), hint (extra click hint).
function QI.Show(owner, questID, fallback, opts, reloaded)
    opts = opts or {}
    QI.owner, QI.shown = owner, { questID, fallback, opts, reloaded = reloaded }
    -- 1.3.7: the game can answer a load request at once (inside this call); the busy flag and the single reload
    -- keep that answer from showing the tooltip again and again (C stack overflow).
    QI.busy = true
    local tip = GameTooltip
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    local inLog = QI.LogIndex(questID) ~= nil
    local level = QI.Level(questID)
    tip:AddLine((opts.prefix or "") .. QI.Title(questID, fallback), 1, .82, 0, true)
    local info = {}
    if level then info[#info + 1] = (L("Quest level %d")):format(level) end
    if inLog then info[#info + 1] = L("in quest log") end
    if #info > 0 then tip:AddLine(table.concat(info, " · "), .62, .67, .72) end
    for _, line in ipairs(opts.lines or {}) do tip:AddLine(line, .8, .8, .8, true) end
    local story, objectiveText = QI.LogText(questID)
    local objectives = QI.Objectives(questID)
    if #objectives > 0 then
        tip:AddLine(" ")
        for _, o in ipairs(objectives) do
            if o.finished then tip:AddLine("- " .. o.text, .52, .84, .63, true) else tip:AddLine("- " .. o.text, 1, 1, 1, true) end
        end
    elseif objectiveText then
        tip:AddLine(" ")
        tip:AddLine(shorten(objectiveText, 300), 1, 1, 1, true)
    elseif not inLog then
        -- Not in your log: the game's quest link knows the objectives; ForeverDB's targets otherwise.
        local found = false
        local probe = GP.QuestInfoProbe
        if not probe and CreateFrame then
            probe = CreateFrame("GameTooltip", "GearPilotProQuestProbe", UIParent, "GameTooltipTemplate")
            GP.QuestInfoProbe = probe
        end
        if probe and probe.SetHyperlink then
            probe:SetOwner(UIParent, "ANCHOR_NONE")
            probe:ClearLines()
            local ok = pcall(probe.SetHyperlink, probe, ("quest:%d:%d"):format(questID, level or 0))
            local lines = ok and probe:NumLines() or 0
            for i = 2, lines do
                local left = _G["GearPilotProQuestProbeTextLeft" .. i]
                local text = left and left:GetText()
                if readable(text) and text ~= "" then
                    if not found then tip:AddLine(" ") end
                    found = true
                    tip:AddLine(text, 1, 1, 1, true)
                end
            end
            probe:Hide()
        end
        if not found then
            local targets = QI.Targets(questID)
            if #targets > 0 then
                tip:AddLine(" ")
                tip:AddLine(L("Objective") .. ": " .. table.concat(targets, ", "), 1, 1, 1, true)
            end
        end
    end
    if story then
        tip:AddLine(" ")
        tip:AddLine(shorten(story, 420), .85, .80, .68, true)
    end
    local xp = GP.QuestXP and GP.QuestXP.Get(questID, level)
    if xp and xp.xp and xp.xp > 0 then
        tip:AddLine(" ")
        tip:AddLine(L("Experience") .. ": " .. GP.QuestXP.Text(xp.xp), .88, .69, .31)
    end
    tip:AddLine(" ")
    if opts.hint then tip:AddLine(opts.hint, .88, .69, .31) end
    tip:AddLine(L("Shift-click: link in chat"), .62, .67, .72)
    if inLog then tip:AddLine(L("Right-click: share with your group"), .62, .67, .72) end
    tip:Show()
    if not reloaded and C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, questID) end
    QI.busy = false
end
function QI.Hide(owner)
    if QI.owner == owner then QI.owner, QI.shown = nil, nil end
    GameTooltip:Hide()
end

-- The game answers a quest request later: show the tooltip again with the loaded text.
if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
    events:SetScript("OnEvent", function(_, _, questID, ok)
        local shown = QI.shown
        if QI.busy or not ok or not shown or shown.reloaded then return end
        if shown[1] == questID and QI.owner and GameTooltip:IsOwned(QI.owner) then
            QI.Show(QI.owner, shown[1], shown[2], shown[3], true)
        end
    end)
end

-- Invisible button over a quest icon; QI.Set gives it a quest (nil hides it).
function QI.Hotspot(parent, icon, margin)
    local b = CreateFrame("Button", nil, parent)
    margin = margin or 3
    b:SetPoint("TOPLEFT", icon, "TOPLEFT", -margin, margin)
    b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", margin, -margin)
    b:SetFrameLevel(parent:GetFrameLevel() + 3)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self) if self.questID then QI.Show(self, self.questID, self.questTitle) end end)
    b:SetScript("OnLeave", function(self) QI.Hide(self) end)
    b:SetScript("OnClick", function(self, button)
        if self.questID and not QI.Click(self.questID, self.questTitle, button) and self.fallthrough then
            self.fallthrough(button)
        end
    end)
    b:Hide()
    return b
end
function QI.Set(hotspot, questID, title)
    if not hotspot then return end
    hotspot.questID, hotspot.questTitle = questID, title
    hotspot:SetShown(questID ~= nil)
end
