# GearPilot

GearPilot is a standalone equipment upgrade planner for **World of Warcraft: Forever**. It compares equipment using role profiles and is designed to identify quest rewards and dungeon drops worth pursuing at your current level.

## Development build

Copy the inner `GearPilot` folder into `World of Warcraft/_forever_/Interface/AddOns/`, then open the window with `/gearpilot` or `/gp`. There are no addon dependencies. The interface is available in English and German.

- **Find upgrades → Bags:** compare supported armor, necklaces, cloaks and rings in your bags with equipped items. Hover an item for its game tooltip and select a row for the point gain and the item it would replace.
- **Equipped gear:** inspect your current equipment and empty slots.
- **Quests and Dungeons:** the views and independently adjustable level offsets are ready for catalog data. This build ships an empty catalog until the ForeverDB response format and coverage have been checked.

The preset role weights are provisional, and the score is a weighted sum of item stats. Weapons and trinkets are visible in equipped gear but excluded from recommendations. The comparison does not model effects, set bonuses or all restrictions on specific items. It conservatively avoids recommending duplicate ring IDs.

## Catalog

`GearPilot/Catalog.lua` defines the offline data boundary. Each row describes one item and one quest or dungeon source, with a recommendation level, optional faction, confirmed prerequisites and provenance. Source level drives the level window. Required equip level is evaluated separately against the game item data.

The planned build step will fetch ForeverDB JSON outside WoW and produce the catalog. API credentials belong in the build environment. The repository and addon contain no credentials. Real data and visible provider attribution will be added together.

## Checks

Run `lua5.1 tests/planner.lua` or let GitHub Actions run the Lua syntax check and planner fixtures.
