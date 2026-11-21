-- The route destination, recommendation and inline zone picker above the task list.
local _, GP = ...
local S, L = GP.Style, GP.L
local ROW_HEIGHT, VISIBLE_ROWS = 27, 7

function GP.CreateRouteHeader(parent, redraw)
    local header = S.Surface(parent, "panel")
    local mode = S.Text(header, "GameFontDisableSmall", 11, 7, 240)
    local zone = S.Text(header, "GameFontNormal", 11, 22, 240)
    local recommendation = S.Text(header, "GameFontDisableSmall", 11, 43, 240)
    recommendation:SetWordWrap(false)
    local choice
    local reset = S.Button(header, 157, 26, L("Use recommendation"), function()
        header:ClosePicker()
        GP.QuestRoute.SetZone(nil)
        redraw()
    end)
    reset:SetPoint("RIGHT", header, "RIGHT", -9, 0)
    local choose = S.Button(header, 114, 26, L("Choose zone"), function()
        if header.picking then
            header:ClosePicker()
        else
            header.picking = true
            header.selectedZone = GP.settings.routeZone or (header.plan.zone and header.plan.zone.zone)
            header.choices = GP.QuestRoute.ZoneChoices(ForeverDB, header.plan)
            local exists = false
            for _, option in ipairs(header.choices) do
                if option.id == header.selectedZone then
                    exists = true
                    break
                end
            end
            if not exists then header.selectedZone = header.choices[1] and header.choices[1].id end
        end
        redraw()
    end)

    local picker = S.Surface(parent, "raised")
    local pickerLabel = S.Text(picker, "GameFontHighlightSmall", 11, 12, 94, L("Destination"))
    local dropdown = S.Surface(parent, "raised")
    dropdown:SetFrameStrata("DIALOG")
    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouse(true)
    local scroll = CreateFrame("ScrollFrame", nil, dropdown, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -24, 5)
    local content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    local buttons = {}

    local function renderSelection()
        local text = L("No matching open quests")
        for _, option in ipairs(header.choices or {}) do
            if option.id == header.selectedZone then
                text = option.name or ("#" .. option.id)
                break
            end
        end
        choice:SetText(text)
    end

    choice = S.Button(picker, 210, 26, "", function()
        if dropdown:IsShown() then
            dropdown:Hide()
        else
            scroll:SetVerticalScroll(0)
            dropdown:Show()
        end
    end)
    choice:SetPoint("TOPLEFT", picker, "TOPLEFT", 105, -7)
    local label = choice:GetFontString()
    label:ClearAllPoints()
    label:SetPoint("LEFT", choice, "LEFT", 8, 0)
    label:SetPoint("RIGHT", choice, "RIGHT", -24, 0)
    local arrow = choice:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(20, 20)
    arrow:SetPoint("RIGHT", choice, "RIGHT", -3, 0)
    dropdown:SetPoint("TOPLEFT", choice, "BOTTOMLEFT", 0, -3)
    local apply = S.Button(picker, 124, 26, L("Quest in this zone"), function()
        local id = header.selectedZone
        if not id then return end
        header:ClosePicker()
        GP.QuestRoute.SetZone(id)
        redraw()
    end)
    apply:SetPoint("LEFT", choice, "RIGHT", 7, 0)

    function header:ClosePicker()
        self.picking, self.choices, self.selectedZone = nil, nil, nil
        picker:Hide()
        dropdown:Hide()
    end

    function header:HideAll()
        self:Hide()
        self:ClosePicker()
    end

    function header:Render(plan, width, top)
        self.plan = plan
        if not plan then
            self:HideAll()
            return 0
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -top)
        self:SetSize(width, 64)
        self:Show()
        local name = plan.zone and plan.zone.name or L("No matching open quests")
        mode:SetText(plan.chosenZone and L("Your choice") or plan.mine and L("My route") or L("Automatic"))
        zone:SetText(plan.mine and L("My quests") or name)
        local suggested = plan.recommended and plan.recommended.name
        recommendation:SetText(suggested and (L("Recommended: %s")):format(suggested) or "")
        local canReset = plan.chosenZone ~= nil or plan.mine == true
        reset:SetShown(canReset)
        choose:ClearAllPoints()
        if canReset then choose:SetPoint("RIGHT", reset, "LEFT", -7, 0)
        else choose:SetPoint("RIGHT", self, "RIGHT", -9, 0) end
        local labelWidth = width - (canReset and 303 or 140)
        mode:SetWidth(labelWidth)
        zone:SetWidth(labelWidth)
        recommendation:SetWidth(labelWidth)

        if not self.picking then return 72 end
        picker:ClearAllPoints()
        picker:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
        picker:SetSize(width, 40)
        picker:Show()
        pickerLabel:Show()
        local dropdownWidth = math.min(370, width - 250)
        choice:SetWidth(dropdownWidth)
        dropdown:SetWidth(dropdownWidth)
        local options = self.choices or {}
        content:SetSize(dropdownWidth - 29, math.max(1, #options * ROW_HEIGHT))
        dropdown:SetHeight(10 + math.max(1, math.min(VISIBLE_ROWS, #options)) * ROW_HEIGHT)
        for i, option in ipairs(options) do
            local b = buttons[i]
            if not b then
                b = S.Button(content, dropdownWidth - 29, 25, "", function(button)
                    self.selectedZone = button.zoneID
                    renderSelection()
                    dropdown:Hide()
                end)
                b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
                buttons[i] = b
            end
            b.zoneID = option.id
            b:SetWidth(dropdownWidth - 29)
            b:SetText(("%s  ·  %d"):format(option.name or ("#" .. option.id), option.count))
            b:Show()
        end
        for i = #options + 1, #buttons do buttons[i]:Hide() end
        renderSelection()
        choice:SetEnabled(#options > 0)
        apply:SetEnabled(self.selectedZone ~= nil)
        S.Primary(apply)
        return 118
    end
    header:HideAll()
    return header
end
