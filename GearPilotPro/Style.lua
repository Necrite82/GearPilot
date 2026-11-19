-- Shared look, taken over from CraftPilot: dark surfaces with round corners, gold for the selection and for
-- primary actions. Media/Round.tga is a backdrop edge whose corners are filled quarter circles; fill and edge
-- share one color, so a surface gets round corners without a visible outline.
local _, GP = ...
local Style = {}
GP.Style = Style

Style.palette = {
    window = {.078, .090, .110}, panel = {.098, .114, .137}, raised = {.122, .141, .172},
    border = {.17, .196, .227}, gold = {.88, .69, .31}, text = {.91, .90, .87}, muted = {.60, .64, .68},
    green = {.52, .84, .63}, red = {.92, .47, .42}, dark = {.11, .08, .02},
}
local ROUND = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\AddOns\\GearPilotPro\\Media\\Round",
    edgeSize = 6, insets = { left = 6, right = 6, top = 6, bottom = 6 } }

function Style.Round(f, hover)
    if not f or type(f.SetBackdrop) ~= "function" then return f end
    f:SetBackdrop(ROUND)
    if not rawget(f, "gpRound") then
        f.gpRound = true
        local setColor, setBorder = f.SetBackdropColor, f.SetBackdropBorderColor
        f.SetBackdropColor = function(self, r, g, b, a)
            self.gpBase = { r, g, b, a or 1 }
            if self.gpHover then r, g, b = math.min(1, r + .06), math.min(1, g + .06), math.min(1, b + .07) end
            setColor(self, r, g, b, a or 1)
            setBorder(self, r, g, b, a or 1)
        end
        f.SetBackdropBorderColor = function() end
        if hover then
            f:HookScript("OnEnter", function(self)
                self.gpHover = true
                local c = self.gpBase
                if c then self:SetBackdropColor(c[1], c[2], c[3], c[4]) end
            end)
            f:HookScript("OnLeave", function(self)
                self.gpHover = nil
                local c = self.gpBase
                if c then self:SetBackdropColor(c[1], c[2], c[3], c[4]) end
            end)
        end
    end
    return f
end

function Style.Surface(parent, shade)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Style.Round(f)
    local c = Style.palette[shade or "panel"]
    f:SetBackdropColor(c[1], c[2], c[3], 1)
    return f
end

function Style.Text(parent, font, x, y, width, value, align)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if width then t:SetWidth(width) end
    t:SetJustifyH(align or "LEFT")
    t:SetText(value or "")
    return t
end

function Style.Button(parent, width, height, caption, callback)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    Style.Round(b, true)
    b:SetBackdropColor(.114, .133, .165, 1)
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(b)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    b:SetFontString(label)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetSize(width, height)
    b:SetText(caption or "")
    if callback then b:SetScript("OnClick", callback) end
    return b
end

local primaryFont
function Style.Primary(b)
    b:SetBackdropColor(.88, .69, .31, 1)
    if not primaryFont then
        primaryFont = CreateFont("GearPilotProPrimaryButtonFont")
        primaryFont:CopyFontObject(GameFontHighlightSmall)
        primaryFont:SetTextColor(.11, .08, .02)
        primaryFont:SetShadowOffset(0, 0)
        primaryFont:SetShadowColor(0, 0, 0, 0)
    end
    b:SetNormalFontObject(primaryFont)
    b:SetHighlightFontObject(primaryFont)
    b:SetDisabledFontObject(primaryFont)
    local label = b:GetFontString()
    if label then
        label:SetTextColor(.11, .08, .02)
        label:SetShadowOffset(0, 0)
    end
    if b.IsEnabled and not b:IsEnabled() then b:SetBackdropColor(.40, .33, .18, 1) end
    return b
end

-- One option of a segmented control: gold when selected, otherwise a quiet label on the group surface.
function Style.Segment(b, on)
    if on then return Style.Primary(b) end
    b:SetBackdropColor(0, 0, 0, 0)
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    local label = b:GetFontString()
    if label then
        label:SetTextColor(.80, .79, .75)
        label:SetShadowOffset(1, -1)
        label:SetShadowColor(0, 0, 0, 1)
    end
    return b
end

-- Three figures side by side (label above, value below), like CraftPilot's metric strip.
function Style.Metrics(parent, values, x, y, width)
    parent.gpMetrics = rawget(parent, "gpMetrics") or {}
    local w = (width - 16) / 3
    for i = 1, 3 do
        local p = parent.gpMetrics[i]
        if not p then
            p = Style.Surface(parent, "raised")
            p.label = Style.Text(p, "GameFontDisableSmall", 10, 7, w - 20)
            p.value = Style.Text(p, "GameFontNormal", 10, 24, w - 20)
            p.value:SetWordWrap(false)
            parent.gpMetrics[i] = p
        end
        local v = values[i]
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (i - 1) * (w + 8), -y)
        p:SetSize(w, 48)
        p.label:SetWidth(w - 20)
        p.value:SetWidth(w - 20)
        p.label:SetText(v.label)
        p.value:SetText(v.value)
        p.value:SetFontObject(v.emphasis and "GameFontNormalLarge" or "GameFontNormal")
        local c = v.color or {1, .84, .46}
        p.value:SetTextColor(c[1], c[2], c[3])
        p:Show()
    end
end
function Style.HideMetrics(parent)
    for _, p in ipairs(rawget(parent, "gpMetrics") or {}) do p:Hide() end
end

function Style.QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    if c and c.hex then return c.hex end
    return "|cffffffff"
end
