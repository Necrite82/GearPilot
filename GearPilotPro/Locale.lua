local _, GP = ...
local de = {
    -- Pages and navigation
    ["Best upgrades"] = "Beste Upgrades", ["Quests"] = "Quests", ["Dungeons"] = "Dungeons", ["Bags"] = "Taschen",
    ["Equipped gear"] = "Ausrüstung", ["Settings"] = "Einstellungen", ["Help"] = "Hilfe",
    ["Gear companion"] = "Ausrüstungsbegleiter",
    ["Bags, quests and dungeons in your level range, best first"] = "Taschen, Quests und Dungeons in deinem Stufenbereich, das Beste zuerst",
    ["Quest rewards that improve your gear"] = "Quest-Belohnungen, die deine Ausrüstung verbessern",
    ["Dungeon drops that improve your gear"] = "Dungeon-Beute, die deine Ausrüstung verbessert",
    ["Items in your bags that beat what you wear"] = "Gegenstände in deinen Taschen, die besser sind als deine Ausrüstung",
    ["Your equipment and its score"] = "Deine Ausrüstung und ihre Punkte",
    ["Level range, stat profile and data"] = "Stufenbereich, Werteprofil und Daten",
    ["How GearPilot works"] = "So funktioniert GearPilot",
    -- Profiles
    ["Melee (strength)"] = "Nahkampf (Stärke)", ["Melee (agility)"] = "Nahkampf (Beweglichkeit)", ["Ranged"] = "Fernkampf",
    ["Caster"] = "Zauberschaden", ["Healer"] = "Heilung", ["Tank"] = "Tank",
    -- Slots
    ["Head"] = "Kopf", ["Neck"] = "Hals", ["Shoulders"] = "Schultern", ["Back"] = "Rücken", ["Chest"] = "Brust",
    ["Wrists"] = "Handgelenke", ["Hands"] = "Hände", ["Waist"] = "Taille", ["Legs"] = "Beine", ["Feet"] = "Füße",
    ["Ring 1"] = "Ring 1", ["Ring 2"] = "Ring 2", ["Trinket 1"] = "Schmuck 1", ["Trinket 2"] = "Schmuck 2",
    ["Main hand"] = "Waffenhand", ["Off hand"] = "Schildhand", ["Ranged slot"] = "Distanz",
    -- Values
    ["Strength"] = "Stärke", ["Agility"] = "Beweglichkeit", ["Stamina"] = "Ausdauer", ["Intellect"] = "Intelligenz",
    ["Spirit"] = "Willenskraft", ["Attack power"] = "Angriffskraft", ["Ranged attack power"] = "Distanzangriffskraft",
    ["Spell damage and healing"] = "Zauberschaden und Heilung", ["Healing"] = "Heilung",
    ["School spell damage"] = "Schaden einer Magieschule", ["Mana per 5 sec."] = "Mana alle 5 Sek.",
    ["Critical strike %"] = "Kritische Treffer %", ["Spell critical strike %"] = "Kritische Zaubertreffer %",
    ["Hit %"] = "Trefferchance %", ["Spell hit %"] = "Zaubertrefferchance %", ["Defense"] = "Verteidigung",
    ["Dodge %"] = "Ausweichen %", ["Parry %"] = "Parieren %", ["Block %"] = "Blocken %", ["Block value"] = "Blockwert",
    ["Armor"] = "Rüstung", ["Weapon DPS"] = "Waffen-DPS", ["Ranged weapon DPS"] = "Distanzwaffen-DPS",
    ["Wand DPS"] = "Zauberstab-DPS", ["Haste"] = "Tempo", ["Health per 5 sec."] = "Gesundheit alle 5 Sek.",
    -- Header, footer, sidebar
    ["Level range"] = "Stufenbereich", ["Level %d"] = "Stufe %d", ["Level %d · range %d–%d"] = "Stufe %d · Bereich %d–%d",
    ["Quests and dungeons in this range are compared. Bag items are always compared."] =
        "Quests und Dungeons in diesem Bereich werden verglichen. Taschen immer.",
    ["Click: settings"] = "Anklicken: Einstellungen", ["Data from "] = "Datenstand ",
    ["Quest rewards and dungeon drops from ForeverDB (GPL-3.0)."] = "Quest-Belohnungen und Dungeon-Beute aus ForeverDB (GPL-3.0).",
    ["ForeverDB is not installed. Quests and dungeons need it; the CurseForge app installs it with GearPilot."] =
        "ForeverDB ist nicht installiert. Quests und Dungeons brauchen es; die CurseForge-App installiert es mit GearPilot.",
    ["ForeverDB missing"] = "ForeverDB fehlt", ["Data: ForeverDB (GPL-3.0)"] = "Daten: ForeverDB (GPL-3.0)",
    ["Provisional weights · weapon DPS counts, random proc effects do not · data: ForeverDB"] =
        "Vorläufige Gewichtungen · Waffen-DPS zählt, Zufallseffekte nicht · Daten: ForeverDB",
    ["Stat profile"] = "Werteprofil",
    ["Which values count. Provisional weights; weapon DPS is included, random proc effects are not."] =
        "Welche Werte zählen. Vorläufige Gewichtungen; Waffen-DPS zählt mit, Zufallseffekte nicht.",
    -- List and detail
    ["In your bags"] = "In deinen Taschen", ["Quest"] = "Quest", ["Empty slot"] = "Platz frei",
    ["No item equipped"] = "Nichts angelegt", ["Loading item data …"] = "Gegenstandsdaten werden geladen …",
    ["No upgrades in this selection. Try a wider level range in the settings."] =
        "Keine Upgrades in dieser Auswahl. Probier in den Einstellungen einen größeren Stufenbereich.",
    ["ForeverDB is not installed. Quests and dungeons need it; the CurseForge app installs it with GearPilot. Bag upgrades work without it."] =
        "ForeverDB ist nicht installiert. Quests und Dungeons brauchen es; die CurseForge-App installiert es mit GearPilot. Taschen-Upgrades gehen auch ohne.",
    ["Select an item for details."] = "Wähle einen Gegenstand für Details.",
    ["Score gain"] = "Punktegewinn", ["Replaces"] = "Ersetzt", ["Drop chance"] = "Dropchance",
    ["unknown"] = "unbekannt", ["Required level"] = "Benötigte Stufe", ["Where to get it"] = "Woher",
    ["Already in your bags."] = "Liegt schon in deinen Taschen.", ["Equip"] = "Anlegen",
    ["Quest level %d"] = "Queststufe %d", ["from level %d"] = "ab Stufe %d", ["Quest giver: "] = "Questgeber: ",
    ["Prerequisites: "] = "Vorquests: ",
    ["Choice reward: you get one item of this quest. GearPilot shows the best one for you."] =
        "Auswahlbelohnung: Du bekommst einen Gegenstand dieser Quest. GearPilot zeigt den besten für dich.",
    ["raid"] = "Schlachtzug", ["Drops from: "] = "Beute von: ", ["Drop chance about %d %%"] = "Dropchance etwa %d %%",
    ["Drop chance not known yet (new in Forever or too few kills recorded)."] =
        "Dropchance noch unbekannt (neu in Forever oder zu wenige Kills erfasst).",
    ["Values compared"] = "Werte im Vergleich", ["No value differences."] = "Keine Unterschiede bei den Werten.",
    ["Score"] = "Punkte", ["Profile"] = "Profil", ["Values"] = "Werte", ["(not weighted)"] = "(zählt nicht)",
    ["No readable values."] = "Keine lesbaren Werte.",
    -- Settings
    ["Quests and dungeons from this many levels below to this many levels above your level are compared."] =
        "Verglichen werden Quests und Dungeons von so vielen Stufen unter bis so vielen Stufen über deiner Stufe.",
    ["Levels below"] = "Stufen darunter", ["Levels above"] = "Stufen darüber",
    ["Choose what your character needs. The weights are provisional and will be refined with player feedback."] =
        "Wähle, was dein Charakter braucht. Die Gewichtungen sind vorläufig und werden mit Rückmeldungen verfeinert.",
    ["Minimum drop chance"] = "Mindest-Dropchance",
    ["Dungeon items below this chance are left out. Unknown chances from new Forever dungeons and bosses are always shown."] =
        "Dungeon-Beute unter dieser Chance wird ausgeblendet. Unbekannte Chancen aus neuen Forever-Dungeons und von Bossen werden immer gezeigt.",
    ["Installed, data from "] = "Installiert, Datenstand ",
    ["Quest rewards and dungeon drops come from ForeverDB (GPL-3.0, github.com/foreverfraddons/forever-db)."] =
        "Quest-Belohnungen und Dungeon-Beute stammen aus ForeverDB (GPL-3.0, github.com/foreverfraddons/forever-db).",
    ["Not installed. Install ForeverDB with the CurseForge app; bag upgrades work without it."] =
        "Nicht installiert. Installiere ForeverDB über die CurseForge-App; Taschen-Upgrades gehen auch ohne.",
    -- Help
    ["GearPilot scores every item with the values of your stat profile and compares it with what you wear in the same slot. The score gain is the difference."] =
        "GearPilot bewertet jeden Gegenstand mit den Werten deines Profils und vergleicht ihn mit dem, was du am selben Platz trägst. Der Punktegewinn ist der Unterschied.",
    ["Best upgrades lists bag items, quest rewards and dungeon drops together. Quests and dungeons only count inside your level range; quests you have done are hidden."] =
        "Beste Upgrades zeigt Taschen, Quest-Belohnungen und Dungeon-Beute zusammen. Quests und Dungeons zählen nur in deinem Stufenbereich; erledigte Quests sind ausgeblendet.",
    ["Quest choice rewards: you can take one item per quest, so only the best one is shown."] =
        "Auswahlbelohnungen: Pro Quest gibt es nur einen Gegenstand, deshalb steht nur der beste in der Liste.",
    ["Limits"] = "Grenzen", ["Commands"] = "Befehle",
    ["Weights are provisional. Random proc effects and set bonuses are not scored. Items the game has not loaded yet appear a moment later."] =
        "Die Gewichtungen sind vorläufig. Zufallseffekte und Set-Boni werden nicht bewertet. Gegenstände, die das Spiel noch nicht geladen hat, erscheinen einen Moment später.",
}
function GP.L(key)
    return GetLocale() == "deDE" and de[key] or key
end
GP.de = de
