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
- **Dungeons:** items with boss and drop chance, or **per dungeon** with the expected gain of one run (score gain × drop chance; an unknown chance counts with the boss's loot table share from AllTheThings, marked "estimated", otherwise 10 %) and its dungeon quests.
- **Buy & craft:** vendor gear (ForeverDB vendors of your faction, price estimated from the vendor sell price), the auction house (Auctionator prices) and recipes from CraftPilot's catalog; sort by score, price or score per gold, with a maximum price.
- **Auction house:** upgrades from your last Auctionator scan (required level from 10 below your level), with the age of each price, a maximum price (presets or your own gold amount), sorting by score, price or score per gold, and a search button while the auction house is open.
- **Wishlist:** add items with the button in any item details or with Ctrl+Alt-click (Alt-click stays with CraftPilot). Every source is listed (quests with chain, dungeons with boss, drop chance and entrance waypoint, vendors, open world mobs, world drop, CraftPilot recipes with hand-over, auction price) with a waypoint. One goal per slot is your own BIS list with progress; export and import as text. Hints in the chat: wishlist item in the auction house (at or below your wish price), your target or dungeon can drop one, received.
- **BIS (calculated):** GearPilot works out the best item per slot for your level range, level 60 pre-raid or level 60 with raids, from quests, dungeons, vendors and crafting with your profile's weights, and can take it over as goals. **This is GearPilot's own calculation, not an official BIS list:** set bonuses and random effects are not scored and the weights are provisional.
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

Dungeon bosses and their loot for the new Forever dungeons (The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, The Shaper's Terrace, City of Dalaran and others) come from [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) (MIT) and are shipped in `GearPilotPro/Data/Dungeons.lua`. They tell GearPilot which boss stands in which dungeon when ForeverDB has no spawn data yet, add boss loot without recorded drops and give dungeon entrances. `tools/dungeons/fetch_att.py` downloads ATT's Forever dungeon files, `tools/dungeons/build.lua` builds the data file; the workflow `.github/workflows/dungeons.yml` does both every Monday (or by hand) and opens a pull request `data/dungeons` when bosses or loot changed. For pull requests from that workflow, allow "GitHub Actions to create and approve pull requests" in the repository settings (Actions → General).

## Checks

`lua5.1 tests/run.lua` runs the tooltip parser, planner and source checks. `python3 tools/build_release.py` rebuilds the install archive in `dist/`; GitHub Actions checks the Lua syntax, runs the tests and fails when the archive does not match the source.

## Release

1. Set `## Version: x.y.z` in `GearPilotPro/GearPilotPro.toc`, run `python3 tools/build_release.py` and add `docs/RELEASE_x.y.z.md` (changelog).
2. Merge into `main`, then start **Actions → Release → Run workflow**. It runs the checks, creates the tag and GitHub release and uploads the ZIP to CurseForge with ForeverDB as required dependency (`tools/upload_curseforge.py`; needs `## X-Curse-Project-ID` in the TOC and the secret `CF_API_TOKEN`).

The CurseForge project description is `docs/CURSEFORGE_DESCRIPTION.md`.

## License

GPL-3.0. `Data/Dungeons.lua` contains data from AllTheThings, MIT License (`Data/LICENSE-AllTheThings.txt`).
