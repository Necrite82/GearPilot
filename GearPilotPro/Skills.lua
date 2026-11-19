-- Weapon skills. On Forever a weapon type has to be learned and then leveled; an upgrade with a weapon you
-- cannot use yet, or with a low skill, needs a note. Read from the skill list (English and German names).
local _, GP = ...
local Skills = {}
GP.Skills = Skills

-- Weapon subclass -> skill names (enUS, deDE).
Skills.names = {
    [0] = { "Axes", "Äxte" }, [1] = { "Two-Handed Axes", "Zweihandäxte" }, [2] = { "Bows", "Bogen" },
    [3] = { "Guns", "Schusswaffen" }, [4] = { "Maces", "Streitkolben" }, [5] = { "Two-Handed Maces", "Zweihandstreitkolben" },
    [6] = { "Polearms", "Stangenwaffen" }, [7] = { "Swords", "Schwerter" }, [8] = { "Two-Handed Swords", "Zweihandschwerter" },
    [10] = { "Staves", "Stäbe" }, [13] = { "Fist Weapons", "Faustwaffen" }, [15] = { "Daggers", "Dolche" },
    [16] = { "Thrown", "Wurfwaffen" }, [18] = { "Crossbows", "Armbrüste" }, [19] = { "Wands", "Zauberstäbe" },
}
local lookup = {}
for subclass, names in pairs(Skills.names) do
    for _, name in ipairs(names) do lookup[name:lower()] = subclass end
end
Skills.lookup = lookup

-- Pure: skill lines { {name, rank, max}, ... } -> table subclass -> {rank, max}, plus whether any weapon skill
-- was found at all (then a missing one means "not learned").
function Skills.Parse(lines)
    local found, any = {}, false
    for _, line in ipairs(lines) do
        local subclass = type(line[1]) == "string" and lookup[line[1]:lower()]
        if subclass then
            found[subclass] = { rank = line[2], max = line[3] }
            any = true
        end
    end
    return found, any
end

local cache, cacheTime
function Skills.Read()
    local now = GetTime and GetTime() or 0
    if cache and cacheTime and now - cacheTime < 2 then return cache.found, cache.any end
    local lines = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local ok, name, header, _, rank, _, _, max = pcall(GetSkillLineInfo, i)
            if ok and name and not header then lines[#lines + 1] = { name, rank, max } end
        end
    end
    local found, any = Skills.Parse(lines)
    cache, cacheTime = { found = found, any = any }, now
    return found, any
end

-- nil = nothing to say (not a weapon, or the game gives no skill list). Otherwise { state, rank, max, name }:
-- state "missing" (not learned) or "low" (below 80 % of the maximum).
function Skills.Weapon(item)
    if not item or item.classID ~= 2 then return nil end
    local names = Skills.names[item.subclassID]
    if not names then return nil end
    local found, any = Skills.Read()
    local name = GetLocale and GetLocale() == "deDE" and names[2] or names[1]
    local skill = found[item.subclassID]
    if not skill then
        if any then return { state = "missing", name = name } end
        return nil
    end
    if type(skill.rank) == "number" and type(skill.max) == "number" and skill.max > 0 and skill.rank < skill.max * 0.8 then
        return { state = "low", name = name, rank = skill.rank, max = skill.max }
    end
    return nil
end

function Skills.Note(item)
    local info = Skills.Weapon(item)
    if not info then return nil end
    if info.state == "missing" then
        return (GP.L("Weapon skill %s not learned yet: visit a weapon master.")):format(info.name)
    end
    return (GP.L("Weapon skill %s only %d/%d: level it before you rely on this weapon.")):format(info.name, info.rank, info.max)
end
