-- Dungeons to go: your own list of dungeons to run, in your order, with run count and preparation.
-- Saved per character in GearPilotProSettings.togo as { { name, runs, added } }.
local _, GP = ...
local L = GP.L
local Togo = {}
GP.Togo = Togo

local function list() return GP.settings and GP.settings.togo or {} end
Togo.List = list

local function index(name)
    for i, entry in ipairs(list()) do
        if entry.name == name then return i end
    end
    return nil
end
function Togo.Has(name) return index(name) ~= nil end
function Togo.Get(name)
    local i = index(name)
    return i and list()[i] or nil
end
function Togo.Add(name)
    if not name or index(name) then return end
    table.insert(list(), { name = name, runs = 0, added = time and time() or 0 })
end
function Togo.Remove(name)
    local i = index(name)
    if i then table.remove(list(), i) end
end
function Togo.Toggle(name)
    if index(name) then Togo.Remove(name) else Togo.Add(name) end
    if GP.Render then GP.Render() end
end
-- Moves a dungeon up (-1) or down (+1) in your order.
function Togo.Move(name, delta)
    local items = list()
    local i = index(name)
    local j = i and i + delta
    if not i or j < 1 or j > #items then return end
    items[i], items[j] = items[j], items[i]
    if GP.Render then GP.Render() end
end

-- Open quests of a dungeon for you (catalog entry d): quests for your race and class, not done.
-- Returns the quest infos (Sources.DungeonQuest) with done/active flags, and the number still open.
function Togo.Quests(d)
    local db = ForeverDB
    local out, open = {}, 0
    if not (db and d) then return out, 0 end
    local player = GP.Player()
    local options = { class = player.class, faction = player.faction, raceBit = player.raceBit }
    for _, id in ipairs(d.quests or {}) do
        local info = GP.Sources.DungeonQuest(db, id, options, d.quests)
        if info then
            info.done = GP.Sources.QuestDone(id)
            info.active = C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) or false
            if not info.done then open = open + 1 end
            out[#out + 1] = info
        end
    end
    table.sort(out, function(a, b)
        if a.done ~= b.done then return not a.done end
        return (a.level or 0) < (b.level or 0)
    end)
    return out, open
end

-- Next step to take for each open quest: the first open step of its chain (pre-quests first).
function Togo.NextSteps(quests)
    local ids, seen = {}, {}
    for _, info in ipairs(quests) do
        if not info.done and not info.active then
            local chain = GP.Route.Chain(info.id)
            local _, nextIndex = GP.Planner.ChainStatus(chain)
            local step = nextIndex and chain[nextIndex]
            local id = step and step.id or info.id
            if not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

-- Waypoints to every quest giver you need before the run(s), nearest first.
function Togo.Prepare(dungeons)
    local ids, seen = {}, {}
    for _, d in ipairs(dungeons) do
        local quests = Togo.Quests(d)
        local steps = Togo.NextSteps(quests)
        -- 1.6.1: the next step of an open access chain (Drakefire Amulet, dungeon keys) comes along.
        for _, id in ipairs(GP.Access and GP.Access.NextSteps(d.name) or {}) do steps[#steps + 1] = id end
        for _, id in ipairs(steps) do
            if not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        end
    end
    if #ids == 0 then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. L("Nothing to prepare: every quest is done or in your quest log."))
        end
        return
    end
    GP.Route.ToMany(ids)
end

-- Wishlist items that drop in a dungeon (catalog entry d) and are not received yet.
function Togo.WishItems(d)
    local out = {}
    if not (d and GP.Wish) then return out end
    local wishes = GP.Wish.List()
    for _, boss in ipairs(d.bosses or {}) do
        for _, id in ipairs(boss.items or {}) do
            local wish = wishes[id]
            if wish and not wish.got then out[#out + 1] = id end
        end
    end
    return out
end

-- Runs: entering a dungeon of the list counts one run (once per entry, not on reloads inside).
local lastInstance
local function entered()
    if not (GP.settings and GetInstanceInfo) then return end
    local _, kind, _, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then
        lastInstance = nil
        return
    end
    if not instanceID or instanceID == lastInstance then return end
    lastInstance = instanceID
    local catalog = GP.Catalog and GP.Catalog() or {}
    for _, d in ipairs(catalog) do
        if d.mapID == instanceID then
            local entry = Togo.Get(d.name)
            if entry then
                entry.runs = (entry.runs or 0) + 1
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. (L("To go: %s, run %d."):format(GP.Sources.DungeonName(d), entry.runs)))
                end
            end
            return
        end
    end
end

-- Done: every quest done and every wishlist item received, after at least one run.
function Togo.Finished(d)
    local entry = Togo.Get(d.name)
    if not entry or (entry.runs or 0) == 0 then return false end
    local _, open = Togo.Quests(d)
    return open == 0 and #Togo.WishItems(d) == 0
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    if C_Timer then C_Timer.After(2, entered) else entered() end
end)
