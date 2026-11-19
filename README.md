# GearPilot

GearPilot finds equipment upgrades for **World of Warcraft: Forever**: items in your bags, quest rewards and dungeon drops in your level range, best first. The window uses the same layout as CraftPilot: navigation on the left, list and details on the right. English and German.

## Install (development build)

Download `dist/GearPilot-<version>.zip` from the repository, unpack it and copy the `GearPilotPro` folder into `World of Warcraft/_forever_/Interface/AddOns/` and open the window with `/gpp` or `/gearpilotpro`. If an older `GearPilot` folder from a previous development build is there, delete it.

Quest rewards and dungeon drops need the **ForeverDB** addon ([CurseForge](https://www.curseforge.com/wow/addons/forever-db), [GitHub](https://github.com/foreverfraddons/forever-db)). The CurseForge app installs it together with GearPilot; for a manual install copy its `ForeverDB` folder next to `GearPilotPro`. Bag upgrades work without it.

The internal name is `GearPilotPro` (folder, saved settings, window names) so it never collides with the unrelated MoP Classic addon called GearPilot. The name shown in game stays GearPilot.

## Pages

- **Slot filter** (menu in the filter bar): only one slot, e.g. weapons, chest or rings, on every upgrade list.
- **Best upgrades:** bags, quests and dungeons together, sorted by score gain; vendors, auction house and crafting can be added in the settings.
- **Quests:** items or **zones** (where questing pays most, with waypoints to every quest giver). Sort by score, distance or zone; dungeon quests are marked and can be hidden or shown alone. The details show the whole quest chain with waypoints (TomTom: an arrow per step; otherwise the game's map waypoint moves on by itself).
- **Dungeons:** items with boss and drop chance, or **per dungeon** with the expected gain of one run (score gain × drop chance; unknown chances count as 10 %) and its dungeon quests.
- **Buy & craft:** vendor gear (ForeverDB vendors of your faction, price estimated from the vendor sell price), the auction house (Auctionator prices) and recipes from CraftPilot's catalog; sort by score, price or score per gold, with a maximum price.
- **Auction house:** upgrades from your last Auctionator scan (required level from 10 below your level), with the age of each price, a maximum price (presets or your own gold amount), sorting by score, price or score per gold, and a search button while the auction house is open.
- **Bags:** upgrades, or gear that **can go** (not usable for your class or worse than what you wear); items CraftPilot reserves are never listed.
- **Equipped gear:** every slot with its score and the values that count for your profile. **Weapon setup** compares your best two-hand weapon with your best main hand + off hand (a second weapon for dual wielders, shield or held item otherwise), from what you wear and carry or from every source; an off-hand weapon's DPS counts half.
- **Settings:** level range, stat profile (automatic from your talents, six built-in profiles or your own, Pawn / WoWSims import), sources, minimum drop chance and the helpers below.

## Helpers outside the window

- **Item tooltip:** how much better or worse an item is than what you wear, with a green or red arrow, plus a weapon skill note.
- **Quest rewards:** the best reward is marked in the quest window; without an upgrade, the one with the highest vendor price.
- **Need and greed:** a chat line per roll saying whether the item is an upgrade for you.
- **Weapon skills:** a note when a weapon type is not learned yet or its skill is low.
- **Minimap button** (drag it around the minimap; right click opens the settings) and an entry in the game's addon compartment.

The window can be resized with the grip in the bottom right corner; size and position are saved. Quests limited to one race (e.g. humans only) are only shown to that race. Spell school damage (fire, frost, ...) is scored per school, so a Pawn fire scale does not count frost damage. Quest chains: skipped steps (breadcrumbs, optional quests) count as done, grey quests are marked, a filter shows only chains you have started, and quests whose alternative (exclusiveTo) you have done are hidden. A Classic quest and its Forever replacement count as done in either version. Quest chains show every step with the game's quest icons: done, in your quest log, next.

## Scoring

The details show the value differences as bars, as in CraftPilot: their length is the effect on the score.

Each item gets a score from its values and the weights of the chosen profile (melee strength, melee agility, ranged, caster, healer, tank). The game's item stats miss most caster, healer and hunter values on Forever (spell damage and healing, mana per 5 sec., crit and hit chance are "Equip:" lines), so GearPilot also reads the tooltip in English and German. Weapon DPS counts; ranged weapons and wands are scored separately. Proficiencies are strict: mail for hunters and shamans and plate for warriors and paladins only from level 40, judged at the level you can actually wear the item. Two-hand weapons are compared against main and off hand together, quest choice rewards only list the best item of a quest, and class proficiencies (armor, shields, weapons, dual wield) are respected.

The weights are provisional. Random proc effects and set bonuses are not scored.

## Data

Quest rewards (`rew`, `qrw`), quest details (`quest`, `qx`, `qg`) and drops (`drop`, `npc`, `spw`, `ind`, `dng`) come from ForeverDB, which merges QuestieDB (Forever), VMaNGOS, cMaNGOS, pfQuest, AllTheThings and in-game recordings and is published under GPL-3.0. GearPilot loads it on demand the first time the window opens. Item values come from the game client.

## Checks

`lua5.1 tests/run.lua` runs the tooltip parser, planner and source checks. `python3 tools/build_release.py` rebuilds the install archive in `dist/`; GitHub Actions checks the Lua syntax, runs the tests and fails when the archive does not match the source.

## License

GPL-3.0.
