pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs
import qs.modules.services.config
import "SpecialIcons.js" as SpecialIcons

// Kompakte Workspace-Anzeige fuer die eingeklappte Notch: senkrechte
// Stäbchen statt Punkten, der aktive ist hoeher. Im Notch-Layout parkt der
// grosse Workspace-Selektor im Hub und ist nur aufgeklappt zu sehen – das hier
// ist sein Platzhalter in der geschlossenen Notch.
//
// Dieselbe Gruppenlogik wie WorkspaceSelector.qml: jede Leiste zeigt die
// Workspaces ihres eigenen Monitors (je `perMonitor` am Stueck).
Row {
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

    // { wsId: hatFenster }. WorkspaceSelector haelt die Liste ueber
    // refreshWorkspaces() frisch, hier wird nur gelesen.
    readonly property var occupied: {
        const occ = {};
        for (const ws of Hyprland.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }

    spacing: 4
    height: root.activeHeight

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
                width: root.barWidth + root.spacing
                height: root.activeHeight + 8

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

    // Liegt ein Special-Workspace offen, steht sein Symbol hinter den
    // Staebchen (tertiaer, wie die Special-Pille der grossen Leiste)
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.activeSpecial !== ""
        text: SpecialIcons.iconFor(root.activeSpecial.slice("special:".length))
        color: Colors.tertiary
        font.family: "Material Symbols Outlined"
        font.pixelSize: 15
        font.variableAxes: ({ FILL: 1 })
        leftPadding: 2
    }
}
