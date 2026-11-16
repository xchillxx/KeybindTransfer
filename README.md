# KeybindTransfer

Kopiert **nur deine Tastenbelegung** zwischen WoW Forever, Retail und den Classic-Versionen. Keine Zauber, keine Makros, kein Leisten-Layout.

Die Belegung ist an Befehle wie `ACTIONBUTTON1` gebunden, nicht an Zauber. Hast du in Classic "Aktionsleiste 1, Slot 1 = Taste Q", liegt Q danach auch in Forever auf Aktionsleiste 1, Slot 1, egal welcher Zauber dort steht.

## Benutzung

1. Im Quellspiel `/kbt` eingeben und **Exportieren** klicken. Den markierten Text mit Strg+C kopieren.
2. Im Zielspiel `/kbt` eingeben, den Text einfügen, **Vorschau** klicken.
3. Die Vorschau zeigt, was übertragen wird, was im Ziel nicht existiert (wird übersprungen) und wie viele bestehende Tasten überschrieben werden.
4. **Anwenden** klicken. Vorher wird automatisch ein Backup angelegt. **Rückgängig** stellt den alten Stand wieder her (die letzten 5 Backups bleiben erhalten).

| Befehl | Wirkung |
| --- | --- |
| `/kbt` | Fenster öffnen oder schließen |
| `/kbt export` | Direkt exportieren |
| `/kbt import` | Fenster mit leerem Textfeld öffnen |
| `/kbt undo` | Letzten Import rückgängig machen |

## Hinweise

- Befehle, die es im Zielspiel nicht gibt (zum Beispiel Retail-only Funktionen), werden übersprungen und in der Vorschau aufgelistet.
- Im Kampf ist Anwenden und Rückgängig gesperrt.
- Der Export-String ist einzeilig und kann per Chat, Discord oder Notepad weitergegeben werden. Ein abgeschnittener String wird erkannt und abgelehnt.

## Kompatibilität

Eine `.toc` für alle Versionen (Interface 16001 Forever, Retail, Classic Era, TBC Anniversary, Wrath, MoP Classic). Die Interface-Nummern müssen bei jedem Patch geprüft werden.

---

# KeybindTransfer (English)

Copies **only your keybinds** between WoW Forever, Retail and Classic. No spells, no macros, no action bar layout.

Bindings belong to commands such as `ACTIONBUTTON1`, not to spells. If key Q is on "Action Bar 1, slot 1" in Classic, it will be on the same slot in Forever, whatever spell sits there.

1. In the source game, type `/kbt`, click **Export**, copy the text.
2. In the target game, type `/kbt`, paste the text, click **Preview**.
3. Click **Apply**. A backup is created automatically, **Undo** restores it.

Commands unknown to the target client are skipped and listed. Apply and Undo are blocked in combat.
