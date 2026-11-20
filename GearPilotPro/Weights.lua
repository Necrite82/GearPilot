-- Own profile: edit every weight or paste a Pawn scale (WoWSims exports the same format).
local _, GP = ...
local P, L, S, St = GP.Planner, GP.L, GP.Style, GP.Stats
local C = S.palette
local KEYS = { "STR", "AGI", "STA", "INT", "SPI", "AP", "RAP", "SP", "HEAL", "MP5", "CRIT", "SCRIT", "HIT",
    "SHIT", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR", "DPS", "RDPS", "WAND", "SCHOOL",
    "SCHOOL_FIRE", "SCHOOL_FROST", "SCHOOL_SHADOW", "SCHOOL_ARCANE", "SCHOOL_NATURE", "SCHOOL_HOLY" }

local dialog
local function build()
    local f = CreateFrame("Frame", "GearPilotProWeights", UIParent, "BackdropTemplate")
    S.Round(f)
    f:SetBackdropColor(C.window[1], C.window[2], C.window[3], 1)
    f:SetSize(560, 660)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "GearPilotProWeights")
    S.Text(f, "GameFontNormalLarge", 18, 18, 400, L("Own profile"))
    S.Text(f, "GameFontHighlightSmall", 18, 42, 520,
        L("Weight per point; crit, hit, dodge, parry and block per 1 %, weapon DPS per 1 DPS. 0 or empty = does not count."))
    local close = S.Button(f, 26, 24, "x", function() f:Hide() end)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    f.inputs = {}
    local columns, rowHeight = 2, 28
    for i, key in ipairs(KEYS) do
        local col, rowIndex = (i - 1) % columns, math.floor((i - 1) / columns)
        local x, y = 18 + col * 266, 76 + rowIndex * rowHeight
        S.Text(f, "GameFontHighlightSmall", x, y + 6, 180, L(St.names[key] or key))
        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetSize(60, 20)
        box:SetPoint("TOPLEFT", f, "TOPLEFT", x + 190, -(y + 2))
        box:SetAutoFocus(false)
        box:SetNumeric(false)
        box:SetScript("OnEscapePressed", box.ClearFocus)
        box:SetScript("OnEnterPressed", box.ClearFocus)
        f.inputs[key] = box
    end
    local importY = 76 + math.ceil(#KEYS / columns) * rowHeight + 8
    local title = S.Text(f, "GameFontNormal", 18, importY, 520, L("Import Pawn / WoWSims"))
    title:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    f.import = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.import:SetSize(400, 20)
    f.import:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -(importY + 24))
    f.import:SetAutoFocus(false)
    f.import:SetScript("OnEscapePressed", f.import.ClearFocus)
    local apply = S.Button(f, 100, 24, L("Import"), function()
        local weights = P.ParsePawn(f.import:GetText())
        if not weights then
            f.status:SetText("|cffeb786b" .. L("No Pawn values found in the text.") .. "|r")
            return
        end
        for _, key in ipairs(KEYS) do f.inputs[key]:SetText(weights[key] and tostring(math.floor(weights[key] * 100 + .5) / 100) or "") end
        f.status:SetText("|cff85d6a0" .. L("Imported. Check the values and save.") .. "|r")
    end)
    apply:SetPoint("LEFT", f.import, "RIGHT", 10, 0)
    f.status = S.Text(f, "GameFontHighlightSmall", 18, importY + 52, 520, "")
    local copy = S.Button(f, 180, 26, L("Start from current profile"), function()
        local profile = GP.ActiveProfile()
        for _, key in ipairs(KEYS) do f.inputs[key]:SetText(profile[key] and tostring(profile[key]) or "") end
    end)
    copy:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
    local save = S.Primary(S.Button(f, 140, 26, L("Save and use"), function()
        local weights = {}
        for _, key in ipairs(KEYS) do
            local text = (f.inputs[key]:GetText() or ""):gsub(",", ".")
            local value = tonumber(text)
            if value and value ~= 0 then weights[key] = value end
        end
        GP.settings.custom = weights
        P.SetCustom(weights)
        GP.settings.autoProfile = false
        GP.settings.profile = "custom"
        f:Hide()
        GP.Render()
    end))
    save:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    return f
end

function GP.EditWeights()
    dialog = dialog or build()
    local profile = P.custom or GP.ActiveProfile()
    for _, key in ipairs(KEYS) do dialog.inputs[key]:SetText(profile[key] and tostring(profile[key]) or "") end
    dialog.import:SetText("")
    dialog.status:SetText("")
    dialog:Show()
end
