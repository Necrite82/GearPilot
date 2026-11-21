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
QR.DETOUR_MIN, QR.DETOUR_SHARE = 60, 0.3 -- yards / share of the way a task "on the way" may add
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
-- Spawns of a target near its first spot (at most 25, so ordering stays quick), and among them the one that
-- adds the least to the way from a to b (a creature on the way instead of the one at the giver).
local function nearbySpawns(db, ref, around)
    local spawns = type(ref) == "string" and db and db.spw and db.spw[ref]
    local list = {}
    for _, s in ipairs(spawns or {}) do
        if type(s[2]) == "number" then
            local p = { s[1], s[2], s[3] }
            if not around or p[1] == around[1] then list[#list + 1] = { p = p, d = around and distance(around, p) or 0 } end
        end
    end
    table.sort(list, function(x, y) return x.d < y.d end)
    local out = {}
    for i = 1, math.min(25, #list) do out[i] = list[i].p end
    return out
end
local function spotVia(spawns, a, b)
    local best, bestCost
    for _, p in ipairs(spawns) do
        local cost = distance(a, p) + (b and distance(p, b) or 0)
        if not best or cost < bestCost then best, bestCost = p, cost end
    end
    return best
end
QR.NearbySpawns, QR.SpotVia = nearbySpawns, spotVia

-- Places of every vendor of your faction that sells an item: { continent, y, x, vendorID }.
function QR.VendorSpots(db, itemID)
    local out = {}
    local faction = GP.Player and GP.Player().faction
    local function friendly(side)
        return not side or side == "" or not faction or side == "AH"
            or (faction == "Alliance" and side == "A") or (faction == "Horde" and side == "H")
    end
    -- 1.6.1: the full vendor lists (ForeverDB keeps at most 30 vendors per item, the nearest can be missing).
    local full = GP.QuestVendors and GP.QuestVendors[itemID]
    if type(full) == "table" then
        local sides = { [0] = "", [1] = "A", [2] = "H", [3] = "AH" }
        for i = 1, #full, 5 do
            if friendly(sides[full[i + 4]]) then out[#out + 1] = { full[i + 1], full[i + 2], full[i + 3], full[i] } end
        end
        return out
    end
    local vendors = db.vend and db.vend[itemID]
    if type(vendors) ~= "table" then return out end
    for _, npcID in ipairs(vendors) do
        local side = db.nfac and db.nfac[npcID]
        local friendly = not side or not faction or side == "AH"
            or (faction == "Alliance" and side == "A") or (faction == "Horde" and side == "H")
        if friendly then
            for _, s in ipairs(db.spw and db.spw["c" .. npcID] or {}) do
                if type(s[2]) == "number" then out[#out + 1] = { s[1], s[2], s[3], npcID } end
            end
        end
    end
    return out
end

-- Objectives with a known place: creatures (qx[8]), objects (qx[9]) and items (qx[10], from who drops them).
local function objectives(db, questID, near)
    local detail = db.qx and db.qx[questID] or {}
    local out = {}
    local function add(ref, label, itemID, npcID)
        local p = spot(db, ref, near)
        if p and #out < 4 then out[#out + 1] = { p = p, label = label, item = itemID, npc = npcID, ref = ref } end
    end
    for _, npcID in ipairs(type(detail[8]) == "table" and detail[8] or {}) do
        local npc = db.npc and db.npc[npcID]
        add("c" .. npcID, npc and npc[1], nil, npcID)
    end
    for _, objectID in ipairs(type(detail[9]) == "table" and detail[9] or {}) do
        local object = db.obj and db.obj[objectID]
        add("o" .. objectID, object and object[1])
    end
    for _, itemID in ipairs(type(detail[10]) == "table" and detail[10] or {}) do
        -- 1.6.0: an item a vendor of your faction sells is bought, not farmed: every vendor's place counts, the
        -- route takes the one nearest to its way. The vendor's ID rides along as p[4].
        local spots = QR.VendorSpots(db, itemID)
        local item = db.item and db.item[itemID]
        if #spots > 0 and #out < 4 then
            local best, bestDistance
            for _, p in ipairs(spots) do
                local d = near and distance(near, p) or 0
                if not best or d < bestDistance then best, bestDistance = p, d end
            end
            out[#out + 1] = { p = best, label = item and item[1], item = itemID, buy = true, spots = spots }
        end
        local drops = #spots == 0 and db.drop and db.drop[itemID] or {}
        local npcID, chance = nil, -1
        for i = 1, #drops, 2 do
            if (drops[i + 1] or 0) > chance then npcID, chance = drops[i], drops[i + 1] or 0 end
        end
        if npcID then add("c" .. npcID, item and item[1], itemID) end
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

-- Escort quests: ForeverDB marks them with the party-accept flag (qx[12] bit 2) and the event flag (qx[13] bit 2).
local function bit2(value) return math.floor((tonumber(value) or 0) / 2) % 2 == 1 end
function QR.IsEscort(db, id)
    local detail = db and db.qx and db.qx[id]
    return type(detail) == "table" and bit2(detail[12]) and bit2(detail[13]) or false
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
                    escort = QR.IsEscort(db, id), skipped = ctx.skip and ctx.skip(id) or false,
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
function QR.Order(quests, position, complete, rank)
    local db = ForeverDB
    -- 1.5.0: your own order (rank by quest): the ready step of the highest quest comes first; quests you have not
    -- placed follow after them, nearest first.
    local ranked = type(rank) == "table" and next(rank) ~= nil
    local tasks = {}
    for _, q in ipairs(quests) do
        local accepted = q.active
        if not accepted and q.giver then
            tasks[#tasks + 1] = { kind = "accept", quest = q, p = q.giver }
        end
        if not (complete and complete(q.id)) then
            for _, o in ipairs(q.objectives) do
                tasks[#tasks + 1] = { kind = "objective", quest = q, p = o.p, label = o.label, item = o.item, npc = o.npc, ref = o.ref,
                    buy = o.buy, spots = o.spots }
            end
        end
        tasks[#tasks + 1] = { kind = "turnin", quest = q, p = q.ender }
    end
    for _, t in ipairs(tasks) do
        if t.kind == "objective" and t.spots then
            -- 1.6.1: buying: the vendor nearest to where you are now (not to where the route would be by then).
            t.p = spotVia(t.spots, position) or t.p
        elseif t.kind == "objective" and t.ref then
            t.spawns = nearbySpawns(db, t.ref, t.p)
            if #t.spawns == 0 then t.spawns = nil end
        end
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
        local pick, pickDistance, pickPoint, pickRank
        for i, t in ipairs(tasks) do
            if not used[i] then
                local ready = t.kind == "accept" or (t.kind == "objective" and accepted[t.quest.id])
                    or (t.kind == "turnin" and accepted[t.quest.id] and open[t.quest.id] == 0
                        and not (deferred[t.quest.id] and others(i)))
                if ready then
                    -- Objectives: the spawn nearest to where you are now, not the one next to the giver.
                    local p = t.spawns and spotVia(t.spawns, here) or t.p
                    local d = distance(here, p)
                    local r = ranked and (rank[t.quest.id] or math.huge) or 0
                    if not pick or r < pickRank or (r == pickRank and d < pickDistance) then
                        pick, pickDistance, pickPoint, pickRank = i, d, p, r
                    end
                end
            end
        end
        if not pick then break end
        -- 1.4.0: objectives and turn-ins of quests you already have that lie on the way to that step come first,
        -- so you do them in passing instead of walking past them.
        local share = GP.settings and GP.settings.routeDetour or QR.DETOUR_SHARE
        local limit = (share > 0 and not (ranked and pickRank < math.huge)) and math.max(QR.DETOUR_MIN, pickDistance * share) or -1
        local onWay, onWayDistance, onWayPoint
        for i, t in ipairs(tasks) do
            if not used[i] and i ~= pick and t.p and (t.kind == "objective" or t.kind == "turnin") then
                local ready = accepted[t.quest.id] and (t.kind == "objective" or (open[t.quest.id] == 0
                    and not (deferred[t.quest.id] and others(i))))
                if ready then
                    local p = t.spawns and spotVia(t.spawns, here, pickPoint) or t.p
                    local d = distance(here, p)
                    local detour = d + distance(p, pickPoint) - pickDistance
                    if detour <= limit and (not onWay or d < onWayDistance) then onWay, onWayDistance, onWayPoint = i, d, p end
                end
            end
        end
        if onWay then pick, pickPoint = onWay, onWayPoint end
        local t = tasks[pick]
        t.p = pickPoint or t.p
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
    -- Skipped quests and (when hidden) escort quests stay out; the picker still lists them.
    local usable = {}
    for _, q in ipairs(candidates) do
        if not q.skipped and not (ctx.hideEscort and q.escort and not q.active) then usable[#usable + 1] = q end
    end
    local zones = QR.Zones(usable, ctx.position)
    if ctx.mine then
        -- My route: only the quests you picked (and the follow-ups of picked quests you have done).
        local byID = {}
        for _, q in ipairs(usable) do byID[q.id] = q end
        for id in pairs(ctx.mine) do
            if ctx.done(id) then
                for _, child in ipairs(QR.children and QR.children[id] or {}) do
                    if byID[child] then ctx.mine[child] = true end
                end
            end
        end
        local quests, xp = {}, 0
        for _, q in ipairs(usable) do
            if ctx.mine[q.id] then quests[#quests + 1] = q; xp = xp + q.xp end
        end
        table.sort(quests, function(a, b) return a.value > b.value end)
        return { mine = true, zones = zones, recommended = zones[1], quests = quests, xp = xp, candidates = candidates,
            tasks = QR.Order(quests, ctx.position, ctx.complete, ctx.rank) }
    end
    local zone = zones[1]
    if ctx.zone then
        zone = nil
        for _, option in ipairs(zones) do
            if option.zone == ctx.zone then zone = option; break end
        end
        if not zone then
            local name = db.area and db.area[ctx.zone] and db.area[ctx.zone][1]
            zone = { zone = ctx.zone, name = QR.AreaName(ctx.zone, name), quests = {} }
        end
    end
    local focused
    if ctx.focusedQuest then
        for _, candidateZone in ipairs(ctx.zone and { zone } or zones) do
            for _, quest in ipairs(candidateZone.quests) do
                if quest.id == ctx.focusedQuest then zone, focused = candidateZone, quest; break end
            end
            if focused then break end
        end
    end
    if not zone then return { zones = zones, tasks = {}, quests = {}, xp = 0, candidates = candidates } end
    local quests = {}
    for _, q in ipairs(zone.quests) do quests[#quests + 1] = q end
    table.sort(quests, function(a, b) return a.value > b.value end)
    while #quests > QR.MAX_QUESTS do
        local index = quests[#quests] == focused and #quests - 1 or #quests
        table.remove(quests, index)
    end
    local xp = 0
    for _, q in ipairs(quests) do xp = xp + q.xp end
    local nextZone
    if not ctx.zone then
        if zone == zones[1] then nextZone = zones[2] else nextZone = zones[1] end
    end
    return { zone = zone, zones = zones, chosenZone = ctx.zone, recommended = zones[1], quests = quests, xp = xp,
        next = nextZone, candidates = candidates,
        tasks = QR.Order(quests, ctx.position, ctx.complete, ctx.rank) }
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
    return best and best[1] or nil, bestDistance, best
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
    local s = GP.settings
    local profileKey = GP.Planner.Signature(GP.ActiveProfile())
    if QR.profileKey ~= profileKey then
        QR.profileKey = profileKey
        QR.own = nil
        QR.Invalidate()
    end
    -- A changed route setting (focus, dungeon or escort quests, automatic or your own) means a new plan.
    local key = table.concat({ tostring(s.routeFocus), tostring(s.routeDungeon), tostring(s.routeEscort), tostring(s.routeMode),
        tostring(s.routeDetour), tostring(s.routeZone) }, ":")
    if QR.plan and QR.planKey == key then return QR.plan end
    QR.planKey = key
    local player = GP.Player()
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
        skip = function(id) return s.routeSkip and s.routeSkip[id] == true end,
        hideEscort = s.routeEscort ~= true,
        mine = s.routeMode == "mine" and s.routeMine or nil,
        zone = s.routeZone,
        rank = QR.Rank(),
        focusedQuest = QR.following and QR.currentKey and QR.current and not QR.TaskDone(QR.current) and QR.current.quest.id,
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
    -- Zone names in your language.
    for _, zone in ipairs(QR.plan.zones or {}) do
        zone.name = QR.AreaName(zone.zone, zone.name)
        for _, q in ipairs(zone.quests) do q.zoneName = zone.name end
    end
    -- Ask the server for the experience of the planned quests (the plan refreshes when answers come).
    local ids = {}
    for _, q in ipairs(QR.plan.quests) do ids[#ids + 1] = q.id end
    GP.QuestXP.Request(ids)
    return QR.plan
end
function QR.Invalidate() QR.plan = nil end

-- 1.5.0: skip, your own order and your own route (all per character).
local function store()
    local s = GP.settings
    s.routeSkip = type(s.routeSkip) == "table" and s.routeSkip or {}
    s.routeOrder = type(s.routeOrder) == "table" and s.routeOrder or {}
    s.routeMine = type(s.routeMine) == "table" and s.routeMine or {}
    return s
end
QR.Store = store
local function changed()
    QR.Invalidate()
    if QR.following then
        QR.Follow(true, true)
    end
    if GP.ScheduleRefresh then GP.ScheduleRefresh() end
    if GP.Tracker then GP.Tracker.Refresh() end
end
function QR.Rank()
    local s = GP.settings
    local rank = {}
    for i, id in ipairs(type(s.routeOrder) == "table" and s.routeOrder or {}) do rank[id] = i end
    return rank
end
function QR.Skip(id, on)
    local s = store()
    s.routeSkip[id] = on ~= false or nil
    changed()
end
function QR.Skipped()
    local list = {}
    for id in pairs(store().routeSkip) do list[#list + 1] = id end
    table.sort(list)
    return list
end
function QR.Ordered() return #store().routeOrder > 0 end
-- Moves a quest one place up (-1) or down (1). The first move takes the current order as your own.
function QR.Move(id, direction)
    local s = store()
    local order = s.routeOrder
    if #order == 0 then
        local seen = {}
        for _, t in ipairs(QR.plan and QR.plan.tasks or {}) do
            if not seen[t.quest.id] and not QR.TaskDone(t) then seen[t.quest.id] = true; order[#order + 1] = t.quest.id end
        end
    end
    local index
    for i, other in ipairs(order) do if other == id then index = i end end
    if not index then order[#order + 1] = id; index = #order end
    local target = index + direction
    if target < 1 or target > #order then return end
    order[index], order[target] = order[target], order[index]
    changed()
end
function QR.ResetOrder()
    store().routeOrder = {}
    changed()
end
function QR.InMine(id) return store().routeMine[id] == true end
function QR.SetMine(id, on)
    local s = store()
    s.routeMine[id] = on and true or nil
    changed()
end
function QR.SetMode(mode)
    local s = store()
    s.routeMode = mode
    s.routeZone = nil
    changed()
end

function QR.SetZone(areaID)
    local s = store()
    s.routeMode = "auto"
    s.routeZone = areaID
    changed()
end

-- Include known quest areas even when there is nothing suitable at the current level.
function QR.ZoneChoices(db, plan)
    local choices, byID = {}, {}
    for _, zone in ipairs(plan.zones) do
        if type(zone.zone) == "number" and zone.zone > 0 then
            local choice = { id = zone.zone, name = zone.name, count = #zone.quests, xp = zone.xp }
            choices[#choices + 1] = choice
            byID[choice.id] = true
        end
    end
    for _, detail in pairs(db.qx or {}) do
        local id = detail[11]
        local area = id and db.area and db.area[id]
        if type(id) == "number" and id > 0 and area and not byID[id] and not (db.dng and db.dng[id]) then
            byID[id] = true
            choices[#choices + 1] = { id = id, name = QR.AreaName(id, area[1]), count = 0, xp = 0 }
        end
    end
    table.sort(choices, function(a, b)
        if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
        local an, bn = a.name or "", b.name or ""
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return choices
end

-- A task is done when its quest moved past it.
-- Progress of an objective from your quest log: true/false when an objective of the quest names this target,
-- nil when the quest is not in your log or no objective matches. Proximity is displayed separately.
function QR.ObjectiveState(t)
    if not (GP.QuestInfo and onQuest(t.quest.id)) then return nil end
    local names = {}
    if t.item and GP.ItemData then names[#names + 1] = GP.ItemData(t.item).name end
    if t.npc and GP.Names then names[#names + 1] = GP.Names.Get(t.npc) end
    names[#names + 1] = t.label
    for _, o in ipairs(GP.QuestInfo.Objectives(t.quest.id)) do
        for _, name in ipairs(names) do
            if type(name) == "string" and name ~= "" and o.text:find(name, 1, true) then return o.finished == true, o end
        end
    end
    return nil
end

-- A task keeps its key when the plan is built again (new tables after every quest log update).
function QR.TaskKey(t)
    if not t then return nil end
    return t.kind .. ":" .. t.quest.id .. ":" .. tostring(t.item or t.ref or t.npc or t.label or "")
end
QR.reached = {}
function QR.TaskDone(t)
    local id = t.quest.id
    if GP.Sources.QuestDone(id) then return true end
    if t.kind == "accept" then return onQuest(id) end
    if t.kind == "objective" then
        if complete(id) then return true end
        if t.buy then
            local have, need = QR.BuyProgress(t)
            if need then return have >= need end
        end
        -- 1.5.1: a quest in your log tells its progress; reaching the place only counts where it does not.
        local state = QR.ObjectiveState(t)
        if state ~= nil then return state end
        return false
    end
    return false
end

-- Map point of a task (zone map coordinates for waypoints and the map window).
function QR.MapPoint(t)
    if not t.p then return nil end
    return GP.Sources.MapPoint({ world = true, map = t.p[1], x = t.p[2], y = t.p[3] })
end

-- Zone name in your language: the game's name of the area, ForeverDB's English one as fallback.
function QR.AreaName(areaID, fallback)
    if areaID and C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, areaID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return fallback
end
-- Flight point name in your language: the game's flight point at that place on the zone map.
function QR.FlightName(node)
    if not node then return nil end
    local uiMap, x, y = GP.Sources.MapPoint({ world = true, map = node[2], x = node[3], y = node[4] })
    if uiMap and x and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, uiMap)
        local best, bestDistance
        for _, info in ipairs(ok and type(nodes) == "table" and nodes or {}) do
            local pos = info.position
            if pos and info.name then
                local d = (pos.x - x) ^ 2 + (pos.y - y) ^ 2
                if not best or d < bestDistance then best, bestDistance = info.name, d end
            end
        end
        if best and bestDistance < 0.0025 then return best end
    end
    return node[1]
end

-- Quest title in your language (the game's), ForeverDB's English one until the game has it.
function QR.Title(q)
    return GP.Sources.QuestTitle(q.id, q.title) or q.title or ("#" .. q.id)
end

-- Text of a task: "Accept", "Objective: Kobold Vermin", "Turn in".
function QR.TaskText(t)
    if t.kind == "accept" then return L("Accept") end
    if t.kind == "objective" then
        -- Quest items by the game's (local) name; creatures and objects as ForeverDB names them.
        local label = t.label
        if t.npc and GP.Names then label = GP.Names.Get(t.npc) or label end
        if t.item and GP.ItemData then
            local item = GP.ItemData(t.item)
            if item and item.name then label = item.name end
        end
        if t.buy then
            -- "Buy: Fine Spice 1/3 · Krinkle Goodsteel"
            local have, need = QR.BuyProgress(t)
            local count = need and ((" %d/%d"):format(math.min(have, need), need)) or (have > 0 and (" · " .. (L("%d in bags"):format(have))) or "")
            local vendor = QR.VendorName(t)
            return L("Buy") .. ": " .. (label or "?") .. count .. (vendor and (" · " .. vendor) or "")
        end
        local arrived = QR.reached[QR.TaskKey(t)] and (" · " .. L("Location reached")) or ""
        return L("Objective") .. (label and (": " .. label) or "") .. arrived
    end
    return L("Turn in")
end

-- Bought quest items: how many you have and how many the quest wants (known once the quest is in your log).
function QR.TrackerAction(t)
    if t.kind == "accept" or t.kind == "turnin" then
        local ref = t.kind == "accept" and t.quest.giverRef or t.quest.enderRef or t.quest.giverRef
        local npc = ForeverDB and ref and GP.Sources.GiverName(ForeverDB, ref)
        if npc then
            return (L(t.kind == "accept" and "Accept from %s" or "Turn in to %s")):format(npc)
        end
    elseif not t.buy then
        local _, objective = QR.ObjectiveState(t)
        if objective and type(objective.numRequired) == "number" and objective.numRequired > 0
            and type(objective.numFulfilled) == "number" then
            return (L("%d of %d left · %s")):format(math.max(0, objective.numRequired - objective.numFulfilled),
                objective.numRequired, QR.TaskText(t))
        end
    end
    return QR.TaskText(t)
end

function QR.BuyProgress(t)
    local have = GetItemCount and t.item and (GetItemCount(t.item) or 0) or 0
    local need
    local name = t.item and GP.ItemData and GP.ItemData(t.item).name
    if GP.QuestInfo and name then
        for _, o in ipairs(GP.QuestInfo.Objectives(t.quest.id)) do
            if type(o.text) == "string" and o.text:find(name, 1, true) and type(o.numRequired) == "number" and o.numRequired > 0 then
                need = o.numRequired
                if type(o.numFulfilled) == "number" then have = math.max(have, o.numFulfilled) end
            end
        end
    end
    return have, need
end
function QR.VendorName(t)
    local npcID = t.p and t.p[4]
    if not npcID then return nil end
    local db = ForeverDB
    return (GP.Names and GP.Names.Get(npcID)) or (db and db.npc and db.npc[npcID] and db.npc[npcID][1]) or nil
end

-- Follow the current open step until the quest log confirms progress.
local function say(text) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end end
-- Open steps in order. A turn-in whose quest is in your log but not complete waits at the end: you are not
-- sent to turn in before the objectives are done.
function QR.Blocked(t)
    return t.kind == "turnin" and onQuest(t.quest.id) and not complete(t.quest.id)
end
local function canTrack(t)
    return t.kind == "accept" or onQuest(t.quest.id)
end
function QR.OpenTasks(plan)
    local open, waiting = {}, {}
    local tracked
    for i, t in ipairs(plan and plan.tasks or {}) do
        if not QR.TaskDone(t) then
            local entry = { t = t, index = i }
            if QR.Blocked(t) then waiting[#waiting + 1] = entry
            elseif QR.following and canTrack(t) and QR.TaskKey(t) == QR.currentKey then tracked = entry
            else open[#open + 1] = entry end
        end
    end
    if tracked then table.insert(open, 1, tracked) end
    for _, entry in ipairs(waiting) do open[#open + 1] = entry end
    return open
end
function QR.NextTask(preferredKey)
    -- Same order as OpenTasks, without building the list (called every second while following).
    local plan = QR.Current()
    local keep = preferredKey or (QR.following and QR.currentKey)
    local first, firstIndex, waiting, waitingIndex
    for i, t in ipairs(plan and plan.tasks or {}) do
        if not QR.TaskDone(t) then
            if not QR.Blocked(t) then
                if not keep or (canTrack(t) and QR.TaskKey(t) == keep) then return t, i end
                if not first then first, firstIndex = t, i end
            elseif not waiting then
                waiting, waitingIndex = t, i
            end
        end
    end
    if first then return first, firstIndex end
    return waiting, waitingIndex
end
-- 1.4.0: the route's previous TomTom point goes when the next step starts (or the route stops); the game's own
-- waypoint is replaced anyway.
function QR.ClearTomTom()
    if QR.tomtom and type(TomTom) == "table" and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, QR.tomtom) end
    QR.tomtom = nil
end
function QR.Follow(on, force, preferredKey)
    QR.following = on
    if not on or force then QR.currentKey = nil end
    if not on then
        QR.current = nil
        if GP.Tracker and GP.Tracker.Refresh then GP.Tracker.Refresh() end
        QR.ClearTomTom()
        if QR.ownWaypoint and C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
        QR.ownWaypoint = false
        return
    end
    local t, i = QR.NextTask(preferredKey)
    if not t then
        local plan = QR.Current()
        say(plan and plan.chosenZone and L("No matching open quests in your chosen zone. Choose another zone or use the recommendation.")
            or L("Quest route: nothing left here. Open the route for the next zone."))
        QR.Follow(false)
        return
    end
    -- 1.4.0: only a new step sets the waypoint and writes to the chat (the plan is rebuilt on every quest log
    -- update, which used to repeat the same line again and again).
    local key = QR.TaskKey(t)
    local changed = key ~= QR.currentKey
    QR.current, QR.currentKey = t, key
    if GP.Tracker and GP.Tracker.Refresh then GP.Tracker.Refresh() end
    if not changed then return end
    local uiMap, x, y = QR.MapPoint(t)
    if uiMap and x and C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(uiMap) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(uiMap, x, y))
        QR.ownWaypoint = true
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    QR.ClearTomTom()
    if type(TomTom) == "table" and TomTom.AddWaypoint and uiMap and x then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, uiMap, x, y, { title = QR.Title(t.quest) .. " · " .. QR.TaskText(t), from = "GearPilot", persistent = false })
        if ok then QR.tomtom = uid end
    end
    -- With the tracker open the step is there already; the chat line is only for players without it.
    if not (GP.Tracker and GP.Tracker.IsShown()) then
        say((L("Quest route %d of %d: "):format(i, #QR.Current().tasks)) .. QR.Title(t.quest) .. " · " .. QR.TaskText(t))
    end
end

local events = CreateFrame("Frame")
-- Your quest log in short: which quests, which complete. QUEST_LOG_UPDATE comes with every kill or loot; the plan is
-- only built again when this changes (1.6.2: less work and garbage while questing).
local function logSignature()
    local parts = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
            local info = C_QuestLog.GetInfo(i)
            if type(info) == "table" and not info.isHeader and info.questID then
                parts[#parts + 1] = info.questID .. (complete(info.questID) and "+" or "")
            end
        end
    end
    return table.concat(parts, ",")
end
for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED" }) do
    events:RegisterEvent(event)
end
local pendingUpdate = false
events:SetScript("OnEvent", function(_, event)
    if event == "ITEM_DATA_LOAD_RESULT" and not QR.loading then return end
    if event == "ITEM_DATA_LOAD_RESULT" or event == "PLAYER_LEVEL_UP" or event == "PLAYER_EQUIPMENT_CHANGED" then QR.own = nil end
    -- Bags: a bought quest item finishes its step; the plan itself stays.
    if event == "QUEST_LOG_UPDATE" then
        local signature = logSignature()
        if signature ~= QR.logSignature then QR.logSignature = signature; QR.Invalidate() end
    elseif event ~= "BAG_UPDATE_DELAYED" then
        QR.Invalidate()
    end
    if pendingUpdate or not C_Timer then return end
    pendingUpdate = true
    C_Timer.After(0.6, function()
        pendingUpdate = false
        if QR.following then
            local t = QR.NextTask()
            if QR.TaskKey(t) ~= QR.currentKey then QR.Follow(true) end
        end
        if GP.ScheduleRefresh then GP.ScheduleRefresh() end
    end)
end)
-- Reaching the coordinates says where you are; only quest progress completes the objective.
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 1 or not QR.following then return end
    elapsed = 0
    local t = QR.current
    if t and t.kind == "objective" and not QR.reached[QR.TaskKey(t)] and not t.buy then
        local here = QR.Position()
        if here and distance(here, t.p) < 40 then
            QR.reached[QR.TaskKey(t)] = true
            if GP.Tracker then GP.Tracker.Refresh() end
            if GP.ScheduleRefresh then GP.ScheduleRefresh() end
        end
    end
    -- 1.6.0: the next step changed without a quest event (your own order, skip, my route, a route setting):
    -- the waypoint follows at once instead of pointing to the old step.
    local nextTask = QR.NextTask()
    if QR.TaskKey(nextTask) ~= QR.currentKey then QR.Follow(true) end
end)
