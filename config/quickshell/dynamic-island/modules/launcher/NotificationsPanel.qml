pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs
import qs.modules.services.config
import qs.modules.services.notifications
import qs.modules.bar.components.notifications
import qs.modules.settings

// Untermenue "Benachrichtigungen" der Notch: die gruppierte Liste der
// Benachrichtigungs-Pille, dazu Nicht-stoeren und Alle-loeschen.
// Aufruf: SUPER+N, `>benachrichtigungen`, Blaettern.
ViewPanel {
    id: root

    readonly property real maxListHeight: 440
    readonly property real toolbarHeight: 32
    // Die Liste waechst mit ihrem echten Inhalt (auch aufgeklappte Gruppen)
    // bis maxListHeight, danach scrollt sie. Hier geht das mit
    // list.contentHeight, weil die Hoehe der Liste ihre Inhaltshoehe nicht
    // beeinflusst (die Pille rechnet anders, siehe NotificationPill.qml).
    // Leer keine Liste – die Werkzeugleiste sagt dann "Keine Nachrichten".
    readonly property real listHeight: Notifications.count === 0 ? 0
        : Math.min(root.maxListHeight, Math.max(54, list.contentHeight))

    title: I18n.tr("Benachrichtigungen")
    icon: "notifications"
    contentWidth: 380
    contentHeight: root.toolbarHeight + root.listHeight
    maxContentHeight: root.toolbarHeight + root.maxListHeight

    // ---- Werkzeugleiste ----
    // Links Nicht stoeren als Schalter, rechts Alle loeschen bzw. der Leerstand
    Item {
        width: parent.width
        height: root.toolbarHeight

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 2
            spacing: 10

            SettingsSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Nicht stören")
                color: Colors.fgSurface
                font.family: Config.font
                font.pixelSize: 12
            }
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 2
                verticalCenter: parent.verticalCenter
            }
            visible: Notifications.count === 0
            text: I18n.tr("Keine Nachrichten")
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 11
        }

        Rectangle {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: Notifications.count > 0
            width: clearText.implicitWidth + 24
            height: 26
            radius: 8
            color: Colors.alpha(Colors.fgSurface, clearHover.hovered ? 0.14 : 0.08)

            Text {
                id: clearText

                anchors.centerIn: parent
                text: I18n.tr("Alle löschen")
                color: Colors.fgSurface
                font.family: Config.font
                font.pixelSize: 11
            }

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Notifications.clear()
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
        // Alle Zeilen erzeugen, damit contentHeight die echte Hoehe ist und
        // nicht aus den sichtbaren geschaetzt wird
        cacheBuffer: 4000
        model: ScriptModel {
            values: Notifications.groups
        }
        // Kein Highlight-Nachfuehren (siehe LauncherPanel.qml)
        highlightFollowsCurrentItem: false
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

    }
}
