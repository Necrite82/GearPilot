# GearPilot

GearPilot finds equipment upgrades for **World of Warcraft: Forever**: items in your bags, quest rewards and dungeon drops in your level range, best first. The window uses the same layout as CraftPilot: navigation on the left, list and details on the right. English and German.

## Install (development build)

Download `dist/GearPilot-<version>.zip` from the repository, unpack it and copy the `GearPilotPro` folder into `World of Warcraft/_forever_/Interface/AddOns/` and open the window with `/gpp` or `/gearpilotpro`. If an older `GearPilot` folder from a previous development build is there, delete it.

Quest rewards and dungeon drops need the **ForeverDB** addon ([CurseForge](https://www.curseforge.com/wow/addons/forever-db), [GitHub](https://github.com/foreverfraddons/forever-db)). The CurseForge app installs it together with GearPilot; for a manual install copy its `ForeverDB` folder next to `GearPilotPro`. Bag upgrades work without it.

The internal name is `GearPilotPro` (folder, saved settings, window names) so it never collides with the unrelated MoP Classic addon called GearPilot. The name shown in game stays GearPilot.

## Pages

- **Best upgrades:** bags, quests and dungeons together, sorted by score gain.
- **Quests / Dungeons / Bags:** one source each. Quests show level, quest giver, zone and prerequisites; dungeons show the boss and the drop chance.
- **Equipped gear:** every slot with its score and the values that count for your profile.
- **Settings:** level range below and above your level, stat profile, minimum drop chance.

## Scoring

Each item gets a score from its values and the weights of the chosen profile (melee strength, melee agility, ranged, caster, healer, tank). The game's item stats miss most caster, healer and hunter values on Forever (spell damage and healing, mana per 5 sec., crit and hit chance are "Equip:" lines), so GearPilot also reads the tooltip in English and German. Weapon DPS counts; ranged weapons and wands are scored separately. Two-hand weapons are compared against main and off hand together, quest choice rewards only list the best item of a quest, and class proficiencies (armor, shields, weapons, dual wield) are respected.

The weights are provisional. Random proc effects and set bonuses are not scored.

## Data

Quest rewards (`rew`, `qrw`), quest details (`quest`, `qx`, `qg`) and drops (`drop`, `npc`, `spw`, `ind`, `dng`) come from ForeverDB, which merges QuestieDB (Forever), VMaNGOS, cMaNGOS, pfQuest, AllTheThings and in-game recordings and is published under GPL-3.0. GearPilot loads it on demand the first time the window opens. Item values come from the game client.

## Checks

`lua5.1 tests/run.lua` runs the tooltip parser, planner and source checks. `python3 tools/build_release.py` rebuilds the install archive in `dist/`; GitHub Actions checks the Lua syntax, runs the tests and fails when the archive does not match the source.

## License

GPL-3.0.
