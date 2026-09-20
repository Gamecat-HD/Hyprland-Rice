pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.config

import "root:/"

// Einstellungen der Shell – vierte Ansicht der Notch-Karte.
//
// Erreichbar ueber `>einstellungen` im Launcher. Geschaltet wird direkt in
// ~/.config/dynamic-island/shell.json (siehe services/config/Config.qml); die
// Leiste haengt an denselben Werten und reagiert sofort.
Item {
    id: panel

    // ---- Schnittstelle zur Notch ----
    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    readonly property alias maxOuterHeight: panel.outerHeight

    implicitWidth: 620
    implicitHeight: header.height + 1 + list.implicitHeight + 12

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: panel.inset
        rightMargin: panel.inset
    }
    y: panel.topOffset

    // Eine Zeile mit Schalter. Inline-Komponenten muessen auf der obersten
    // Ebene der Datei stehen, sonst legt Qt sie stillschweigend nicht an.
    component Toggle: Item {
        id: entry

        required property string title
        required property string description
        required property bool value
        signal toggled()

        width: parent?.width ?? 0
        implicitHeight: 46

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: 12
            color: entryHover.hovered ? Colors.alpha(Colors.fgSurface, 0.05) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        HoverHandler {
            id: entryHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: entry.toggled()
        }

        Column {
            anchors {
                left: parent.left
                right: knob.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            Text {
                width: parent.width
                text: entry.title
                color: Colors.fgBackground
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: entry.description
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: knob

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 40
            height: 22
            radius: height / 2
            color: entry.value ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.18)

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: entry.value ? parent.width - width - 3 : 3
                color: entry.value ? Colors.fgPrimary : Colors.fgSurfaceVariant

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ---- Kopfzeile ----
    Item {
        id: header

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 50

        Text {
            id: headerIcon

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: "tune"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 19
            color: Colors.primary
        }

        Text {
            anchors {
                left: headerIcon.right
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: "Einstellungen"
            color: Colors.fgSurface
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: "~/.config/dynamic-island/shell.json"
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
            font.pixelSize: 10
        }
    }

    Rectangle {
        id: separator

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
    }

    // ---- Schalter ----
    Column {
        id: list

        anchors {
            top: separator.bottom
            topMargin: 8
            left: parent.left
            right: parent.right
            leftMargin: 24
            rightMargin: 24
        }
        spacing: 2

        Text {
            width: parent.width
            bottomPadding: 4
            text: "LEISTE"
            color: Colors.fgSurfaceVariant
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 0.8
        }

        Toggle {
            title: "Workspace-Punkte"
            description: "Die Punktreihe links aussen"
            value: Config.bar.workspaces
            onToggled: {
                Config.bar.workspaces = !Config.bar.workspaces;
                Config.save();
            }
        }

        Toggle {
            title: "System-Pille"
            description: "Akkustand, Energieprofile und Auslastung neben den Workspaces"
            value: Config.bar.stats
            onToggled: {
                Config.bar.stats = !Config.bar.stats;
                Config.save();
            }
        }

        Toggle {
            title: "Systemtray"
            description: "Die Icons links neben der Uhr"
            value: Config.bar.tray
            onToggled: {
                Config.bar.tray = !Config.bar.tray;
                Config.save();
            }
        }

        Toggle {
            title: "Settings-Karte"
            description: "Der Kreis rechts der Uhr mit WLAN, Bluetooth und Co."
            value: Config.bar.settings
            onToggled: {
                Config.bar.settings = !Config.bar.settings;
                Config.save();
            }
        }

        Toggle {
            title: "Medien-Karte"
            description: "Titel, Cover und Steuerung rechts aussen"
            value: Config.bar.media
            onToggled: {
                Config.bar.media = !Config.bar.media;
                Config.save();
            }
        }

        Toggle {
            title: "Benachrichtigungen"
            description: "Die Glocke mit Zaehler; aus heisst auch: keine Popups mehr"
            value: Config.bar.notifications
            onToggled: {
                Config.bar.notifications = !Config.bar.notifications;
                Config.save();
            }
        }
    }
}
