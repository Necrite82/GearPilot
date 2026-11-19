-- Minimap button (no library needed: drag it around the minimap) and the game's addon compartment.
local _, GP = ...
local L = GP.L
local ICON = "Interface\\AddOns\\GearPilotPro\\Media\\GearPilot"

local function tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("GearPilot")
    GameTooltip:AddLine(L("Click: open or close"), 1, 1, 1)
    GameTooltip:AddLine(L("Drag: move around the minimap"), 1, 1, 1)
    GameTooltip:Show()
end

local button
local function place(angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function create()
    button = CreateFrame("Button", "GearPilotProMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then GP.Open("settings") else GP.Toggle() end
    end)
    button:SetScript("OnEnter", tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            GP.settings.minimapAngle = angle
            place(angle)
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

function GP.UpdateMinimapButton()
    if not GP.settings or not Minimap then return end
    if GP.settings.minimap == false then
        if button then button:Hide() end
        return
    end
    if not button then create() end
    place(GP.settings.minimapAngle or 210)
    button:Show()
end

-- Addon compartment (the addon list button next to the minimap); referenced in the TOC.
function GearPilotPro_OnAddonCompartmentClick() GP.Toggle() end
function GearPilotPro_OnAddonCompartmentEnter(_, owner) if owner then tooltip(owner) end end
function GearPilotPro_OnAddonCompartmentLeave() GameTooltip:Hide() end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() GP.UpdateMinimapButton() end)
