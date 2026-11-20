-- Access quests (1.6.1): raids and dungeons that need a quest chain before you can enter them (or a key).
-- Hand-kept list: the last quest of each chain per faction; GearPilot builds the whole chain from ForeverDB.
-- WoW Forever (Nov 2026): Onyxia's Lair needs the Drakefire Amulet (Blizzard's raid overview, Oct 20, 2026);
-- Barrow Deeps and Hyjal Summit name no attunement. The dungeon keys are the Classic ones and not confirmed
-- for Forever yet (confirmed = false).
local _, GP = ...
GP.Attunements = {
    { dungeon = "Onyxia's Lair", label = "Drakefire Amulet", required = true, confirmed = true,
        Alliance = 6502, Horde = 6602 },
    { dungeon = "Blackrock Spire", label = "Seal of Ascension (Upper Blackrock Spire)", confirmed = false,
        Alliance = 4743, Horde = 4743 },
    { dungeon = "Scholomance", label = "Skeleton Key", confirmed = false, Alliance = 5505, Horde = 5511 },
    { dungeon = "Blackrock Depths", label = "Shadowforge Key", confirmed = false, Alliance = 3802, Horde = 3802 },
}
