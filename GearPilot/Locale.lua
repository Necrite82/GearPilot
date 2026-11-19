local _, GP = ...
local de = {
    ["Find upgrades"] = "Upgrades finden", ["Equipped gear"] = "Getragene Ausrüstung",
    ["Bags"] = "Taschen", ["Quests"] = "Quests", ["Dungeons"] = "Dungeons",
    ["Level range"] = "Stufenbereich", ["Profile"] = "Profil",
    ["Melee"] = "Nahkampf", ["Caster"] = "Zauber", ["Ranged"] = "Fernkampf",
    ["Healer"] = "Heilung", ["Tank"] = "Tank",
    ["Score gain"] = "Punktegewinn", ["Current gear"] = "Aktuell getragen",
    ["No item equipped"] = "Platz frei", ["Requires level %d"] = "Benötigt Stufe %d",
    ["Pending item data"] = "Gegenstandsdaten werden geladen",
    ["No upgrades in this selection."] = "Keine Upgrades für diese Auswahl.",
    ["No quest or dungeon catalog installed yet."] = "Der Quest- und Dungeonkatalog ist noch nicht enthalten.",
    ["Select an item for details."] = "Wähle einen Gegenstand für Details.",
    ["Source"] = "Quelle", ["Unknown"] = "Unbekannt",
    ["Classic fallback"] = "Classic-Daten", ["Seen in Forever"] = "In Forever beobachtet",
    ["Quest %d"] = "Quest %d", ["Dungeon %d"] = "Dungeon %d",
    ["Prerequisites"] = "Vorquests", ["Level %d"] = "Stufe %d",
    ["Head"] = "Kopf", ["Neck"] = "Hals", ["Shoulders"] = "Schultern",
    ["Chest"] = "Brust", ["Waist"] = "Taille", ["Legs"] = "Beine",
    ["Feet"] = "Füße", ["Wrists"] = "Handgelenke", ["Hands"] = "Hände",
    ["Ring 1"] = "Ring 1", ["Ring 2"] = "Ring 2", ["Trinket 1"] = "Schmuck 1",
    ["Trinket 2"] = "Schmuck 2", ["Back"] = "Rücken", ["Main hand"] = "Waffenhand",
    ["Off hand"] = "Schildhand", ["Ranged slot"] = "Fernkampfplatz",
    ["Preview stat profiles; weapon damage and item effects are not scored."] =
        "Vorläufige Statprofile. Waffenschaden und Gegenstandseffekte werden nicht bewertet.",
}
function GP.L(key)
    return GetLocale() == "deDE" and de[key] or key
end
