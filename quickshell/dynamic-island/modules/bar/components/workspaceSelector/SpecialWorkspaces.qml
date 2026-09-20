pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import "root:/"

// Special-Workspaces in der Selektor-Karte – dieselbe Idee wie
// caelestia/modules/bar/components/workspaces/SpecialWorkspaces.qml, nur
// horizontal und ohne Fenster-Icons:
//   - ein Chip pro EXISTIERENDEM Special-WS (special:<name>)
//   - der auf diesem Monitor offene leuchtet, Klick toggelt ihn
//   - Icons wie in caelestias utils/Icons.qml (Fallback: Anfangsbuchstabe)
//
// Sichtbar ist die Reihe nur, waehrend auf diesem Monitor ein Special offen
// ist – WorkspaceSelector blendet dafuer die Punkte weg. Eintritt ist der
// Klick auf den aktiven Punkt (der toggelt den generischen "special").
RowLayout {
    id: root

    required property HyprlandMonitor hyprMonitor

    // Offener Special auf DIESEM Monitor, z.B. "special:music" – sonst ""
    readonly property string activeSpecial: root.hyprMonitor?.lastIpcObject.specialWorkspace?.name ?? ""

    // Nur Specials DIESES Monitors – die des anderen Bildschirms gehoeren
    // nicht in diese Leiste (gleiche Beschraenkung wie caelestia im
    // per-Monitor-Modus). Bewusst ueber den Namen statt Objekt-Identitaet:
    // robuster, falls Quickshell die Monitor-Wrapper neu baut.
    readonly property var specials: Hyprland.workspaces.values.filter(
        w => w.name.startsWith("special:") && w.monitor?.name === root.hyprMonitor?.name)

    // Gleicher Rhythmus wie die Punkte: 2px Luft, der Rest kommt aus den
    // Chip-Raendern (dort hitPadding-Prinzip wie in Workspace.qml)
    spacing: 2

    Repeater {
        model: root.specials

        Rectangle {
            id: chip

            required property var modelData   // HyprlandWorkspace

            // "special:music" -> "music". Der generische Special heisst intern
            // "special:special" (Hyprland haengt IMMER das Prefix an), also
            // bleibt der Key nie leer und bekommt den Star wie in caelestia.
            readonly property string key: chip.modelData.name.slice("special:".length)
            readonly property bool isActive: root.activeSpecial === chip.modelData.name
            readonly property bool hasWindows: chip.modelData.lastIpcObject.windows > 0

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: icon.implicitWidth + 16
            implicitHeight: 22
            radius: height / 2

            color: chip.isActive ? Colors.primary
                 : hover.hovered ? Colors.alpha(Colors.fgSurface, 0.08)
                 : "transparent"

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Text {
                id: icon

                anchors.centerIn: parent
                text: chip.iconName(chip.key)
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: chip.isActive ? Colors.fgBackground
                     : chip.hasWindows ? Colors.fgSurface
                     : Colors.fgSurfaceVariant
                // Belegte Specials heben sich vom leeren Rahmen ab – dieselbe
                // Stufung wie bei den Punkten, nur ohne Groessenunterschied.

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            function iconName(key: string): string {
                // Dieselben Defaults wie caelestia/utils/Icons.qml
                const map = {
                    "special": "star",
                    "communication": "forum",
                    "music": "music_cast",
                    "todo": "checklist",
                    "sysmon": "monitor_heart"
                };
                return map[key] ?? key.charAt(0).toUpperCase();
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${chip.key}")`)
            }
        }
    }
}
