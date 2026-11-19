-- Quest route: the quests worth doing at your level (experience plus the upgrade value of their rewards), the
-- zone that pays most for the way there, and an order to do them in: accept, objectives, turn in, nearest
-- first. It follows your level: new quests come in, grey ones go, and when a zone runs dry the next one comes.
--
-- The planning is plain Lua on world coordinates (ForeverDB spawns: continent, x, y), so tests run it outside
-- the game. QR.Plan(db, ctx) -> plan; the game side (QR.Current, QR.Follow) wraps it.
local _, GP = ...
local L = GP.L
local QR = {}
GP.QuestRoute = QR

-- How much one score point of an upgrade is worth in experience, by focus.
QR.focus = { xp = 0, balanced = 100, gear = 400 }
QR.MAX_QUESTS = 20
QR.OTHER_CONTINENT = 8000 -- yards a continent change counts as

local function distance(a, b)
    if not (a and b) then return math.huge end
    if a[1] ~= b[1] then return QR.OTHER_CONTINENT + 3000 end
    return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end
QR.Distance = distance

-- World spot of a ForeverDB reference ("c123" creature, "o45" object): the spawn nearest to near.
local function spot(db, ref, near)
    local spawns = type(ref) == "string" and db.spw and db.spw[ref]
    local best, bestDistance
    for _, s in ipairs(spawns or {}) do
        if type(s[2]) == "number" then
            local p = { s[1], s[2], s[3] }
            local d = near and distance(near, p) or 0
            if not best or d < bestDistance then best, bestDistance = p, d end
        end
    end
    return best
end
QR.Spot = spot

-- Objectives with a known place: creatures (qx[8]), objects (qx[9]) and items (qx[10], from who drops them).
local function objectives(db, questID, near)
    local detail = db.qx and db.qx[questID] or {}
    local out = {}
    local function add(ref, label)
        local p = spot(db, ref, near)
        if p and #out < 4 then out[#out + 1] = { p = p, label = label } end
    end
    for _, npcID in ipairs(type(detail[8]) == "table" and detail[8] or {}) do
        local npc = db.npc and db.npc[npcID]
        add("c" .. npcID, npc and npc[1])
    end
    for _, objectID in ipairs(type(detail[9]) == "table" and detail[9] or {}) do
        local object = db.obj and db.obj[objectID]
        add("o" .. objectID, object and object[1])
    end
    for _, itemID in ipairs(type(detail[10]) == "table" and detail[10] or {}) do
        local drops = db.drop and db.drop[itemID] or {}
        local npcID, chance = nil, -1
        for i = 1, #drops, 2 do
            if (drops[i + 1] or 0) > chance then npcID, chance = drops[i], drops[i + 1] or 0 end
        end
        local item = db.item and db.item[itemID]
        if npcID then add("c" .. npcID, item and item[1]) end
    end
    return out
end
QR.Objectives = objectives

-- A quest you can take now: for you (race, class), level, not grey, prerequisites done, not excluded.
local function available(db, id, ctx)
    local quest = db.quest and db.quest[id]
    if not quest then return false end
    local detail = db.qx and db.qx[id] or {}
    local S = GP.Sources
    if not S.RaceAllowed(detail[1], ctx.raceBit, ctx.faction) or not S.ClassAllowed(detail[2], ctx.class) then return false end
    local level, minLevel = quest[2] or 0, quest[3] or 0
    if minLevel > ctx.level or (level > 0 and level <= ctx.grey) or level > ctx.level + 3 then return false end
    local zone = detail[11]
    if type(zone) ~= "number" or zone <= 0 then return false end -- class, profession and holiday quests
    if not ctx.includeDungeon and db.dng and db.dng[zone] then return false end
    if type(detail[3]) == "table" and #detail[3] > 0 then
        local any = false
        for _, pre in ipairs(detail[3]) do if ctx.done(pre) then any = true end end
        if not any then return false end
    end
    for _, pre in ipairs(type(detail[4]) == "table" and detail[4] or {}) do
        if not ctx.done(pre) then return false end
    end
    for _, other in ipairs(type(detail[5]) == "table" and detail[5] or {}) do
        if ctx.done(other) or ctx.active(other) then return false end
    end
    return true
end
QR.Available = available

-- Follow-up quests: quest -> the quests that need it (from the prerequisites, qx[3] and qx[4]).
function QR.Children(db)
    local children = {}
    for id, detail in pairs(db.qx or {}) do
        for _, field in ipairs({ 3, 4 }) do
            for _, pre in ipairs(type(detail[field]) == "table" and detail[field] or {}) do
                children[pre] = children[pre] or {}
                table.insert(children[pre], id)
            end
        end
    end
    return children
end
-- The best reward on the way: the quest's own or one of its follow-ups (a chain's first quest leads to the
-- reward at its end). own(id) -> gain, item. Returns gain, item, quest that gives it.
function QR.ChainReward(children, id, own, depth, seen)
    depth, seen = depth or 0, seen or {}
    if seen[id] or depth > 8 then return 0 end
    seen[id] = true
    local bestGain, bestItem, bestQuest = own(id)
    bestGain = bestGain or 0
    if bestGain > 0 then bestQuest = id end
    for _, child in ipairs(children[id] or {}) do
        local gain, item, quest = QR.ChainReward(children, child, own, depth + 1, seen)
        if gain > bestGain then bestGain, bestItem, bestQuest = gain, item, quest end
    end
    return bestGain, bestItem, bestQuest
end

-- Quests worth doing now: available or in your log, with giver, turn-in and objective places and a value.
function QR.Candidates(db, ctx)
    local list = {}
    for id, quest in pairs(db.quest or {}) do
        local active = ctx.active(id)
        if not ctx.done(id) and (active or available(db, id, ctx)) and not (ctx.replaced and ctx.replaced(id)) then
            local giverRef = db.qg and db.qg[id] and db.qg[id][1]
            local enderRef = db.qe and db.qe[id] and db.qe[id][1]
            local giver = spot(db, giverRef, ctx.position)
            local ender = spot(db, enderRef, giver or ctx.position) or giver
            if (giver or active) and ender then
                local xp = ctx.xp(id, quest[2]) or 0
                local gain, reward, rewardQuest = 0, nil, nil
                if ctx.gain then gain, reward, rewardQuest = ctx.gain(id) end
                gain = gain or 0
                local detail = db.qx and db.qx[id] or {}
                local zone = detail[11]
                list[#list + 1] = {
                    id = id, title = quest[1], level = quest[2], active = active, zone = zone,
                    zoneName = db.area and db.area[zone] and db.area[zone][1] or nil,
                    giver = giver, giverRef = giverRef, ender = ender, enderRef = enderRef,
                    objectives = objectives(db, id, giver or ender), xp = xp, gain = gain, reward = reward,
                    rewardQuest = rewardQuest ~= id and rewardQuest or nil,
                    value = xp + gain * (ctx.weight or QR.focus.balanced),
                }
            end
        end
    end
    return list
end

-- Zones by worth: the value of their quests over the way there (a zone you are in costs nothing).
function QR.Zones(candidates, position)
    local zones, order = {}, {}
    for _, q in ipairs(candidates) do
        local key = q.zone or 0
        local z = zones[key]
        if not z then
            z = { zone = key, name = q.zoneName, quests = {}, value = 0, xp = 0, sx = 0, sy = 0, n = 0 }
            zones[key] = z
            order[#order + 1] = z
        end
        z.quests[#z.quests + 1] = q
        z.value, z.xp = z.value + q.value, z.xp + q.xp
    end
    for _, z in ipairs(order) do
        -- The zone's continent: where most of its quest givers stand (some are given in a capital elsewhere).
        local count = {}
        for _, q in ipairs(z.quests) do
            local p = q.giver or q.ender
            if p then count[p[1]] = (count[p[1]] or 0) + 1 end
        end
        for continent, n in pairs(count) do
            if not z.continent or n > count[z.continent] then z.continent = continent end
        end
        for _, q in ipairs(z.quests) do
            local p = q.giver or q.ender
            if p and p[1] == z.continent then z.sx, z.sy, z.n = z.sx + p[2], z.sy + p[3], z.n + 1 end
        end
        z.center = z.n > 0 and { z.continent, z.sx / z.n, z.sy / z.n } or nil
        -- Nearest quest of the zone on its continent, not its center: a zone you stand in is close.
        local near = math.huge
        for _, q in ipairs(z.quests) do
            local p = q.giver or q.ender
            if p and p[1] == z.continent then near = math.min(near, distance(position, p)) end
        end
        z.distance = near
        z.score = z.value / (1 + z.distance / 1500)
    end
    table.sort(order, function(a, b) return a.score > b.score end)
    return order
end

-- Tasks of a zone in order: nearest first; a quest's objectives after accepting it, its turn-in after them.
-- A quest whose objectives are unknown and that you turn in where you took it is probably "go and do something":
-- its turn-in waits until the rest of the zone is done (or until the game says the quest is complete).
function QR.Order(quests, position, complete)
    local tasks = {}
    for _, q in ipairs(quests) do
        local accepted = q.active
        if not accepted and q.giver then
            tasks[#tasks + 1] = { kind = "accept", quest = q, p = q.giver }
        end
        if not (complete and complete(q.id)) then
            for _, o in ipairs(q.objectives) do
                tasks[#tasks + 1] = { kind = "objective", quest = q, p = o.p, label = o.label }
            end
        end
        tasks[#tasks + 1] = { kind = "turnin", quest = q, p = q.ender }
    end
    -- Ready: accept always; objectives once the quest is accepted; turn-in once its objectives are done.
    local accepted, open = {}, {}
    for _, q in ipairs(quests) do
        accepted[q.id] = q.active
        open[q.id] = 0
    end
    for _, t in ipairs(tasks) do
        if t.kind == "objective" then open[t.quest.id] = open[t.quest.id] + 1 end
    end
    local ordered, used, here = {}, {}, position
    local deferred = {}
    for _, q in ipairs(quests) do
        local unknown = #q.objectives == 0 and q.giverRef ~= nil and q.giverRef == q.enderRef
        deferred[q.id] = unknown and not (complete and complete(q.id))
    end
    local function others(i)
        for j, t in ipairs(tasks) do
            if not used[j] and j ~= i and not (t.kind == "turnin" and deferred[t.quest.id]) then return true end
        end
        return false
    end
    for _ = 1, #tasks do
        local pick, pickDistance
        for i, t in ipairs(tasks) do
            if not used[i] then
                local ready = t.kind == "accept" or (t.kind == "objective" and accepted[t.quest.id])
                    or (t.kind == "turnin" and accepted[t.quest.id] and open[t.quest.id] == 0
                        and not (deferred[t.quest.id] and others(i)))
                if ready then
                    local d = distance(here, t.p)
                    if not pick or d < pickDistance then pick, pickDistance = i, d end
                end
            end
        end
        if not pick then break end
        local t = tasks[pick]
        used[pick] = true
        ordered[#ordered + 1] = t
        here = t.p or here
        if t.kind == "accept" then accepted[t.quest.id] = true
        elseif t.kind == "objective" then open[t.quest.id] = open[t.quest.id] - 1 end
    end
    return ordered
end

-- The plan: the best zone, its best quests (at most MAX_QUESTS) in order, the next zone after it.
function QR.Plan(db, ctx)
    local candidates = QR.Candidates(db, ctx)
    local zones = QR.Zones(candidates, ctx.position)
    local zone = zones[1]
    if not zone then return { zones = zones, tasks = {}, quests = {}, xp = 0 } end
    local quests = {}
    for _, q in ipairs(zone.quests) do quests[#quests + 1] = q end
    table.sort(quests, function(a, b) return a.value > b.value end)
    while #quests > QR.MAX_QUESTS do table.remove(quests) end
    local xp = 0
    for _, q in ipairs(quests) do xp = xp + q.xp end
    return { zone = zone, zones = zones, quests = quests, xp = xp, next = zones[2],
        tasks = QR.Order(quests, ctx.position, ctx.complete) }
end

-- Nearest flight point of your faction (ForeverDB taxi: name, continent, x, y, z, flags, Horde, Alliance).
function QR.FlightPoint(db, p, faction)
    local best, bestDistance
    for _, node in pairs(db.taxi or {}) do
        local friendly = (faction == "Horde" and (node[7] or 0) ~= 0) or (faction == "Alliance" and (node[8] or 0) ~= 0)
        local name = tostring(node[1])
        if friendly and name:find(", ", 1, true) and not name:find("^Transport") and not name:find("^Quest") then
            local d = distance(p, { node[2], node[3], node[4] })
            if not best or d < bestDistance then best, bestDistance = node, d end
        end
    end
    return best and best[1] or nil, bestDistance
end

-- Game side ----------------------------------------------------------------------------------------------------
local function onQuest(id) return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false end
local function complete(id) return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) or false end
function QR.Position()
    if not UnitPosition then return nil end
    local y, x, _, instance = UnitPosition("player")
    if not y then return nil end
    return { instance, y, x }
end

-- Best reward of one quest for you (your class and gear): gain and item. Items still loading are counted
-- once they arrive (the plan is worked out again then).
local function rewardsOf()
    local player = GP.Player()
    local rows = GP.Sources.Rows(player.class, player.faction, GP.settings.minChance, player.raceBit) or {}
    local byQuest = {}
    for _, row in ipairs(rows) do
        if row.source == "Quests" then
            byQuest[row.sourceID] = byQuest[row.sourceID] or {}
            table.insert(byQuest[row.sourceID], row)
        end
    end
    local equipped = GP.ReadGear and GP.ReadGear() or {}
    local profile = GP.ActiveProfile()
    local cache = {}
    return function(id)
        if cache[id] then return cache[id][1], cache[id][2] end
        local bestGain, bestItem, complete = 0, nil, true
        for _, row in ipairs(byQuest[id] or {}) do
            local item = GP.ItemData(row.itemID)
            if item.name then
                -- Judged at the item's own level: a reward at the end of a chain may need a few more levels.
                local level = math.max(player.level, item.minLevel or 0)
                local result = GP.Planner.Compare(item, equipped, profile, player.class, level)
                if result and result.gain and result.gain > bestGain then bestGain, bestItem = result.gain, item end
            else
                complete = false
                QR.loading = true
            end
        end
        if complete then cache[id] = { bestGain, bestItem } end
        return bestGain, bestItem
    end
end

-- The current plan (cached until something changes).
function QR.Current()
    local db = ForeverDB
    if not db then return nil end
    if QR.plan then return QR.plan end
    local player = GP.Player()
    local s = GP.settings
    local twins = GP.Sources.Twins(db)
    QR.children = QR.children or QR.Children(db)
    -- Rewards are judged once and kept until your gear, your level or item data changes.
    if not QR.own then
        QR.loading = false
        QR.own = rewardsOf()
    end
    local own = QR.own
    local chainCache = {}
    local xpCache = {}
    local ctx = {
        class = player.class, faction = player.faction, raceBit = player.raceBit, level = player.level,
        grey = GP.Planner.GreyLevel(player.level), position = QR.Position(),
        done = GP.Sources.QuestDone, active = onQuest, complete = complete,
        includeDungeon = s.routeDungeon == true, weight = QR.focus[s.routeFocus or "balanced"] or QR.focus.balanced,
        xp = function(id, level)
            if xpCache[id] == nil then
                local value = GP.QuestXP.Get(id, level)
                xpCache[id] = value.xp or 0
            end
            return xpCache[id]
        end,
        gain = function(id)
            if not chainCache[id] then chainCache[id] = { QR.ChainReward(QR.children, id, own) } end
            return chainCache[id][1], chainCache[id][2], chainCache[id][3]
        end,
        -- A Classic quest whose Forever twin is in the database: only the twin counts.
        replaced = function(id)
            for _, twin in ipairs(twins[id] or {}) do
                if twin > id and db.quest[twin] then return true end
            end
            return false
        end,
    }
    QR.plan = QR.Plan(db, ctx)
    -- Ask the server for the experience of the planned quests (the plan refreshes when answers come).
    local ids = {}
    for _, q in ipairs(QR.plan.quests) do ids[#ids + 1] = q.id end
    GP.QuestXP.Request(ids)
    return QR.plan
end
function QR.Invalidate() QR.plan = nil end

-- A task is done when its quest moved past it.
function QR.TaskDone(t)
    local id = t.quest.id
    if GP.Sources.QuestDone(id) then return true end
    if t.kind == "accept" then return onQuest(id) end
    if t.kind == "objective" then return complete(id) or t.reached == true end
    return false
end

-- Map point of a task (zone map coordinates for waypoints and the map window).
function QR.MapPoint(t)
    if not t.p then return nil end
    return GP.Sources.MapPoint({ world = true, map = t.p[1], x = t.p[2], y = t.p[3] })
end

-- Quest title in your language (the game's), ForeverDB's English one until the game has it.
function QR.Title(q)
    return GP.Sources.QuestTitle(q.id, q.title) or q.title or ("#" .. q.id)
end

-- Text of a task: "Accept", "Objective: Kobold Vermin", "Turn in".
function QR.TaskText(t)
    if t.kind == "accept" then return L("Accept") end
    if t.kind == "objective" then return L("Objective") .. (t.label and (": " .. t.label) or "") end
    return L("Turn in")
end

-- Follow: waypoint to the next open task; moves on when a quest is accepted, completed or turned in, and when
-- you reach an objective's place.
local function say(text) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end end
function QR.NextTask()
    local plan = QR.Current()
    for i, t in ipairs(plan and plan.tasks or {}) do
        if not QR.TaskDone(t) then return t, i end
    end
    return nil
end
function QR.Follow(on)
    QR.following = on
    if not on then return end
    local t, i = QR.NextTask()
    if not t then
        say(L("Quest route: nothing left here. Open the route for the next zone."))
        QR.following = false
        return
    end
    local uiMap, x, y = QR.MapPoint(t)
    QR.current = t
    if uiMap and x and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(uiMap) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(uiMap, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    if type(TomTom) == "table" and TomTom.AddWaypoint and uiMap and x then
        pcall(TomTom.AddWaypoint, TomTom, uiMap, x, y, { title = QR.Title(t.quest) .. " · " .. QR.TaskText(t), from = "GearPilot", persistent = false })
    end
    say((L("Quest route %d of %d: "):format(i, #QR.Current().tasks)) .. QR.Title(t.quest) .. " · " .. QR.TaskText(t))
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT" }) do
    events:RegisterEvent(event)
end
local pendingUpdate = false
events:SetScript("OnEvent", function(_, event)
    if event == "ITEM_DATA_LOAD_RESULT" and not QR.loading then return end
    if event == "ITEM_DATA_LOAD_RESULT" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_EQUIPMENT_CHANGED" then QR.own = nil end
    QR.Invalidate()
    if pendingUpdate or not C_Timer then return end
    pendingUpdate = true
    C_Timer.After(0.6, function()
        pendingUpdate = false
        if QR.following then
            local t = QR.NextTask()
            if t ~= QR.current then QR.Follow(true) end
        end
        if GP.ScheduleRefresh then GP.ScheduleRefresh() end
    end)
end)
-- Reaching an objective's place counts it as reached (the game does not tell which objective belongs where).
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 1 or not QR.following then return end
    elapsed = 0
    local t = QR.current
    if t and t.kind == "objective" and not t.reached then
        local here = QR.Position()
        if here and distance(here, t.p) < 40 then
            t.reached = true
            QR.Follow(true)
        end
    end
end)
