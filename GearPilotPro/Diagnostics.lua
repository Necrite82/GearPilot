-- 1.6.3: "/gpp speicher" – which parts of GearPilot create the most garbage. For 60 seconds the main functions are
-- wrapped and the memory they allocate is summed (only GearPilot's own work; nothing is changed or sent).
local _, GP = ...
local L = GP.L
local D = {}
GP.Diagnostics = D

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end
-- { table name, function name } – looked up when the watch starts.
local WATCH = {
    { "GP", "Render" }, { "GP", "ReadGear" }, { "GP", "ItemData" }, { "GP", "Catalog" }, { "GP", "BisList" },
    { "GP", "TooltipLine" }, { "QuestRoute", "Current" }, { "QuestRoute", "Follow" }, { "QuestRoute", "NextTask" },
    { "QuestRoute", "OpenTasks" }, { "Tracker", "Refresh" }, { "QuestInfo", "Show" }, { "QuestInfo", "Objectives" },
    { "QuestLog", "Quests" }, { "QuestLog", "Ranked" }, { "Sources", "Rows" }, { "Stats", "Read" },
    { "Planner", "Compare" }, { "Planner", "Recommend" }, { "Map", "Layout" }, { "Map", "UpdatePlayer" },
    { "Togo", "Quests" }, { "Access", "For" },
}
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "ITEM_DATA_LOAD_RESULT", "QUEST_DATA_LOAD_RESULT", "UNIT_INVENTORY_CHANGED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" }
local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end

-- GearPilot's own memory as the game shows it (collectgarbage counts every addon together).
local function own()
    local update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if type(update) ~= "function" or type(get) ~= "function" then return nil end
    pcall(update)
    local ok, kb = pcall(get, "GearPilotPro")
    return ok and type(kb) == "number" and kb or nil
end

function D.StartMemoryWatch(seconds)
    if D.watch then say(L("Memory check is already running.")); return end
    seconds = seconds or 60
    local stats, originals, callers, counts = {}, {}, {}, {}
    for _, spec in ipairs(WATCH) do
        local owner = spec[1] == "GP" and GP or GP[spec[1]]
        local fn = type(owner) == "table" and owner[spec[2]]
        if type(fn) == "function" then
            local label = spec[1] == "GP" and spec[2] or (spec[1] .. "." .. spec[2])
            local entry = { name = label, calls = 0, kb = 0 }
            stats[#stats + 1] = entry
            originals[#originals + 1] = { owner, spec[2], fn }
            owner[spec[2]] = function(...)
                -- Who asked for a redraw: the calling line, so frequent redraws show their cause.
                if spec[2] == "Render" and type(debugstack) == "function" then
                    local ok, stack = pcall(debugstack, 2, 3, 0)
                    if ok and type(stack) == "string" then
                        local where
                        for line in stack:gmatch("[^\n]+") do
                            local file, num = line:match("([%w_]+%.lua)%D+(%d+)")
                            if file and file ~= "Diagnostics.lua" then where = file .. ":" .. num; break end
                        end
                        callers[where or "?"] = (callers[where or "?"] or 0) + 1
                    end
                end
                local before = collectgarbage("count")
                local result = pack(fn(...))
                local used = collectgarbage("count") - before
                entry.calls = entry.calls + 1
                if used > 0 then entry.kb = entry.kb + used end
                return unpack(result, 1, result.n)
            end
        end
    end
    local listener = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do pcall(listener.RegisterEvent, listener, event) end
    listener:SetScript("OnEvent", function(_, event) counts[event] = (counts[event] or 0) + 1 end)
    local start = own()
    D.watch = true
    say((L("Memory check runs for %d seconds – just keep playing."):format(seconds)))
    local function finish()
        for _, o in ipairs(originals) do o[1][o[2]] = o[3] end
        listener:UnregisterAllEvents()
        D.watch = nil
        table.sort(stats, function(a, b) return a.kb > b.kb end)
        local now = own()
        if start and now then
            say((L("Memory check: GearPilot from %.1f to %.1f MB in %d seconds (WoW cleans up in between). Biggest causes (sub-calls included):")):format(start / 1024, now / 1024, seconds))
        else
            say((L("Memory check over %d seconds. Biggest causes (sub-calls included):")):format(seconds))
        end
        for i = 1, math.min(8, #stats) do
            local s = stats[i]
            if s.calls > 0 then say(("  %s: %.1f MB, %d %s"):format(s.name, s.kb / 1024, s.calls, L("calls"))) end
        end
        local function top(map, label)
            local list = {}
            for k, n in pairs(map) do list[#list + 1] = { k, n } end
            table.sort(list, function(a, b) return a[2] > b[2] end)
            local parts = {}
            for i = 1, math.min(6, #list) do parts[#parts + 1] = list[i][1] .. " " .. list[i][2] .. "×" end
            if #parts > 0 then say(label .. table.concat(parts, ", ")) end
        end
        top(callers, L("Redraws started by: "))
        top(counts, L("Events: "))
    end
    if C_Timer and C_Timer.After then C_Timer.After(seconds, finish) else finish() end
    return true
end
