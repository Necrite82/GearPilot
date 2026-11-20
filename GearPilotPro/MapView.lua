-- Map window: a zoomable map section in GearPilot's look with numbered points (quest givers of a chain, the
-- quests to collect before a dungeon, its entrance) and your own position. The map art comes from the game
-- (C_Map art layers); zones it cannot draw fall back to the world map.
--
-- GP.Map.Show(title, points): points = { { uiMap, x, y (0..1), kind = "quest"|"active"|"done"|"entrance",
--   label = "1", title, sub, questID, spot } }
local _, GP = ...
local L, S = GP.L, GP.Style
local C = S.palette
local Map = {}
GP.Map = Map

local W, H, HEAD = 560, 460, 74
local ICONS = {
    quest = "Interface\\GossipFrame\\AvailableQuestIcon", active = "Interface\\GossipFrame\\ActiveQuestIcon",
    done = "Interface\\RaidFrame\\ReadyCheck-Ready", entrance = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
}

-- Window ----------------------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "GearPilotProMap", UIParent, "BackdropTemplate")
S.Round(frame)
frame:SetBackdropColor(C.window[1], C.window[2], C.window[3], 1)
frame:SetSize(W, H)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetResizable(true)
if frame.SetResizeBounds then frame:SetResizeBounds(380, 320, 1400, 1000) end
frame:EnableMouse(true)
frame:Hide()
tinsert(UISpecialFrames, "GearPilotProMap")

local function save()
    if not GP.settings then return end
    local point, _, relative, x, y = frame:GetPoint()
    GP.settings.mapWindow = { point = point, relative = relative, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight() }
end
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
header:SetHeight(40)
header:EnableMouse(true)
header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() frame:StartMoving() end)
header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); save() end)
local title = S.Text(header, "GameFontNormal", 14, 13, W - 200)
title:SetWordWrap(false)
-- 1.3.4: the buttons of the top row are children of the drag strip, otherwise the strip lies over them and
-- takes their clicks (world map, zoom and whole map did nothing). Close button in the same style as CraftPilot.
local close = S.Button(header, 26, 24, "x", function() frame:Hide() end)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
local grip = CreateFrame("Button", nil, frame)
grip:SetSize(18, 18)
grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); save(); Map.Layout() end)
grip:SetFrameLevel(frame:GetFrameLevel() + 20)

-- Zone tabs and buttons.
local tabs = {}
local zoomIn, zoomOut, worldButton
local view = CreateFrame("Frame", nil, frame, "BackdropTemplate")
S.Round(view)
view:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1)
view:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEAD)
view:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
if view.SetClipsChildren then view:SetClipsChildren(true) end
view:EnableMouse(true)
view:EnableMouseWheel(true)
local canvas = CreateFrame("Frame", nil, view)
canvas:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
local message = S.Text(view, "GameFontHighlightSmall", 20, 20, 300)
message:Hide()

-- State: the points, the map shown, zoom (1 = the whole map fits) and offset (pixels, top left of the map).
local state = { points = {}, maps = {}, map = nil, zoom = 1, offsetX = 0, offsetY = 0 }
local tiles, overlayTiles, pins = {}, {}, {}
local updateReveal
local playerPin

local function art(uiMap)
    if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return nil end
    local ok, layers = pcall(C_Map.GetMapArtLayers, uiMap)
    local layer = ok and type(layers) == "table" and layers[1]
    if not (layer and layer.layerWidth and layer.layerWidth > 0 and layer.tileWidth and layer.tileWidth > 0) then return nil end
    local textures
    ok, textures = pcall(C_Map.GetMapArtLayerTextures, uiMap, 1)
    if not (ok and type(textures) == "table" and #textures > 0) then return nil end
    return { width = layer.layerWidth, height = layer.layerHeight, tileWidth = layer.tileWidth, tileHeight = layer.tileHeight,
        textures = textures }
end

-- Detail pieces on top of the base map (towns, roads, forests). "Whole map": every piece from the client tables
-- (Data/MapOverlays.lua, built by tools/maps); otherwise, or without that data, the pieces you have explored.
-- Each: { offsetX, offsetY, width, height, fileIDs (row by row, 256 px tiles) }.
local function overlays(uiMap)
    local reveal = not (GP.settings and GP.settings.mapReveal == false)
    local data = GP.MapOverlays and GP.MapOverlays.maps and GP.MapOverlays.maps[uiMap]
    if reveal and data then return data end
    local list = {}
    if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
        local ok, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, uiMap)
        for _, info in ipairs(ok and type(explored) == "table" and explored or {}) do
            if not info.isShownByMouseOver and info.fileDataIDs then
                list[#list + 1] = { info.offsetX or 0, info.offsetY or 0, info.textureWidth or 0, info.textureHeight or 0, info.fileDataIDs }
            end
        end
    end
    return list
end
local function pow2(value)
    local size = 16
    while size < value do size = size * 2 end
    return size
end

-- Fit: the scale at which the whole map fits the view.
local function fit(info)
    local vw, vh = view:GetWidth() or 400, view:GetHeight() or 300
    return math.min(vw / info.width, vh / info.height)
end
local function clampOffset(info, scale)
    local vw, vh = view:GetWidth() or 400, view:GetHeight() or 300
    local mw, mh = info.width * scale, info.height * scale
    -- A map smaller than the view is centered; a larger one cannot be dragged past its edges.
    if mw <= vw then state.offsetX = (vw - mw) / 2 else state.offsetX = math.min(0, math.max(vw - mw, state.offsetX)) end
    if mh <= vh then state.offsetY = (vh - mh) / 2 else state.offsetY = math.min(0, math.max(vh - mh, state.offsetY)) end
end

local function pin(i)
    local p = pins[i]
    if p then return p end
    p = CreateFrame("Button", nil, canvas)
    p:SetSize(22, 22)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p.label = p:CreateFontString(nil, "OVERLAY")
    p.label:SetFontObject(S.Font("GameFontHighlightSmall"))
    p.label:SetPoint("TOPLEFT", p, "BOTTOMRIGHT", -8, 8)
    p:SetScript("OnEnter", function(self)
        local point = self.point
        if not point then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((point.label and (point.label .. ". ") or "") .. (point.title or ""))
        if point.sub then GameTooltip:AddLine(point.sub, .8, .8, .8, true) end
        GameTooltip:AddLine(L("Click: waypoint"), .88, .69, .31)
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnClick", function(self)
        local point = self.point
        if not point then return end
        if point.questID then GP.Route.ToGiver(point.questID)
        else GP.Route.ToSpot({ world = false, map = point.uiMap, x = point.x, y = point.y }, point.title, point.sub) end
    end)
    pins[i] = p
    return p
end

-- Draws the map, the points and your position at the current zoom and offset.
function Map.Layout()
    if not frame:IsShown() then return end
    updateReveal()
    for _, t in ipairs(tiles) do t:Hide() end
    for _, t in ipairs(overlayTiles) do t:Hide() end
    for _, p in ipairs(pins) do p:Hide() end
    if playerPin then playerPin:Hide() end
    local uiMap = state.map
    local info = uiMap and art(uiMap)
    worldButton:SetEnabled(uiMap ~= nil)
    if not info then
        message:SetWidth((view:GetWidth() or 300) - 40)
        message:SetText(uiMap and L("GearPilot cannot draw this map. Open it on the world map instead.") or L("No positions known for these points."))
        message:Show()
        return
    end
    message:Hide()
    local scale = fit(info) * state.zoom
    clampOffset(info, scale)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", view, "TOPLEFT", state.offsetX, -state.offsetY)
    canvas:SetSize(info.width * scale, info.height * scale)
    local cols = math.ceil(info.width / info.tileWidth)
    for index, fileID in ipairs(info.textures) do
        local t = tiles[index]
        if not t then
            t = canvas:CreateTexture(nil, "BACKGROUND")
            tiles[index] = t
        end
        local col, row = (index - 1) % cols, math.floor((index - 1) / cols)
        t:SetTexture(fileID)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", canvas, "TOPLEFT", col * info.tileWidth * scale, -row * info.tileHeight * scale)
        t:SetSize(info.tileWidth * scale, info.tileHeight * scale)
        t:Show()
    end
    -- Detail pieces, cut like the world map does: 256 px tiles, the last row and column smaller.
    local used = 0
    for _, piece in ipairs(overlays(uiMap)) do
        local ox, oy, pw, ph, files = piece[1], piece[2], piece[3], piece[4], piece[5]
        local columns, rowsCount = math.ceil(pw / 256), math.ceil(ph / 256)
        for row = 1, rowsCount do
            local pixelH = (row == rowsCount and ph % 256 ~= 0) and ph % 256 or 256
            for col = 1, columns do
                local fileID = files[(row - 1) * columns + col]
                if fileID then
                    local pixelW = (col == columns and pw % 256 ~= 0) and pw % 256 or 256
                    used = used + 1
                    local t = overlayTiles[used]
                    if not t then
                        t = canvas:CreateTexture(nil, "BORDER")
                        overlayTiles[used] = t
                    end
                    t:SetTexture(fileID)
                    t:SetTexCoord(0, pixelW / pow2(pixelW), 0, pixelH / pow2(pixelH))
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", canvas, "TOPLEFT", (ox + (col - 1) * 256) * scale, -(oy + (row - 1) * 256) * scale)
                    t:SetSize(pixelW * scale, pixelH * scale)
                    t:Show()
                end
            end
        end
    end
    local n = 0
    for _, point in ipairs(state.points) do
        if point.uiMap == uiMap then
            n = n + 1
            local p = pin(n)
            p.point = point
            p.icon:SetTexture(ICONS[point.kind] or ICONS.quest)
            p.icon:SetDesaturated(point.kind == "done")
            p.icon:SetAlpha(point.kind == "done" and .6 or 1)
            p.label:SetText(point.label or "")
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", point.x * info.width * scale, -point.y * info.height * scale)
            p:SetFrameLevel(canvas:GetFrameLevel() + 2 + (point.kind == "done" and 0 or 1))
            p:Show()
        end
    end
    Map.UpdatePlayer()
end

-- Your position, when you are on the map shown.
function Map.UpdatePlayer()
    if not (frame:IsShown() and state.map and C_Map and C_Map.GetPlayerMapPosition) then return end
    local info = art(state.map)
    if not info then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, state.map, "player")
    if not playerPin then
        playerPin = canvas:CreateTexture(nil, "OVERLAY")
        playerPin:SetSize(18, 18)
        playerPin:SetTexture("Interface\\Minimap\\MinimapArrow")
    end
    local x, y = ok and pos and pos.x, ok and pos and pos.y
    if not (x and y and x > 0 and y > 0) then playerPin:Hide() return end
    local scale = fit(info) * state.zoom
    playerPin:ClearAllPoints()
    playerPin:SetPoint("CENTER", canvas, "TOPLEFT", x * info.width * scale, -y * info.height * scale)
    if GetPlayerFacing and playerPin.SetRotation then playerPin:SetRotation(GetPlayerFacing() or 0) end
    playerPin:Show()
end

-- Zoom around a point of the view (cursor or center): the map spot under it stays in place.
local MAX_ZOOM = 6
function Map.Zoom(factor, vx, vy)
    local info = state.map and art(state.map)
    if not info then return end
    local old = state.zoom
    local new = math.max(1, math.min(MAX_ZOOM, old * factor))
    if new == old then return end
    vx = vx or (view:GetWidth() or 400) / 2
    vy = vy or (view:GetHeight() or 300) / 2
    local base = fit(info)
    local mx, my = (vx - state.offsetX) / (base * old), (vy - state.offsetY) / (base * old)
    state.zoom = new
    state.offsetX, state.offsetY = vx - mx * base * new, vy - my * base * new
    Map.Layout()
end
view:SetScript("OnMouseWheel", function(self, delta)
    local x, y = GetCursorPosition()
    local s = self:GetEffectiveScale()
    Map.Zoom(delta > 0 and 1.25 or 0.8, x / s - self:GetLeft(), self:GetTop() - y / s)
end)
-- Drag to move the map.
view:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    local x, y = GetCursorPosition()
    self.drag = { x = x, y = y, ox = state.offsetX, oy = state.offsetY, scale = self:GetEffectiveScale() }
end)
view:SetScript("OnMouseUp", function(self) self.drag = nil end)
local elapsed = 0
view:SetScript("OnUpdate", function(self, delta)
    if self.drag then
        local x, y = GetCursorPosition()
        state.offsetX = self.drag.ox + (x - self.drag.x) / self.drag.scale
        state.offsetY = self.drag.oy - (y - self.drag.y) / self.drag.scale
        Map.Layout()
        return
    end
    elapsed = elapsed + delta
    if elapsed > 0.5 then
        elapsed = 0
        Map.UpdatePlayer()
    end
end)

zoomIn = S.Button(header, 28, 24, "+", function() Map.Zoom(1.25) end)
zoomOut = S.Button(header, 28, 24, "-", function() Map.Zoom(0.8) end)
worldButton = S.Button(header, 130, 24, L("World map"), function()
    if not state.map then return end
    if WorldMapFrame and WorldMapFrame.SetMapID then
        if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
        WorldMapFrame:SetMapID(state.map)
    elseif OpenWorldMap then
        OpenWorldMap(state.map)
    end
end)
worldButton:SetPoint("RIGHT", close, "LEFT", -8, 0)
zoomIn:SetPoint("RIGHT", worldButton, "LEFT", -8, 0)
zoomOut:SetPoint("RIGHT", zoomIn, "LEFT", -4, 0)
-- Whole map or only what you have explored (for players who want to discover it themselves).
local revealButton = S.Button(header, 130, 24, "", function(self)
    if not GP.settings then return end
    GP.settings.mapReveal = GP.settings.mapReveal == false
    Map.Layout()
end)
revealButton:SetPoint("RIGHT", zoomOut, "LEFT", -8, 0)
function updateReveal()
    local reveal = not (GP.settings and GP.settings.mapReveal == false)
    revealButton:SetText(reveal and L("Whole map") or L("Explored only"))
    S.Segment(revealButton, reveal)
end

local function tab(i)
    local b = tabs[i]
    if b then return b end
    b = S.Button(frame, 120, 22, "", function(self)
        state.map = self.map
        state.zoom, state.offsetX, state.offsetY = 1, 0, 0
        Map.Refresh()
    end)
    tabs[i] = b
    return b
end

-- Tabs per zone, then the map.
function Map.Refresh()
    local x = 12
    for _, b in ipairs(tabs) do b:Hide() end
    for i, entry in ipairs(state.maps) do
        local b = tab(i)
        b.map = entry.map
        b:SetText(("%s (%d)"):format(entry.name, entry.count))
        local width = math.max(90, math.min(200, (b:GetFontString() and b:GetFontString():GetStringWidth() or 80) + 24))
        b:SetWidth(width)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -44)
        S.Segment(b, entry.map == state.map)
        b:Show()
        x = x + width + 6
    end
    Map.Layout()
end

function Map.Show(heading, points)
    state.points = points or {}
    local counts, order = {}, {}
    for _, point in ipairs(state.points) do
        if point.uiMap then
            if not counts[point.uiMap] then order[#order + 1] = point.uiMap end
            counts[point.uiMap] = (counts[point.uiMap] or 0) + 1
        end
    end
    state.maps = {}
    for _, uiMap in ipairs(order) do
        state.maps[#state.maps + 1] = { map = uiMap, count = counts[uiMap], name = GP.Sources.MapName(uiMap) or ("#" .. uiMap) }
    end
    -- First the zone you are in, then the zone with most points.
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    table.sort(state.maps, function(a, b)
        if (a.map == here) ~= (b.map == here) then return a.map == here end
        return a.count > b.count
    end)
    state.map = state.maps[1] and state.maps[1].map or nil
    state.zoom, state.offsetX, state.offsetY = 1, 0, 0
    title:SetText(heading or L("Map"))
    local saved = GP.settings and GP.settings.mapWindow
    if saved and saved.point and not frame.placed then
        frame:ClearAllPoints()
        frame:SetPoint(saved.point, UIParent, saved.relative or saved.point, saved.x or 0, saved.y or 0)
        if saved.w and saved.h then frame:SetSize(saved.w, saved.h) end
        frame.placed = true
    end
    frame:Show()
    frame:Raise()
    Map.Refresh()
end
frame:SetScript("OnSizeChanged", function() Map.Layout() end)

-- Points from quests: every step of a chain (numbered), or quests to collect.
local function questPoint(step, label)
    if not (step and step.uiMap and step.x) then return nil end
    local kind = step.done and "done" or step.active and "active" or "quest"
    local status = step.done and L("done") or step.active and L("in quest log") or nil
    local sub = (step.giver or "?") .. (step.zone and (", " .. step.zone) or "") .. (status and (" · " .. status) or "")
    return { uiMap = step.uiMap, x = step.x, y = step.y, kind = kind, label = label, title = step.title, sub = sub, questID = step.id }
end
function Map.Chain(questID)
    local points = {}
    local chain = GP.Route.Chain(questID)
    GP.Planner.ChainStatus(chain)
    for i, step in ipairs(chain) do
        local point = questPoint(step, tostring(i))
        if point then
            if step.skipped then point.kind = "done" end
            points[#points + 1] = point
        end
    end
    local last = chain[#chain]
    Map.Show(last and last.title or L("Quest chain"), points)
end
-- One place: a vendor, a mob (ForeverDB reference "c123") or any spot.
function Map.Place(heading, title, sub, ref, spot)
    spot = spot or (ref and ForeverDB and GP.Sources.Spot(ForeverDB, ref))
    local uiMap, x, y = GP.Sources.MapPoint(spot)
    local points = {}
    if uiMap and x then
        points[1] = { uiMap = uiMap, x = x, y = y, kind = ref and "quest" or "entrance", title = title, sub = sub }
    end
    Map.Show(heading, points)
end
function Map.Quests(heading, questIDs, entrances)
    local points = {}
    for i, id in ipairs(questIDs or {}) do
        local point = questPoint(GP.Route.Step(id), tostring(i))
        if point then points[#points + 1] = point end
    end
    for _, entry in ipairs(entrances or {}) do
        local uiMap, x, y = GP.Sources.MapPoint(entry.spot)
        if uiMap and x then
            points[#points + 1] = { uiMap = uiMap, x = x, y = y, kind = "entrance", title = entry.title, sub = L("Entrance") }
        end
    end
    Map.Show(heading, points)
end
