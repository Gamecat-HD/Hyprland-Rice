import QtQuick

import qs.modules.widgets

// Schnellkachel: Desktop-Widgets ein-/ausblenden (Einstellung `hidden`).
// Ausgeblendet gibt es die Widgets nur beim Anordnen (SUPER+ALT+D) –
// sonst werden sie gar nicht erst gebaut und kosten nichts.
QuickTile {
    id: tile

    active: tile.plugin?.settings?.hidden !== true
    subtitle: tile.active ? "Sichtbar" : "Nur im Editor"
    icon: tile.active ? "widgets" : "visibility_off"

    onToggled: tile.plugin.set("hidden", tile.active)
}
