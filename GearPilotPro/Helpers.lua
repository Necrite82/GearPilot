-- Help at the right moment: the best quest reward is marked in the quest window, and need/greed rolls get a
-- chat line saying whether the item is an upgrade.
local _, GP = ...
local P, L = GP.Planner, GP.L

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffe0b050GearPilot|r " .. text) end
end
local function compare(link)
    if not link then return nil, nil end
    local item = GP.ItemData(link)
    if not item or not item.name then return nil, item end
    local player = GP.Player()
    return P.Compare(item, GP.ReadGear(), GP.ActiveProfile(), player.class, player.level), item
end

-- Quest rewards -----------------------------------------------------------------------------------------------
local marks = {}
local function rewardButton(index)
    local frame = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    if QuestInfo_GetRewardButton and frame then
        local ok, button = pcall(QuestInfo_GetRewardButton, frame, index)
        if ok and button then return button end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. index] or _G["QuestInfoItem" .. index]
end
local function clearMarks()
    for _, mark in pairs(marks) do mark:Hide() end
end
local function mark(button, upgrade)
    local m = marks[button]
    if not m then
        m = CreateFrame("Frame", nil, button, "BackdropTemplate")
        m:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        m:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        m:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        m.icon = m:CreateTexture(nil, "OVERLAY")
        m.icon:SetSize(16, 16)
        m.icon:SetPoint("TOPRIGHT", m, "TOPRIGHT", -2, -2)
        marks[button] = m
    end
    if upgrade then
        m:SetBackdropBorderColor(.52, .84, .63, 1)
        m.icon:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    else
        m:SetBackdropBorderColor(.88, .69, .31, 1)
        m.icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    end
    m:Show()
end

local attempts = 0
local function markRewards()
    clearMarks()
    if not (GP.settings and GP.settings.rewardHelp) or not GetNumQuestChoices then return end
    local count = GetNumQuestChoices()
    if count < 2 then return end
    local best, bestGain, richest, richestPrice, loading = nil, nil, nil, 0, false
    for i = 1, count do
        local link = GetQuestItemLink("choice", i)
        local result, item = compare(link)
        if not (item and item.name) then loading = true end
        if result and result.usable and not result.worn and result.gain and result.gain > 0
            and (not bestGain or result.gain > bestGain) then
            bestGain = result.gain
            best = { index = i, link = link, percent = result.percent }
        end
        local price = item and item.sellPrice or 0
        if price > (richestPrice or 0) then richest, richestPrice = { index = i, link = link }, price end
    end
    if loading and attempts < 6 then
        attempts = attempts + 1
        C_Timer.After(0.3, markRewards)
        return
    end
    local button
    if best then
        button = rewardButton(best.index)
        if button then mark(button, true) end
        say(L("Best reward for you: ") .. best.link .. (best.percent and (" (" .. ("+%d %%"):format(math.floor(best.percent + .5)) .. ")") or ""))
    elseif richest then
        button = rewardButton(richest.index)
        if button then mark(button, false) end
        say(L("No upgrade among the rewards; the highest vendor price: ") .. richest.link)
    end
end

local quest = CreateFrame("Frame")
for _, event in ipairs({ "QUEST_COMPLETE", "QUEST_DETAIL", "QUEST_FINISHED" }) do quest:RegisterEvent(event) end
quest:SetScript("OnEvent", function(_, event)
    if event == "QUEST_FINISHED" then clearMarks() return end
    attempts = 0
    C_Timer.After(0.1, markRewards)
end)

-- Loot rolls ---------------------------------------------------------------------------------------------------
local function announceRoll(rollID, tries)
    if not (GP.settings and GP.settings.rollHelp) or not GetLootRollItemLink then return end
    local link = GetLootRollItemLink(rollID)
    if not link then return end
    local result, item = compare(link)
    if not (item and item.name) then
        if (tries or 0) < 5 then C_Timer.After(0.3, function() announceRoll(rollID, (tries or 0) + 1) end) end
        return
    end
    if not result then return end
    if result.usable == false then
        say(link .. " · " .. L("not usable for your class"))
    elseif result.worn then
        return
    elseif result.gain and result.gain > 0 then
        local note = GP.Skills.Note(item)
        say(link .. " · |cff85d6a0" .. (result.percent and (L("%d %% better"):format(math.floor(result.percent + .5))) or L("free slot"))
            .. "|r" .. (note and (" · " .. note) or ""))
    else
        say(link .. " · |cffeb786b" .. L("no upgrade") .. "|r")
    end
end
local roll = CreateFrame("Frame")
roll:RegisterEvent("START_LOOT_ROLL")
roll:SetScript("OnEvent", function(_, _, rollID) announceRoll(rollID, 0) end)
