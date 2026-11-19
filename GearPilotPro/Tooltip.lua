-- One line in every item tooltip: how much better or worse the item is than what you wear, for your profile.
local _, GP = ...
local P, L = GP.Planner, GP.L
local UP = "|TInterface\\Buttons\\Arrow-Up-Up:12:12:0:3|t"
local DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-3|t"

local function format(result)
    if result.worn then return L("worn"), .62, .64, .68 end
    if not result.percent then
        if result.gain > 0 then return UP .. " " .. L("free slot"), .52, .84, .63 end
        return nil
    end
    local value = math.floor(math.abs(result.percent) + .5)
    if value == 0 then return L("about equal"), .62, .64, .68 end
    if result.percent > 0 then return UP .. " " .. (L("%d %% better"):format(value)), .52, .84, .63 end
    return DOWN .. " " .. (L("%d %% worse"):format(value)), .92, .47, .42
end

local function annotate(tooltip, link)
    if not (GP.settings and GP.settings.tooltip ~= false and link) then return end
    local item = GP.ItemData(link)
    if not item or not item.name then return end
    local player = GP.Player()
    local profile = GP.ActiveProfile()
    local result = P.Compare(item, GP.ReadGear(), profile, player.class, player.level)
    if not result then return end
    if result.usable == false then
        tooltip:AddDoubleLine("GearPilot", L("not usable for your class"), .88, .69, .31, .62, .64, .68)
    else
        local text, r, g, b = format(result)
        if not text then return end
        tooltip:AddDoubleLine("GearPilot · " .. L(profile.name), text, .88, .69, .31, r, g, b)
        local note = not result.worn and GP.Skills.Note(item)
        if note then tooltip:AddLine(note, .92, .66, .35, true) end
    end
    tooltip:Show()
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local link = data and data.hyperlink
        if not link and tooltip.GetItem then link = select(2, tooltip:GetItem()) end
        annotate(tooltip, link)
    end)
elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) annotate(tooltip, select(2, tooltip:GetItem())) end)
end
