-- Builds GearPilotPro/Data/Dungeons.lua from AllTheThings' Forever dungeon files (MIT).
-- Usage: lua5.1 tools/dungeons/build.lua <att folder from fetch_att.py> <output file> [commit]
-- The ATT files are Lua: they are run with stub functions that only record instances, encounters, creatures
-- and items. Nothing else of ATT is kept. Output is sorted, so an unchanged source gives an unchanged file.
local dir, out, commit = arg[1], arg[2], arg[3] or "unknown"
assert(dir and out, "usage: build.lua <att folder> <output file> [commit]")

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

-- MAP.NAME -> UI map ID from ATT's constants (plain "NAME = 1234;" lines).
local maps = {}
for name, id in readFile(dir .. "/.config/constants/maps.lua"):gmatch("([%u_%d]+)%s*=%s*(%d+)%s*[;,]") do
    maps[name] = tonumber(id)
end

local function node(kind) return function(id, t) return { kind = kind, id = id, t = type(t) == "table" and t or {} } end end
local mapProxy = setmetatable({}, { __index = function(_, k) return k end })
local collected
-- Anything ATT defines besides the recorded helpers: a "proxy" that can be called, indexed, assigned to and
-- concatenated, so tooltip and update scripts in the files run without effect.
local proxyMeta = {}
local function proxy(name) return setmetatable({ kind = name }, proxyMeta) end
proxyMeta.__index = function(self, k) local p = proxy(k); rawset(self, k, p); return p end
proxyMeta.__call = function(self, id, t) return setmetatable({ kind = rawget(self, "kind"), id = id, t = type(t) == "table" and t or {} }, proxyMeta) end
proxyMeta.__concat = function(a, b)
    local function s(v) return type(v) == "table" and "" or tostring(v) end
    return s(a) .. s(b)
end
local env = setmetatable({
    instanceroot = function(id, t)
        local r = { kind = "inst", id = id, t = type(t) == "table" and t or {} }
        collected[#collected + 1] = r
        return r
    end,
    e = node("e"), n = node("n"), q = node("q"), i = node("i"), objective = node("obj"),
    MAP = mapProxy, math = math, string = string, table = table, pairs = pairs, ipairs = ipairs, type = type,
    tostring = tostring, tonumber = tonumber, unpack = unpack, select = select,
}, { __index = function(_, k)
    -- Any other ATT constant is its own name; any other helper builds a plain node.
    if type(k) == "string" and k:match("^%u[%u_%d]*$") then return k end
    return proxy(k)
end })

local function items(list, out)
    for _, child in ipairs(list or {}) do
        if type(child) == "table" then
            if child.kind == "i" and type(child.id) == "number" then out[#out + 1] = child.id
            elseif child.kind ~= "q" and child.kind ~= "obj" and type(child.t) == "table" then
                items(child.t.groups or child.t, out)
            end
        end
    end
    return out
end

local function walk(node, inst)
    if type(node) ~= "table" or type(node.t) ~= "table" then return end
    local boss = node.kind == "e" or (node.kind == "n" and type(node.id) == "number")
    if boss then
        local npcs, seen = {}, {}
        local function add(id) if type(id) == "number" and not seen[id] then seen[id] = true; npcs[#npcs + 1] = id end end
        add(node.t.creatureID)
        for _, id in ipairs(node.t.crs or {}) do add(id) end
        if node.kind == "n" then add(node.id) end
        local loot = items(node.t.groups or node.t, {})
        if #npcs > 0 and (#loot > 0 or node.kind == "e") then
            inst.bosses[#inst.bosses + 1] = { encounter = node.kind == "e" and node.id or nil, npcs = npcs, items = loot,
                rare = type(node.t.description) == "string" and node.t.description:lower():find("rare") and true or nil }
        end
        return
    end
    for _, child in ipairs(node.t.groups or node.t) do walk(child, inst) end
end

-- Names from the comments behind instanceroot(...) and e(...), n(...): "-- The Drowned City".
local function names(text)
    local instance = text:match("instanceroot%(%d+,%s*{%s*%-%-%s*([^\r\n]+)")
    local bosses = {}
    for kind, id, name in text:gmatch("([en])%((%d+),%s*{%s*%-%-%s*([^\r\n]+)") do
        bosses[kind .. id] = name:gsub("%s+$", "")
    end
    return instance and instance:gsub("%s+$", ""), bosses
end

local instances = {}
local files = {}
for name in io.popen('ls "' .. dir .. '/dungeons & raids"'):lines() do
    if name:match("%.lua$") then files[#files + 1] = name end
end
table.sort(files)
for _, file in ipairs(files) do
    local path = dir .. "/dungeons & raids/" .. file
    local chunk, err = loadfile(path)
    if not chunk then error(path .. ": " .. tostring(err)) end
    setfenv(chunk, env)
    collected = {}
    local ok, failure = pcall(chunk)
    if not ok then io.stderr:write("skipped " .. file .. ": " .. tostring(failure) .. "\n") end
    local instanceName, bossNames = names(readFile(path))
    for _, root in ipairs(collected) do
        local t = root.t
        local entrance
        if type(t.coord) == "table" and type(t.coord[1]) == "number" then
            local map = type(t.coord[3]) == "number" and t.coord[3] or maps[t.coord[3]]
            if map then entrance = { map, t.coord[1], t.coord[2] } end
        end
        local inst = { id = root.id, name = instanceName or file:gsub("%.lua$", ""), level = t.lvl, raid = t.isRaid and true or nil,
            area = t.zoneTextAreaID, entrance = entrance, bosses = {} }
        walk(root, inst)
        for _, boss in ipairs(inst.bosses) do
            boss.name = bossNames[(boss.encounter and ("e" .. boss.encounter)) or ("n" .. boss.npcs[#boss.npcs])]
        end
        if #inst.bosses > 0 then instances[#instances + 1] = inst end
    end
end
table.sort(instances, function(a, b) return a.id < b.id end)

-- Output ----------------------------------------------------------------------------------------------------
local function q(s) return string.format("%q", s) end
local function list(t) local parts = {} for _, v in ipairs(t) do parts[#parts + 1] = tostring(v) end return "{ " .. table.concat(parts, ", ") .. " }" end
local lines = {
    "-- GearPilot dungeon data: instances, bosses (creature IDs) and their loot from AllTheThings' WoW Forever",
    "-- database (MIT, https://github.com/ATTWoWAddon/AllTheThings). GENERATED by tools/dungeons/build.lua - do not edit.",
    "local _, GP = ...",
    "GP.DungeonData = {",
    "  source = " .. q("AllTheThings " .. commit) .. ",",
    "  instances = {",
}
local bossCount, itemCount = 0, 0
for _, inst in ipairs(instances) do
    local head = { "id = " .. inst.id, "name = " .. q(inst.name) }
    if inst.level then head[#head + 1] = "level = " .. inst.level end
    if inst.raid then head[#head + 1] = "raid = true" end
    if inst.area then head[#head + 1] = "area = " .. inst.area end
    if inst.entrance then head[#head + 1] = "entrance = " .. list(inst.entrance) end
    lines[#lines + 1] = "    { " .. table.concat(head, ", ") .. ", bosses = {"
    for _, boss in ipairs(inst.bosses) do
        bossCount, itemCount = bossCount + 1, itemCount + #boss.items
        local fields = { "npcs = " .. list(boss.npcs), "items = " .. list(boss.items) }
        if boss.name then table.insert(fields, 1, "name = " .. q(boss.name)) end
        if boss.rare then fields[#fields + 1] = "rare = true" end
        lines[#lines + 1] = "      { " .. table.concat(fields, ", ") .. " },"
    end
    lines[#lines + 1] = "    } },"
end
lines[#lines + 1] = "  },"
lines[#lines + 1] = "}"
local f = assert(io.open(out, "wb"))
f:write(table.concat(lines, "\n") .. "\n")
f:close()
print(("Dungeons.lua: %d instances, %d bosses, %d items"):format(#instances, bossCount, itemCount))
