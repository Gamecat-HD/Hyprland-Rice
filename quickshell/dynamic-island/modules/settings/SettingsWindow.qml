pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Einstellungs-Fenster. Der Inhalt – Gruppenleiste, Zeilen, Plugin-
// Verwaltung – ist SettingsCard.qml; hier steht nur das Fenster, das sie
// traegt.
//
// Ein normales schwebendes Fenster (xdg-toplevel), keine Layer-Oberflaeche:
// es bekommt Fokus wie jede App, laesst sich mit SUPER + Ziehen verschieben,
// und SUPER + C schliesst es nur, wenn es selbst das aktive Fenster ist.
// Hyprland setzt es schwebend und mittig und laesst Rand, Schatten und
// Transparenz weg (Fenster-Regel "dynamic-island-settings" in
// profiles/simple.lua). Das Fenster ist etwas groesser als die Karte, damit
// deren Schatten Platz hat; Klicks nimmt nur die Karte an (mask).
//
// Gebaut wird es erst beim Oeffnen (LazyLoader) und beim Schliessen wieder
// verworfen.
LazyLoader {
    active: SettingsState.open

    FloatingWindow {
        id: win

        readonly property real inset: 28
        // Etwas hoeher als frueher (580): die Gruppenleiste traegt jetzt auch
        // die Plugins
        readonly property size fixedSize: Qt.size(880 + inset * 2, 640 + inset * 2)

        title: "dynamic-island-settings"
        color: "transparent"

        implicitWidth: win.fixedSize.width
        implicitHeight: win.fixedSize.height
        // Feste Groesse – Hyprland soll es nicht in die Kacheln ziehen
        minimumSize: win.fixedSize
        maximumSize: win.fixedSize

        mask: Region {
            item: card
        }

        // Vom Compositor geschlossen (SUPER + C, Fenster-Menue …)
        onClosed: SettingsState.close()
        onVisibleChanged: {
            if (visible)
                card.reset();
        }
        // Entsteht bereits sichtbar – dann kommt kein Wechsel-Signal
        Component.onCompleted: if (visible) Qt.callLater(win.visibleChanged)

        SettingsCard {
            id: card

            anchors {
                fill: parent
                margins: win.inset
            }
            shown: win.visible
        }
    }
}
