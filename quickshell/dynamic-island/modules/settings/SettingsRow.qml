pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.config

import "root:/"

// Eine Zeile im Einstellungs-Fenster, samt Gruppentitel darueber (wenn
// `section` gesetzt ist). Was fuer ein Bedienelement erscheint, entscheidet
// der Typ des Werts in der Datei: Wahrheitswerte bekommen einen Schalter,
// alles andere steht vorerst nur da.
Item {
    id: row

    // { id, section, key, value, title, desc }
    required property var entry
    // Nicht leer = Gruppentitel oberhalb dieser Zeile zeichnen
    property string section: ""

    readonly property bool isBool: typeof row.entry?.value === "boolean"
    readonly property real headerHeight: 24

    implicitHeight: (row.section !== "" ? row.headerHeight : 0) + 50

    Text {
        id: sectionLabel

        anchors {
            left: parent.left
            top: parent.top
        }
        height: row.section !== "" ? row.headerHeight : 0
        visible: row.section !== ""
        verticalAlignment: Text.AlignBottom

        text: (Config.sectionMeta[row.section] ?? row.section).toUpperCase()
        color: Colors.fgSurfaceVariant
        font.pixelSize: 9
        font.weight: Font.Medium
        font.letterSpacing: 0.8
        bottomPadding: 4
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            top: sectionLabel.bottom
            bottom: parent.bottom
        }
        radius: 12
        color: hover.hovered ? Colors.alpha(Colors.fgSurface, 0.05) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        HoverHandler {
            id: hover

            cursorShape: row.isBool ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: row.isBool
            onTapped: Config.set(row.entry.section, row.entry.key, !row.entry.value)
        }

        Column {
            anchors {
                left: parent.left
                leftMargin: 14
                right: control.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            Text {
                width: parent.width
                text: row.entry?.title ?? ""
                color: Colors.fgBackground
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.entry?.desc ?? ""
                color: Colors.fgSurfaceVariant
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        // Schalter fuer Wahrheitswerte
        Rectangle {
            id: control

            anchors {
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }
            width: 40
            height: 22
            radius: height / 2
            visible: row.isBool
            color: row.entry?.value ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.18)

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: row.entry?.value ? parent.width - width - 3 : 3
                color: row.entry?.value ? Colors.fgPrimary : Colors.fgSurfaceVariant

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }

        // Alles, was kein Wahrheitswert ist: vorerst nur anzeigen
        Text {
            anchors {
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }
            visible: !row.isBool
            text: String(row.entry?.value ?? "")
            color: Colors.fgSurfaceVariant
            font.pixelSize: 11
        }
    }
}
