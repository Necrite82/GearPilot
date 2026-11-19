-- Quest experience and money: asked from the game server (the quest's data loads by ID, also for quests that
-- are not in your quest log), remembered in GearPilotProCache, otherwise ForeverDB's value (qrw: money, xp).
-- ForeverDB's experience is the full value; quests far below your level give less (Classic rule).
local _, GP = ...
local L = GP.L
local XP = {}
GP.QuestXP = XP

-- Share of the full experience by how many levels you are above the quest (Classic): full up to 5 levels,
-- then 80, 60, 40, 20 % and 10 % from 10 levels above.
function XP.Factor(questLevel, playerLevel)
    if type(questLevel) ~= "number" or questLevel <= 0 then return 1 end
    local diff = playerLevel - questLevel
    if diff <= 5 then return 1 end
    if diff >= 10 then return 0.1 end
    return 1 - (diff - 5) * 0.2
end
-- Classic rounds quest experience to steps of 5 (small values) up to 50 (large ones); 5 is close enough here.
function XP.Round(value)
    return math.floor(value / 5 + 0.5) * 5
end

local function cache()
    GearPilotProCache = type(GearPilotProCache) == "table" and GearPilotProCache or {}
    GearPilotProCache.quests = type(GearPilotProCache.quests) == "table" and GearPilotProCache.quests or {}
    return GearPilotProCache.quests
end

-- What the server said for a loaded quest: experience for your level and money, or nil.
local function fromServer(questID)
    local getXP, getMoney = GetQuestLogRewardXP, GetQuestLogRewardMoney
    if not getXP then return nil end
    local ok, xp = pcall(getXP, questID)
    local okMoney, money = false, nil
    if getMoney then okMoney, money = pcall(getMoney, questID) end
    xp = ok and type(xp) == "number" and xp or 0
    money = okMoney and type(money) == "number" and money or 0
    if xp <= 0 and money <= 0 then return nil end
    -- A client that ignores the quest ID answers for the quest selected in your log: same value, other quest.
    local selected = C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
    if selected and selected ~= 0 and selected ~= questID then
        local okSelected, selectedXP = pcall(getXP)
        if okSelected and selectedXP == xp and xp > 0 then return nil end
    end
    return xp, money
end

local requested, queue, running = {}, {}, false
local function pump()
    -- A few requests at a time, so a long dungeon list does not flood the server.
    for _ = 1, 5 do
        local id = table.remove(queue, 1)
        if not id then running = false return end
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then pcall(C_QuestLog.RequestLoadQuestByID, id) end
    end
    if C_Timer then C_Timer.After(0.3, pump) else running = false end
end
-- Asks the server for these quests (once per session and level).
function XP.Request(ids)
    local level = GP.Player().level
    local known = cache()
    for _, id in ipairs(ids or {}) do
        local entry = known[id]
        local key = id .. ":" .. level
        if not requested[key] and not (entry and entry.level == level) then
            requested[key] = true
            queue[#queue + 1] = id
        end
    end
    if #queue > 0 and not running then
        running = true
        pump()
    end
end

-- Experience for you and money of one quest: { xp, money, source = "server"|"db"|nil, full }.
-- level: the quest level (for the reduction of ForeverDB's values).
function XP.Get(questID, questLevel)
    local player = GP.Player()
    local entry = cache()[questID]
    if entry and entry.level == player.level then
        return { xp = entry.xp, money = entry.money, source = "server" }
    end
    local db = ForeverDB
    local reward = db and db.qrw and db.qrw[questID]
    local level = questLevel or (db and db.quest and db.quest[questID] and db.quest[questID][2])
    local full = reward and type(reward[2]) == "number" and reward[2] > 0 and reward[2] or nil
    local money = reward and type(reward[1]) == "number" and reward[1] > 0 and reward[1] or nil
    if player.level >= (GP.MAX_LEVEL or 60) then
        return { xp = 0, money = money, source = (full or money) and "db" or nil, full = full }
    end
    if entry then
        -- Asked at another level: the server's value scaled is closer than nothing.
        return { xp = entry.xp, money = entry.money or money, source = "server" }
    end
    if not full then return { xp = nil, money = money, source = money and "db" or nil } end
    return { xp = XP.Round(full * XP.Factor(level, player.level)), money = money, source = "db", full = full }
end

-- Sum over open quests: experience, money, count without a value.
function XP.Sum(quests)
    local xp, money, unknown = 0, 0, 0
    for _, info in ipairs(quests) do
        local value = XP.Get(info.id, info.level)
        if value.xp then xp = xp + value.xp elseif not value.money then unknown = unknown + 1 end
        money = money + (value.money or 0)
    end
    return xp, money, unknown
end

-- "1.500 EP" (thousands with a dot in German, a comma in English).
function XP.Text(value)
    if not value then return nil end
    local text = tostring(math.floor(value + 0.5))
    local sep = L("THOUSANDS_SEPARATOR")
    if sep == "THOUSANDS_SEPARATOR" then sep = "," end
    text = text:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse():gsub("^%" .. sep, "")
    return text .. " " .. L("XP")
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
events:SetScript("OnEvent", function(_, _, questID, success)
    if not success or not questID then return end
    local xp, money = fromServer(questID)
    if xp or money then
        cache()[questID] = { xp = xp, money = money, level = GP.Player().level }
        if XP.waiting and XP.waiting[questID] then
            XP.waiting[questID] = nil
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. (L("Quest %d from the server: %s, money %s."):format(questID,
                    XP.Text(xp) or "-", GetCoinTextureString and GetCoinTextureString(money or 0) or tostring(money))))
            end
        end
        if GP.ScheduleRefresh then GP.ScheduleRefresh() end
    end
end)

-- /gpp ep <questID>: test whether the server answers for a quest.
function XP.Test(questID)
    XP.waiting = XP.waiting or {}
    XP.waiting[questID] = true
    local say = function(text) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end end
    local xp, money = fromServer(questID)
    if xp or money then
        XP.waiting[questID] = nil
        cache()[questID] = { xp = xp, money = money, level = GP.Player().level }
        say((L("Quest %d from the server: %s, money %s."):format(questID, XP.Text(xp) or "-",
            GetCoinTextureString and GetCoinTextureString(money or 0) or tostring(money))))
        return
    end
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(questID) end
    local fallback = XP.Get(questID)
    say((L("Asked the server for quest %d. ForeverDB: %s."):format(questID, XP.Text(fallback.xp) or L("no value"))))
    if C_Timer then
        C_Timer.After(3, function()
            if XP.waiting[questID] then
                XP.waiting[questID] = nil
                say((L("No answer from the server for quest %d: GearPilot uses ForeverDB's values."):format(questID)))
            end
        end)
    end
end
