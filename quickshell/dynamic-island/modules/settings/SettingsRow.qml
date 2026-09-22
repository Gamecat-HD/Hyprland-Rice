pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.config

import qs

// Eine Zeile im Einstellungs-Fenster, samt Gruppentitel darueber (wenn
// `section` gesetzt ist). Was fuer ein Bedienelement erscheint, entscheidet
// der Typ des Werts in der Datei: Wahrheitswerte bekommen einen Schalter,
// Eintraege mit `options` (siehe Config.meta) eine aufklappbare Auswahl,
// alles andere steht vorerst nur da.
Item {
    id: row

    // { id, section, key, value, title, desc }
    required property var entry
    // Nicht leer = Gruppentitel oberhalb dieser Zeile zeichnen
    property string section: ""

    readonly property bool isBool: typeof row.entry?.value === "boolean"
    readonly property bool isChoice: !row.isBool && Array.isArray(row.entry?.options)
    // Schrift-Auswahl: jede Option in ihrer eigenen Schrift zeigen und nur
    // anbieten, was auch installiert ist
    readonly property bool isFont: row.isChoice && String(row.entry?.key ?? "").toLowerCase().includes("font")
    readonly property var choices: {
        if (!row.isChoice)
            return [];
        const installed = row.isFont ? Qt.fontFamilies() : null;
        const list = row.entry.options.filter(o => !installed || installed.includes(o));
        // Von Hand eingetragener Wert, der nicht in der Liste steht: trotzdem zeigen
        const current = String(row.entry.value ?? "");
        if (current !== "" && !list.includes(current))
            list.unshift(current);
        return list;
    }
    property bool expanded: false
    readonly property real headerHeight: 24

    implicitHeight: (row.section !== "" ? row.headerHeight : 0) + 50
                    + (row.expanded ? choiceFlow.implicitHeight + 12 : 0)

    Behavior on implicitHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Text {
        id: sectionLabel
        font.family: Config.font

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

            cursorShape: row.isBool || row.isChoice ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        clip: true

        // Die eigentliche Zeile; bei einer Auswahl haengt die Liste darunter
        Item {
            id: line

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 50

            TapHandler {
                enabled: row.isBool || row.isChoice
                onTapped: {
                    if (row.isBool)
                        Config.set(row.entry.section, row.entry.key, !row.entry.value);
                    else
                        row.expanded = !row.expanded;
                }
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
                    font.family: Config.font
                    width: parent.width
                    text: row.entry?.title ?? ""
                    color: Colors.fgBackground
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    font.family: Config.font
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

            // Aktueller Wert (bei einer Auswahl mit Pfeil zum Aufklappen)
            Row {
                anchors {
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                visible: !row.isBool
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.entry?.value ?? "")
                    color: Colors.fgSurfaceVariant
                    font.family: row.isFont ? String(row.entry?.value ?? "") : Config.font
                    font.pixelSize: 11
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isChoice
                    text: "expand_more"
                    rotation: row.expanded ? 180 : 0
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16

                    Behavior on rotation {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // Die Optionen einer Auswahl als Chips
        Flow {
            id: choiceFlow

            anchors {
                left: parent.left
                right: parent.right
                top: line.bottom
                leftMargin: 14
                rightMargin: 14
            }
            visible: row.isChoice
            opacity: row.expanded ? 1 : 0
            spacing: 6

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Repeater {
                model: row.choices

                Rectangle {
                    id: chip

                    required property string modelData
                    readonly property bool selected: chip.modelData === String(row.entry?.value ?? "")

                    width: chipLabel.implicitWidth + 24
                    height: 28
                    radius: height / 2
                    color: chip.selected ? Colors.primary
                         : chipHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
                         : Colors.alpha(Colors.fgSurface, 0.06)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Text {
                        id: chipLabel

                        anchors.centerIn: parent
                        text: chip.modelData
                        color: chip.selected ? Colors.fgPrimary : Colors.fgSurface
                        font.family: row.isFont ? chip.modelData : Config.font
                        font.pixelSize: 11
                    }

                    HoverHandler {
                        id: chipHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Config.set(row.entry.section, row.entry.key, chip.modelData)
                    }
                }
            }
        }
    }
}
