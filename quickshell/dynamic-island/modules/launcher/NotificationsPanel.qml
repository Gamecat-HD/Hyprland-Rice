pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs
import qs.modules.services.config
import qs.modules.services.notifications
import qs.modules.bar.components.notifications

// Untermenue "Benachrichtigungen" der Notch: die gruppierte Liste der
// Benachrichtigungs-Pille, dazu Nicht-stoeren und Alle-loeschen.
// Aufruf: SUPER+N, `>benachrichtigungen`, Blaettern.
ViewPanel {
    id: root

    readonly property real maxListHeight: 360
    readonly property real toolbarHeight: 32
    // Hoehe aus dem Modell statt aus list.contentHeight (Bindungsschleife,
    // siehe NotificationPill.qml)
    readonly property real listBody: {
        let h = 0;
        for (const g of Notifications.groups) {
            h += g.entries.length > 1 ? 26 : 0;
            h += Notifications.actionButtons(g.entries[0]).length > 0 ? 86 : 54;
        }
        return h;
    }
    readonly property real listHeight: Math.max(70, Math.min(root.maxListHeight, root.listBody))

    title: "Benachrichtigungen"
    icon: "notifications"
    contentWidth: 380
    contentHeight: root.toolbarHeight + root.listHeight
    maxContentHeight: root.toolbarHeight + root.maxListHeight

    component ToolChip: Item {
        id: chip

        required property string icon
        required property string label
        property bool on: false
        signal clicked()

        implicitWidth: chipRow.implicitWidth + 18
        implicitHeight: 24

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? Colors.alpha(Colors.primary, 0.2)
                 : chipHover.hovered ? Colors.alpha(Colors.fgBackground, 0.12)
                 : Colors.alpha(Colors.fgBackground, 0.06)
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.on ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.on ? Colors.primary : Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: chip.clicked()
        }
    }

    // ---- Werkzeugleiste ----
    Item {
        width: parent.width
        height: root.toolbarHeight

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 2
            text: Notifications.count === 0 ? "Keine Nachrichten"
                : Notifications.count === 1 ? "1 Nachricht"
                : `${Notifications.count} Nachrichten`
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 11
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            ToolChip {
                icon: Notifications.dnd ? "notifications_off" : "notifications_active"
                label: "Nicht stören"
                on: Notifications.dnd
                onClicked: Notifications.toggleDnd()
            }

            ToolChip {
                visible: Notifications.count > 0
                icon: "clear_all"
                label: "Alle löschen"
                onClicked: Notifications.clear()
            }
        }
    }

    // ---- Liste ----
    ListView {
        id: list

        y: root.toolbarHeight
        width: parent.width
        height: root.listHeight
        clip: true
        spacing: 2
        model: ScriptModel {
            values: Notifications.groups
        }
        boundsBehavior: Flickable.StopAtBounds

        // Nur senkrecht scrollen – waagerecht gehoert der Notch. Das Rad
        // gleitet zum Ziel (scrollAnim) statt in 54-px-Spruengen; das
        // Touchpad liefert ohnehin feine Pixel-Schritte und geht direkt.
        property real targetY: 0

        NumberAnimation {
            id: scrollAnim

            target: list
            property: "contentY"
            duration: 180
            easing.type: Easing.OutCubic
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                const angle = event.angleDelta.y;
                const pixels = event.pixelDelta.y;
                if (angle === 0 && pixels === 0) {
                    event.accepted = false;
                    return;
                }
                event.accepted = true;
                const max = Math.max(0, list.contentHeight - list.height);

                if (pixels !== 0) {
                    scrollAnim.stop();
                    list.contentY = Math.max(0, Math.min(max, list.contentY - pixels));
                    list.targetY = list.contentY;
                    return;
                }

                // Laeuft gerade keine Animation, vom aktuellen Stand ausgehen
                if (!scrollAnim.running)
                    list.targetY = list.contentY;
                list.targetY = Math.max(0, Math.min(max, list.targetY - angle / 120 * 60));
                scrollAnim.to = list.targetY;
                scrollAnim.restart();
            }
        }

        delegate: NotificationGroup {
            width: ListView.view.width
        }

        Text {
            anchors.centerIn: parent
            visible: Notifications.count === 0
            text: Notifications.dnd ? "Nicht stören ist an" : "Nichts Neues"
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 12
        }
    }
}
