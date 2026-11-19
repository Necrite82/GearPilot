-- Local names of creatures: ForeverDB names them in English, the game only tells an addon the name of a creature
-- you see. GearPilot remembers the names of creatures you target, hover or talk to (per client language, in
-- GearPilotProCache) and shows those instead of the English ones.
local _, GP = ...
local Names = {}
GP.Names = Names

local function store()
    GearPilotProCache = type(GearPilotProCache) == "table" and GearPilotProCache or {}
    GearPilotProCache.names = type(GearPilotProCache.names) == "table" and GearPilotProCache.names or {}
    local locale = GetLocale and GetLocale() or "enUS"
    GearPilotProCache.names[locale] = type(GearPilotProCache.names[locale]) == "table" and GearPilotProCache.names[locale] or {}
    return GearPilotProCache.names[locale]
end

-- Name of a creature in your language, nil when you have not met it yet (or play in English).
function Names.Get(npcID)
    if not npcID or (GetLocale and GetLocale() == "enUS") then return nil end
    return store()[npcID]
end

-- Some unit values are "secret" (in combat, for some units) and cannot be read by addons: those are skipped.
local function readable(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end
local function learn(unit)
    if not (UnitGUID and UnitName and UnitExists and UnitExists(unit)) then return end
    if UnitIsPlayer and UnitIsPlayer(unit) then return end
    local guid = UnitGUID(unit)
    if not readable(guid) then return end
    local ok, kind, id = pcall(string.match, guid, "^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if not ok or (kind ~= "Creature" and kind ~= "Vehicle") then return end
    local name = UnitName(unit)
    if not readable(name) or type(name) ~= "string" or name == "" then return end
    id = tonumber(id)
    if id then store()[id] = name end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_GREETING",
    "QUEST_PROGRESS", "QUEST_COMPLETE", "MERCHANT_SHOW" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    local unit = event == "PLAYER_TARGET_CHANGED" and "target" or event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or "npc"
    -- Outside the game's own click handling, like the wishlist hint.
    if C_Timer then C_Timer.After(0, function() pcall(learn, unit) end) else pcall(learn, unit) end
end)
