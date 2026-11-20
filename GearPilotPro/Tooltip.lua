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

-- 1.6.3: the line of an item is worked out once and kept until your gear, level, talents or profile change
-- (a tooltip is drawn again and again while you hover over an item).
local lines = {}
function GP.TooltipChanged() lines = {} end
function GP.TooltipLine(link)
    local cached = lines[link]
    if cached then return cached end
    local item = GP.ItemData(link)
    if not item or not item.name then return nil end
    local player = GP.Player()
    local profile = GP.ActiveProfile()
    local result = P.Compare(item, GP.ReadGear(), profile, player.class, player.level)
    if not result then return nil end
    local entry
    if result.usable == false then
        entry = { left = "GearPilot", text = L("not usable for your class"), r = .62, g = .64, b = .68 }
    else
        local text, r, g, b = format(result)
        if text then
            entry = { left = "GearPilot · " .. L(profile.name), text = text, r = r, g = g, b = b,
                note = not result.worn and GP.Skills.Note(item) or nil }
        else
            entry = { none = true }
        end
    end
    entry.id = item.id
    lines[link] = entry
    return entry
end
local function annotate(tooltip, link)
    if not (GP.settings and GP.settings.tooltip ~= false and link) then return end
    local entry = GP.TooltipLine(link)
    if not entry or entry.none then return end
    tooltip:AddDoubleLine(entry.left, entry.text, .88, .69, .31, entry.r, entry.g, entry.b)
    if entry.note then tooltip:AddLine(entry.note, .92, .66, .35, true) end
    if GP.Wish and GP.Wish.Has(link) then
        local wish = GP.Wish.List()[entry.id]
        tooltip:AddLine(L("On your wishlist") .. (wish and wish.goal and (" · " .. L("goal")) or ""), .88, .69, .31)
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
