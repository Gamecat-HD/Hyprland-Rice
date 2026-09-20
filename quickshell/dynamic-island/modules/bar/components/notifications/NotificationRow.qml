pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.modules.services.notifications

import "root:/"

// Eine Benachrichtigung: Bild/Icon, Titel, Text, Alter, Schliessen-Knopf.
//
// Dieselbe Zeile in zwei Groessen – `compact` ist die Fassung fuer die
// aufgeklappte Pille (eine Zeile hoch, ohne Schliessen-Knopf), sonst die
// Fassung fuer die Liste.
Item {
    id: row

    // { notif, time } aus dem Dienst; darf null sein (leere Liste)
    property var entry: null
    property bool compact: false

    readonly property var notif: row.entry?.notif ?? null
    readonly property bool critical: row.notif?.urgency === NotificationUrgency.Critical
    readonly property real iconSize: row.compact ? 20 : 26

    implicitHeight: row.compact ? 30 : 52

    // Dezente Flaeche unter der Zeile, damit man sieht, worauf man zeigt
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        radius: 10
        color: !row.compact && rowHover.hovered ? Colors.alpha(Colors.fgSurface, 0.05) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    // Klick loest die erste Aktion aus, wenn die Nachricht eine mitbringt
    // (z.B. "Oeffnen"). Ohne Aktion passiert nichts.
    TapHandler {
        enabled: (row.notif?.actions?.length ?? 0) > 0
        onTapped: row.notif.actions[0].invoke()
    }

    HoverHandler {
        id: rowHover

        cursorShape: (row.notif?.actions?.length ?? 0) > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // ---- Bild / Icon ----
    // Drei Stufen: mitgeschicktes Bild, sonst App-Icon aus dem Icon-Theme,
    // sonst ein Material-Symbol (wie caelestia es macht).
    Item {
        id: iconBox

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: row.iconSize
        height: row.iconSize

        Image {
            id: icon

            anchors.fill: parent
            source: {
                const n = row.notif;
                if (!n)
                    return "";
                if (n.image !== "")
                    return Qt.resolvedUrl(n.image);
                if (n.appIcon !== "")
                    return Quickshell.iconPath(n.appIcon, true);
                return "";
            }
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: row.iconSize * 2
            sourceSize.height: row.iconSize * 2
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: icon.status !== Image.Ready

            text: row.critical ? "release_alert" : "chat"
            color: row.critical ? Colors.error : Colors.fgSurfaceVariant
            font.family: "Material Symbols Outlined"
            font.pixelSize: row.iconSize - 4
        }
    }

    // ---- Text ----
    Column {
        anchors {
            left: iconBox.right
            leftMargin: 10
            right: meta.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: row.compact ? 0 : 2

        Text {
            width: parent.width
            text: row.notif?.summary ?? ""
            color: row.critical ? Colors.error : Colors.fgBackground
            font.pixelSize: row.compact ? 11 : 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            // Die Spec meint ein HTML-Subset, nicht Markdown
            textFormat: Text.StyledText
            text: row.notif?.body ?? ""
            color: Colors.fgSurfaceVariant
            font.pixelSize: row.compact ? 10 : 11
            elide: Text.ElideRight
            maximumLineCount: row.compact ? 1 : 2
            wrapMode: row.compact ? Text.NoWrap : Text.Wrap
        }
    }

    // ---- Alter + Schliessen ----
    Row {
        id: meta

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter

            // `tick` haengt nur mit drin, damit sich die Angabe auffrischt
            text: Notifications.tick, Notifications.formatAge(row.entry?.time ?? null)
            color: Colors.alpha(Colors.fgSurfaceVariant, 0.8)
            font.pixelSize: 10
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.compact

            width: 22
            height: 22
            radius: height / 2
            color: closeArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.14) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Text {
                anchors.centerIn: parent
                text: "close"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.dismiss(row.entry)
            }
        }
    }
}
