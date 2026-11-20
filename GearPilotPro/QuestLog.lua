-- Quest log (1.5.0): a hint when your quest log is full, which quests are best to abandon, and a list of quests you
-- abandoned to take again later (a dungeon quest for later, say) with a waypoint to the quest giver.
local _, GP = ...
local L = GP.L
local QL = {}
GP.QuestLog = QL

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end
local function later()
    local s = GP.settings
    if not s then return {} end
    s.questLater = type(s.questLater) == "table" and s.questLater or {}
    return s.questLater
end
QL.Later = later

-- Quests in your log: { id, title, level, complete }.
function QL.Quests()
    local list = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local entries = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, entries do
            local info = C_QuestLog.GetInfo(i)
            if type(info) == "table" and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
                list[#list + 1] = { id = info.questID, title = info.title, level = info.level,
                    complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) or false }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local entries = GetNumQuestLogEntries() or 0
        for i = 1, entries do
            local title, level, _, header, _, complete, _, id = GetQuestLogTitle(i)
            if not header and id and id > 0 then
                list[#list + 1] = { id = id, title = title, level = level, complete = complete == 1 or complete == true }
            end
        end
    end
    return list
end
function QL.Max()
    for _, fn in ipairs({ C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept, C_QuestLog and C_QuestLog.GetMaxNumQuests }) do
        local ok, value = pcall(fn or error)
        if ok and type(value) == "number" and value > 0 then return value end
    end
    return type(MAX_QUESTS) == "number" and MAX_QUESTS or 40
end
function QL.Full()
    local count, max = #QL.Quests(), QL.Max()
    return count >= max, count, max
end

-- Every quest in your log with a suggestion, worst to keep first:
-- grey quests, quests outside your route with little worth, dungeon quests (remember them for later).
function QL.Ranked()
    local db = ForeverDB
    local plan = GP.QuestRoute.Current()
    local inRoute = {}
    for _, q in ipairs(plan and plan.quests or {}) do inRoute[q.id] = q end
    local grey = GP.Planner.GreyLevel(GP.Player().level)
    local list = {}
    for _, q in ipairs(QL.Quests()) do
        local detail = db and db.qx and db.qx[q.id] or {}
        local zone = detail[11]
        local dungeon = db and db.dng and type(zone) == "number" and db.dng[zone] ~= nil or false
        local xp = GP.QuestXP.Get(q.id, q.level).xp or 0
        local route = inRoute[q.id]
        local entry = { id = q.id, title = q.title, level = q.level, complete = q.complete, dungeon = dungeon, xp = xp,
            inRoute = route ~= nil, gain = route and route.gain or 0 }
        if q.complete then
            entry.score, entry.reason = 1e9, L("complete – turn it in")
        elseif q.level and q.level > 0 and q.level <= grey then
            entry.score, entry.reason, entry.advice = 0, L("grey – hardly any experience"), "abandon"
        elseif dungeon then
            entry.score, entry.reason, entry.advice = 2e5 + xp, L("dungeon quest – remember it for later"), "remember"
        elseif not route then
            entry.score, entry.reason, entry.advice = 1e5 + xp, L("not in your route"), "abandon"
        else
            entry.score, entry.reason = 1e6 + xp, L("in your route")
        end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.score < b.score end)
    return list
end

-- Abandons a quest after you confirm it; remember = true keeps it in the list to take again.
local function selectQuest(id)
    if C_QuestLog and C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(id); return true end
    if SelectQuestLogEntry and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(id)
        if index then SelectQuestLogEntry(index); return true end
    end
    return false
end
local function abandon(id)
    if not selectQuest(id) then return false end
    local setAbandon = (C_QuestLog and C_QuestLog.SetAbandonQuest) or SetAbandonQuest
    local doAbandon = (C_QuestLog and C_QuestLog.AbandonQuest) or AbandonQuest
    if not (setAbandon and doAbandon) then return false end
    setAbandon()
    doAbandon()
    return true
end
function QL.Remember(id, title, level)
    later()[id] = { title = title, level = level, at = time and time() or 0 }
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
end
function QL.Forget(id)
    later()[id] = nil
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
end
if StaticPopupDialogs then
    StaticPopupDialogs.GEARPILOTPRO_ABANDON = {
        text = "%s", button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, data)
            if not data then return end
            if data.remember then QL.Remember(data.id, data.title, data.level) end
            if not abandon(data.id) then
                if data.remember then say(L("Remembered. Abandon it in your quest log.")) end
                return
            end
            say((data.remember and L("Abandoned and remembered: %s") or L("Abandoned: %s")):format(data.title or ("#" .. data.id)))
        end,
    }
end
function QL.Abandon(id, title, level, remember)
    title = GP.QuestInfo.Title(id, title)
    local text = (remember and L("Abandon \"%s\" and remember it for later?") or L("Abandon \"%s\"? Its progress is lost.")):format(title)
    if StaticPopup_Show then
        StaticPopup_Show("GEARPILOTPRO_ABANDON", text, nil, { id = id, title = title, level = level, remember = remember })
    end
end

-- Remembered quests: { id, title, level, inLog, done }.
function QL.LaterList()
    local list = {}
    for id, entry in pairs(later()) do
        list[#list + 1] = { id = id, title = entry.title, level = entry.level, at = entry.at,
            inLog = GP.QuestInfo.LogIndex(id) ~= nil, done = GP.Sources.QuestDone(id) }
    end
    table.sort(list, function(a, b) return (a.level or 0) < (b.level or 0) end)
    return list
end

-- Hint once when the log becomes full; taking a remembered quest again or finishing it clears it from the list.
local wasFull = false
local function check()
    if not GP.settings then return end
    for id in pairs(later()) do
        if GP.Sources.QuestDone(id) then later()[id] = nil end
    end
    local full, count, max = QL.Full()
    if full and not wasFull then
        local tips = {}
        for _, entry in ipairs(QL.Ranked()) do
            if entry.advice and #tips < 2 then
                tips[#tips + 1] = GP.QuestInfo.Title(entry.id, entry.title) .. " (" .. entry.reason .. ")"
            end
        end
        say((L("Quest log full (%d/%d)."):format(count, max))
            .. (#tips > 0 and (" " .. L("Best to abandon: ") .. table.concat(tips, ", ") .. ".") or "")
            .. " " .. L("More under Quest route → Quest log."))
    end
    wasFull = full
end
local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
local pending = false
events:SetScript("OnEvent", function(_, event, first, second)
    -- QUEST_ACCEPTED gives (questID) or (log index, questID), depending on the client.
    local questID = type(second) == "number" and second or first
    if event == "QUEST_ACCEPTED" and type(questID) == "number" and GP.settings and later()[questID] then
        later()[questID] = nil
    end
    if pending or not C_Timer then return end
    pending = true
    C_Timer.After(1, function() pending = false; check() end)
end)
