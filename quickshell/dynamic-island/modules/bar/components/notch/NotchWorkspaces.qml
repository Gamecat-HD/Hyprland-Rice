pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs
import qs.modules.services.config
import qs.modules.widgets

// Workspace-Anzeige der Notch: senkrechte Staebchen, der aktive ist hoeher.
// Steht links neben der Uhr – eingeklappt wie aufgeklappt (Kopfzeile der
// Uebersicht und der Untermenues), ein Klick wechselt den Workspace.
//
// Special-Workspaces: ist auf DIESEM Monitor einer offen, treten die
// Workspace-Staebchen fast ganz zurueck und an ihrer Stelle stehen die
// vorhandenen Specials – ebenfalls als Staebchen, jeder in seiner eigenen
// Farbe (specialColor), der offene hoch wie der aktive Workspace. Klick
// toggelt. Ohne offenen Special sind Specials nicht zu sehen.
//
// Dieselbe Gruppenlogik wie WorkspaceSelector.qml: jede Leiste zeigt die
// Workspaces ihres eigenen Monitors (je `perMonitor` am Stueck). Dessen
// Connections halten die Hyprland-Listen frisch (refreshWorkspaces/-Monitors).
Item {
    id: root

    // Dieselbe Einstellung wie die grosse Punktreihe (bar.workspaceCount)
    property int perMonitor: Math.max(1, Math.min(10, Config.bar.workspaceCount))
    property color color: Colors.primary
    property real barWidth: 5
    property real activeHeight: 15
    property real idleHeight: 9

    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(root.QsWindow.window?.screen ?? null)
    readonly property int activeId: root.hyprMonitor?.activeWorkspace?.id ?? 1
    readonly property int groupOffset: Math.floor((root.activeId - 1) / root.perMonitor) * root.perMonitor
    // Offener Special-Workspace auf DIESEM Monitor ("" = keiner)
    readonly property string activeSpecial: root.hyprMonitor?.lastIpcObject.specialWorkspace?.name ?? ""
    readonly property bool onSpecial: root.activeSpecial !== ""

    // { wsId: hatFenster }
    readonly property var occupied: {
        const occ = {};
        for (const ws of Hyprland.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    // Alle vorhandenen Specials (fuer das Overlay)
    readonly property var specials: Hyprland.workspaces.values
        .filter(w => w.name.startsWith("special:"))
        .sort((a, b) => a.name.localeCompare(b.name))

    // Das Overlay ist genau so breit wie die Staebchen-Reihe – die Anzeige
    // behaelt ihre Groesse, egal ob ein Special offen ist
    implicitWidth: bars.implicitWidth
    implicitHeight: root.activeHeight

    // Feste, gut unterscheidbare Farbe je Special: eigener Farbton, Helligkeit
    // und Saettigung am Theme ausgerichtet (die Theme-Rollen selbst liegen in
    // vielen Schemata zu nah beieinander). Unbekannte Specials reihum.
    function specialColor(key: string, index: int): color {
        const hues = {
            "music": 0.38,          // gruen
            "communication": 0.58,  // blau
            "sysmon": 0.07,         // orange
            "special": 0.78,        // violett
            "todo": 0.15            // gelb
        };
        const cycle = [0.38, 0.58, 0.07, 0.78, 0.15, 0.95];
        const hue = hues[key] ?? cycle[index % cycle.length];
        const light = Math.max(0.62, Math.min(0.75, Colors.primary.hslLightness));
        return Qt.hsla(hue, 0.7, light, 1);
    }

    // ---- Staebchen ----
    Row {
        id: bars

        anchors.centerIn: parent
        spacing: 4
        height: root.activeHeight
        opacity: root.onSpecial ? 0.12 : 1
        scale: root.onSpecial ? 0.9 : 1
        // Im Special-Modus gehoeren die Klicks dem Overlay
        enabled: !root.onSpecial

        Fade on opacity {}
        Morph on scale {}

        Repeater {
            model: root.perMonitor

            Item {
                id: slot

                required property int index
                readonly property int ws: root.groupOffset + slot.index + 1
                readonly property bool active: slot.ws === root.activeId

                width: root.barWidth
                height: root.activeHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.barWidth
                    height: slot.active ? root.activeHeight : root.idleHeight
                    radius: width / 2
                    color: root.color
                    opacity: slot.active ? 1
                           : root.occupied[slot.ws] ? 0.6
                           : slotHover.hovered ? 0.5
                           : 0.3

                    Behavior on height {
                        NumberAnimation { duration: Appearance.morphDuration * 0.6; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                    }
                }

                // Trefferflaeche groesser als das 5-px-Staebchen
                Item {
                    anchors.centerIn: parent
                    width: root.barWidth + bars.spacing
                    height: root.activeHeight + 10

                    HoverHandler {
                        id: slotHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Hyprland.dispatch(Hyprland.usingLua
                            ? `hl.dsp.focus({ workspace = ${slot.ws} })`
                            : `workspace ${slot.ws}`)
                    }
                }
            }
        }
    }

    // ---- Specials als farbige Staebchen ----
    // Liegen mittig ueber der Workspace-Reihe, gleiche Masse und Bewegung.
    Row {
        id: specialBars

        anchors.centerIn: parent
        spacing: bars.spacing
        height: root.activeHeight
        opacity: root.onSpecial ? 1 : 0
        scale: root.onSpecial ? 1 : 0.6
        visible: opacity > 0

        Fade on opacity {}
        Morph on scale {}

        Repeater {
            model: root.specials

            Item {
                id: special

                required property var modelData   // HyprlandWorkspace
                required property int index
                readonly property string key: special.modelData.name.slice("special:".length)
                readonly property bool active: root.activeSpecial === special.modelData.name

                width: root.barWidth
                height: root.activeHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: root.barWidth
                    height: special.active ? root.activeHeight : root.idleHeight
                    radius: width / 2
                    color: root.specialColor(special.key, special.index)
                    opacity: special.active ? 1 : specialHover.hovered ? 0.8 : 0.5

                    Behavior on height {
                        NumberAnimation { duration: Appearance.morphDuration * 0.6; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: root.barWidth + specialBars.spacing
                    height: root.activeHeight + 10

                    HoverHandler {
                        id: specialHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Hyprland.dispatch(Hyprland.usingLua
                            ? `hl.dsp.workspace.toggle_special("${special.key}")`
                            : `togglespecialworkspace ${special.key}`)
                    }
                }
            }
        }
    }
}
