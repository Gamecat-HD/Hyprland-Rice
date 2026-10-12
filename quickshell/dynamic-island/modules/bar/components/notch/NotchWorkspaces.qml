pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs
import qs.modules.services.config
import qs.modules.widgets
import "SpecialIcons.js" as SpecialIcons

// Workspace-Anzeige der Notch: senkrechte Staebchen, der aktive ist hoeher.
// Steht links neben der Uhr – eingeklappt wie aufgeklappt (Kopfzeile der
// Uebersicht und der Untermenues), ein Klick wechselt den Workspace.
//
// Special-Workspaces wie bei Caelestia: ist auf DIESEM Monitor einer offen,
// treten die Staebchen zurueck (gedimmt, kleiner, nicht klickbar) und eine
// kleine Pille legt sich darueber – mit den Symbolen aller vorhandenen
// Specials, der offene hervorgehoben, Klick toggelt. Sonst sind Specials
// nicht zu sehen.
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

    // Platz fuer das Breitere von beidem – die eingeklappte Notch misst sich
    // daran (compactSide), das Overlay darf nicht ueber die Uhr ragen
    implicitWidth: root.onSpecial ? Math.max(bars.implicitWidth, overlay.implicitWidth) : bars.implicitWidth
    implicitHeight: Math.max(root.activeHeight, overlay.implicitHeight)

    Morph on implicitWidth {}

    // ---- Staebchen ----
    Row {
        id: bars

        anchors.centerIn: parent
        spacing: 4
        height: root.activeHeight
        opacity: root.onSpecial ? 0.25 : 1
        scale: root.onSpecial ? 0.85 : 1
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

    // ---- Special-Overlay ----
    Rectangle {
        id: overlay

        anchors.centerIn: parent
        implicitWidth: specialRow.implicitWidth + 6
        implicitHeight: 22
        width: implicitWidth
        height: implicitHeight
        radius: height / 2
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Colors.alpha(Colors.tertiary, 0.35)
        opacity: root.onSpecial ? 1 : 0
        scale: root.onSpecial ? 1 : 0.6
        visible: opacity > 0

        Fade on opacity {}
        Morph on scale {}

        Row {
            id: specialRow

            anchors.centerIn: parent
            spacing: 1

            Repeater {
                model: root.specials

                Item {
                    id: special

                    required property var modelData   // HyprlandWorkspace
                    readonly property string key: special.modelData.name.slice("special:".length)
                    readonly property bool active: root.activeSpecial === special.modelData.name

                    width: special.active ? 26 : 20
                    height: 16

                    Behavior on width {
                        NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: special.active ? Colors.tertiary
                             : specialHover.hovered ? Colors.alpha(Colors.fgBackground, 0.14)
                             : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: SpecialIcons.iconFor(special.key)
                        color: special.active ? Colors.fgTertiary : Colors.fgSurfaceVariant
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 12
                        font.variableAxes: ({ FILL: special.active ? 1 : 0 })
                    }

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
