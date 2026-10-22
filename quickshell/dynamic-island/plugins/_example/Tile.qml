import QtQuick

import qs.modules.widgets

// Schnellkachel des Plugins (plugin.json: tiles.lamp.component).
//
// SettingsTiles.qml laedt diese Datei und setzt `plugin` (Kontext: settings,
// set(), name, ...) und `tileId` ("lamp"). Symbol und Titel kommen aus dem
// Manifest; hier reicht es, den Zustand zu zeigen und beim Tippen zu
// schalten. Unter 150 px Breite zeigt die Kachel von selbst nur das Symbol.
QuickTile {
    id: tile

    active: tile.plugin?.settings?.lamp === true
    subtitle: tile.active ? "An" : "Aus"
    icon: tile.active ? "lightbulb" : "light_off"

    onToggled: tile.plugin.set("lamp", !tile.active)
}
