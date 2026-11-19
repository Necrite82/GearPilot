-- Waypoints to quest givers. With TomTom every step of a quest chain gets its own arrow; without it the game's
-- map waypoint points at the next open step and moves on by itself when a quest is accepted or turned in.
local _, GP = ...
local Route = {}
GP.Route = Route
local L = GP.L
local S = GP.Sources

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end

local function onQuest(id)
    return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false
end

-- One step of a chain: quest, giver name, giver spot.
function Route.Step(questID)
    local db = ForeverDB
    if not db then return nil end
    local quest = db.quest and db.quest[questID]
    local ref = db.qg and db.qg[questID] and db.qg[questID][1]
    local spot = S.Spot(db, ref)
    local uiMap, x, y = S.MapPoint(spot)
    return {
        id = questID, title = S.QuestTitle(questID, quest and quest[1] or ("#" .. questID)),
        level = quest and quest[2], giver = S.GiverName(db, ref), spot = spot, uiMap = uiMap, x = x, y = y,
        zone = S.MapName(uiMap), done = S.QuestDone(questID), active = onQuest(questID),
    }
end

function Route.Chain(questID)
    local steps = {}
    if not ForeverDB then return steps end
    for _, id in ipairs(S.Chain(ForeverDB, questID, UnitFactionGroup("player"))) do
        steps[#steps + 1] = Route.Step(id)
    end
    return steps
end

local function tomtom()
    return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
end

local function place(step)
    if not (step and step.uiMap and step.x) then return false end
    local title = step.title .. (step.giver and (" · " .. step.giver) or "")
    if tomtom() then
        pcall(TomTom.AddWaypoint, TomTom, step.uiMap, step.x, step.y,
            { title = title, from = "GearPilot", persistent = false, minimap = true, world = true })
        return true
    end
    if not (C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(step.uiMap)) then return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(step.uiMap, step.x, step.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    return true
end

local function describe(step)
    return ("%s · %s%s"):format(step.title, step.giver or "?", step.zone and (", " .. step.zone) or "")
end

-- Waypoint to the giver of one quest.
function Route.ToGiver(questID)
    Route.queue = nil
    local step = Route.Step(questID)
    if place(step) then
        say(L("Waypoint: ") .. describe(step))
    else
        say(L("No position known for this quest giver."))
    end
end

-- Whole chain: every open step (not done, not in the quest log).
function Route.ToChain(questID)
    local open = {}
    for _, step in ipairs(Route.Chain(questID)) do
        if not step.done and not step.active then open[#open + 1] = step end
    end
    if #open == 0 then
        say(L("Every quest of this chain is done or already in your quest log."))
        return
    end
    if tomtom() then
        local placed = 0
        for _, step in ipairs(open) do
            if place(step) then placed = placed + 1 end
        end
        say((L("%d waypoints set (TomTom)."):format(placed)))
        return
    end
    for i, step in ipairs(open) do step.index, step.total = i, #open end
    Route.queue = open
    Route.Next(true)
end

-- Several quests (a zone, a dungeon): every open quest giver, nearest first.
function Route.ToMany(questIDs)
    local open, seen = {}, {}
    for _, id in ipairs(questIDs) do
        if not seen[id] then
            seen[id] = true
            local step = Route.Step(id)
            if step and not step.done and not step.active then
                step.distance = S.Distance(step.spot) or math.huge
                open[#open + 1] = step
            end
        end
    end
    table.sort(open, function(a, b) return a.distance < b.distance end)
    if #open == 0 then
        say(L("Every quest of this chain is done or already in your quest log."))
        return
    end
    if tomtom() then
        local placed = 0
        for _, step in ipairs(open) do
            if place(step) then placed = placed + 1 end
        end
        say((L("%d waypoints set (TomTom)."):format(placed)))
        return
    end
    for i, step in ipairs(open) do step.index, step.total = i, #open end
    Route.queue = open
    Route.Next(true)
end

-- Waypoint to an NPC (a vendor).
function Route.ToNPC(ref, title)
    Route.queue = nil
    local spot = ForeverDB and S.Spot(ForeverDB, ref)
    local uiMap, x, y = S.MapPoint(spot)
    local step = { title = title, giver = S.GiverName(ForeverDB or {}, ref), uiMap = uiMap, x = x, y = y, zone = S.MapName(uiMap) }
    if place(step) then
        say(L("Waypoint: ") .. describe(step))
    else
        say(L("No position known for this quest giver."))
    end
end

-- Game waypoint: next open step of the queue.
function Route.Next(announce)
    local queue = Route.queue
    if not queue then return end
    while queue[1] and (S.QuestDone(queue[1].id) or onQuest(queue[1].id)) do table.remove(queue, 1) end
    local step = queue[1]
    if not step then
        Route.queue = nil
        say(L("Quest chain finished."))
        return
    end
    if place(step) then
        say((L("Step %d of %d: "):format(step.index, step.total)) .. describe(step))
    elseif announce then
        say(L("No position known for this quest giver.") .. " " .. describe(step))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function()
    if Route.queue then C_Timer.After(0.5, function() Route.Next(false) end) end
end)
