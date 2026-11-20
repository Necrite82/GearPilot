-- Access quests (1.6.1): the chain to a raid or a dungeon key, with its status, next step and route.
local _, GP = ...
local L = GP.L
local A = {}
GP.Access = A

-- Access entries of a dungeon (catalog name) for your faction: { entry, id (last quest), chain, done, total, next }.
function A.For(name)
    local out = {}
    if not (name and ForeverDB) then return out end
    local faction = GP.Player().faction
    for _, entry in ipairs(GP.Attunements or {}) do
        local id = entry.dungeon == name and entry[faction]
        if id and ForeverDB.quest and ForeverDB.quest[id] then
            local chain = GP.Route.Chain(id)
            local done, nextIndex = GP.Planner.ChainStatus(chain)
            out[#out + 1] = { entry = entry, id = id, chain = chain, done = done, total = #chain,
                complete = GP.Sources.QuestDone(id), next = nextIndex and chain[nextIndex] or nil }
        end
    end
    return out
end
-- Missing access of a dungeon: true when a chain is still open.
function A.Missing(name)
    for _, a in ipairs(A.For(name)) do
        if not a.complete then return true, a end
    end
    return false
end
-- Next steps (quest IDs) of every open access chain of a dungeon, for "collect quests" and "prepare".
function A.NextSteps(name)
    local ids = {}
    for _, a in ipairs(A.For(name)) do
        if not a.complete and a.next and not a.next.active then ids[#ids + 1] = a.next.id end
    end
    return ids
end
-- The whole open chain into your own route (quests you cannot take yet join when they open up).
function A.ToMyRoute(a)
    local count = 0
    for _, st in ipairs(a.chain) do
        if not st.done and not st.skipped then GP.QuestRoute.SetMine(st.id, true); count = count + 1 end
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. (L("%d quests of the access chain are in your own route."):format(count)))
    end
end
