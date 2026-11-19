# GearPilot 1.2.0

## Karte
- **Ganze Karte:** Das Kartenfenster zeigt jetzt die Details der Zonen (Orte, Wege, Wälder), auch in Gebieten, die du noch nicht erkundet hast. Umschaltbar auf **„Nur Erkundetes“**, wenn du selbst entdecken willst.
- Die Kartenteile kommen aus den Tabellen des Forever-Clients und werden jede Woche automatisch aktualisiert. Bis sie da sind, zeigt die Karte deine erkundeten Gebiete wie die Weltkarte.

## Questreihen
- **Zugeklappt:** Eine Questreihe zeigt zuerst nur den ersten und den nächsten Schritt, „Alle n Schritte zeigen“ klappt sie auf.

## Erfahrungspunkte
- **EP bei jeder Quest:** in den Quest-Details (mit Gold), bei jedem Schritt einer Questreihe und bei jeder Dungeon-Quest.
- **Summen:** „noch 8.250 EP offen“ bei der Questreihe, die EP aller offenen Dungeon-Quests samt Vorquests in den Dungeon-Details und in der Dungeon-Liste.
- **Für dich gerechnet:** Quests weit unter deiner Stufe geben weniger (Classic-Regel: ab 6 Stufen darunter 80 %, 60 %, 40 %, 20 %, ab 10 Stufen 10 %). Auf Stufe 60 zählt das Gold.
- **Direkt vom Server:** GearPilot fragt die EP der angezeigten Quests beim Server an und merkt sie sich – so stimmen auch geänderte und neue Forever-Quests. Ohne Antwort nimmt es den Wert aus ForeverDB.
- **Test:** `/gpp ep <Quest-ID>` zeigt, was der Server zu einer Quest sagt, z. B. `/gpp ep 95775` (Versunkene Stadt).

Fragen, Ideen und Fehler im Discord: https://discord.gg/DpsBkHtQS
