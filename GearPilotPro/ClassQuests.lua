-- Class quests (1.7.0): every class quest chain from start to end, for your class or (to look at) another one.
-- A quest counts as a class quest when its class mask names one or two classes or when ForeverDB files it under
-- the class's quest category (some class quests are only limited by race). Chains whose quests fight creatures in
-- a dungeon (the Sunken Temple quests, say) know that dungeon.
local _, GP = ...
local L = GP.L
local CQ = {}
GP.ClassQuests = CQ

-- File name, class mask bit, quest category (negative zone in ForeverDB).
CQ.classes = {
    { "WARRIOR", 1, -81 }, { "PALADIN", 2, -141 }, { "HUNTER", 4, -261 }, { "ROGUE", 8, -162 }, { "PRIEST", 16, -262 },
    { "SHAMAN", 64, -82 }, { "MAGE", 128, -161 }, { "WARLOCK", 256, -61 }, { "DRUID", 1024, -263 },
}
local byClass = {}
for _, c in ipairs(CQ.classes) do byClass[c[1]] = c end
local ALL = 0
for _, c in ipairs(CQ.classes) do ALL = ALL + c[2] end

local function has(mask, bit) return math.floor(mask / bit) % 2 == 1 end
local function classCount(mask)
    local n = 0
    for _, c in ipairs(CQ.classes) do if has(mask, c[2]) then n = n + 1 end end
    return n
end

-- Quest IDs of a class's quests that your faction can see (your class: also your race).
local function questsOf(db, class)
    local info = byClass[class]
    if not info then return {} end
    local player = GP.Player()
    local own = class == player.class
    local out = {}
    for id, detail in pairs(db.qx or {}) do
        local mask = tonumber(detail[2]) or 0
        local inMask = mask > 0 and has(mask, info[2]) and classCount(mask) <= 2
        local inSort = detail[11] == info[3]
        -- Tier exchanges of Classic raids not in WoW Forever (AQ, Naxxramas) stay out.
        local zone = type(detail[11]) == "number" and detail[11] > 0 and db.dng and db.dng[detail[11]]
        local classicRaid = zone and GP.Sources.raidNames[zone[1]] and not GP.ForeverRaid(zone[1])
        if not classicRaid and (inMask or (inSort and (mask == 0 or has(mask, info[2])))) and db.quest and db.quest[id] then
            local side = GP.Sources.QuestFaction(detail[1])
            local fits = own and GP.Sources.RaceAllowed(detail[1], player.raceBit, player.faction)
                or (not own and (side == nil or side == player.faction))
            if fits then out[#out + 1] = id end
        end
    end
    return out
end

-- The dungeon a quest plays in: a creature it asks for (qx[8]) or that drops an item it asks for (qx[10]).
local function dungeonOf(db, id)
    local detail = db.qx and db.qx[id] or {}
    for _, npcID in ipairs(type(detail[8]) == "table" and detail[8] or {}) do
        local name = GP.Sources.NpcDungeon(db, npcID)
        if name then return name end
    end
    for _, itemID in ipairs(type(detail[10]) == "table" and detail[10] or {}) do
        local drops = db.drop and db.drop[itemID] or {}
        for i = 1, #drops, 2 do
            local name = GP.Sources.NpcDungeon(db, drops[i])
            if name then return name end
        end
    end
    return nil
end

-- Chains of a class: one per last quest (a class quest no other class quest follows), kept per class.
local cache = {}
function CQ.Chains(class)
    local db = ForeverDB
    if not db then return {} end
    if cache[class] then return cache[class] end
    local ids = questsOf(db, class)
    local inSet = {}
    for _, id in ipairs(ids) do inSet[id] = true end
    local followed = {}
    for _, id in ipairs(ids) do
        local detail = db.qx[id] or {}
        for _, field in ipairs({ 3, 4 }) do
            for _, pre in ipairs(type(detail[field]) == "table" and detail[field] or {}) do
                if inSet[pre] then followed[pre] = true end
            end
        end
    end
    local chains = {}
    for _, id in ipairs(ids) do
        if not followed[id] then
            local quest = db.quest[id]
            local steps = GP.Sources.Chain(db, id, GP.Player().faction, GP.Player().raceBit)
            local minLevel, dungeon = nil, nil
            for _, step in ipairs(steps) do
                local q = db.quest[step]
                local m = q and (q[3] or q[2])
                if type(m) == "number" and m > 0 and (not minLevel or m < minLevel) then minLevel = m end
                dungeon = dungeon or dungeonOf(db, step)
            end
            chains[#chains + 1] = { id = id, title = quest[1], level = quest[2], minLevel = minLevel or quest[3] or quest[2] or 1,
                steps = #steps, first = steps[1], dungeon = dungeon }
        end
    end
    table.sort(chains, function(a, b)
        if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
        return a.id < b.id
    end)
    cache[class] = chains
    return chains
end

-- Status of a chain now: steps (Route.Chain with done/active), done count, next step.
function CQ.Status(chain)
    local steps = GP.Route.Chain(chain.id)
    local done, nextIndex = GP.Planner.ChainStatus(steps)
    return steps, done, nextIndex and steps[nextIndex] or nil
end

-- Your class's chains that play in a dungeon (catalog name).
function CQ.ForDungeon(name)
    local out = {}
    for _, chain in ipairs(CQ.Chains(GP.Player().class)) do
        if chain.dungeon == name then out[#out + 1] = chain end
    end
    return out
end

-- The whole open chain into your own route.
function CQ.ToMyRoute(chain)
    local steps = CQ.Status(chain)
    local count = 0
    for _, st in ipairs(steps) do
        if not st.done and not st.skipped then GP.QuestRoute.SetMine(st.id, true); count = count + 1 end
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. (L("%d quests of this chain are in your own route."):format(count)))
    end
end

function CQ.ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return type(names) == "table" and names[class] or class
end
