pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.theme

import "root:/"
import "root:/modules/bar/components/notch"

// Theme-Auswahl der Notch: eigenes Suchfeld, darunter das Farb-Karussell und
// ganz unten die Material-Varianten.
//
// Aufbau wie WallpaperPanel.qml – dritte Ansicht derselben Karte, gesteuert
// ueber LauncherState.mode. Anders als die Wallpaper-Auswahl hat sie keinen
// eigenen Knopf in der Leiste: erreichbar ist sie ueber `>theme` im Launcher.
Item {
    id: panel

    // ---- Schnittstelle zur Notch ----
    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    // Die Hoehe steht fest, Reserve und Ist sind dasselbe (siehe WallpaperPanel)
    readonly property alias maxOuterHeight: panel.outerHeight

    // Feste Hoehe des Kachelbereichs – das Karussell steckt in einem Loader
    // und ist im geschlossenen Zustand gar nicht da.
    readonly property real listHeight: 117

    implicitWidth: 900
    implicitHeight: searchRow.height + 1 + listWrapper.height + variantRow.height

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: panel.inset
        rightMargin: panel.inset
    }
    y: panel.topOffset

    onActiveChanged: {
        if (active) {
            search.text = "";
            search.forceActiveFocus();
        }
    }

    // ---- Suchzeile ----
    Item {
        id: searchRow

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 50

        Text {
            id: searchIcon

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: "palette"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 19
            color: Colors.primary
        }

        TextInput {
            id: search

            anchors {
                left: searchIcon.right
                leftMargin: 12
                right: shuffleButton.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            color: Colors.fgSurface
            font.pixelSize: 14
            selectionColor: Colors.alpha(Colors.primary, 0.35)
            selectedTextColor: Colors.fgSurface
            clip: true

            Keys.onEscapePressed: LauncherState.close()
            Keys.onReturnPressed: themes.item?.apply()
            Keys.onEnterPressed: themes.item?.apply()
            // Die Pfeile blaettern im Karussell statt den Textcursor zu bewegen
            Keys.onLeftPressed: themes.item?.moveBy(-1)
            Keys.onRightPressed: themes.item?.moveBy(1)
            Keys.onUpPressed: themes.item?.moveBy(-1)
            Keys.onDownPressed: themes.item?.moveBy(1)
            Keys.onTabPressed: themes.item?.moveBy(1)

            Text {
                anchors.fill: parent
                visible: search.text === ""
                text: `Theme suchen…   ${Themes.entries.length} Schemata`
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                font: search.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Zufallsschema – wie der Shuffle-Knopf in der Wallpaper-Auswahl
        Rectangle {
            id: shuffleButton

            anchors {
                right: parent.right
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            width: 32
            height: 32
            radius: height / 2
            color: shuffleArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 90 }
            }

            MouseArea {
                id: shuffleArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Themes.random();
                    LauncherState.close();
                }
            }

            Text {
                anchors.centerIn: parent
                text: "shuffle"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
                color: shuffleArea.containsMouse ? Colors.primary : Colors.fgSurfaceVariant
            }
        }
    }

    Rectangle {
        id: separator

        anchors {
            top: searchRow.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
    }

    // ---- Karussell ----
    Item {
        id: listWrapper

        anchors {
            top: separator.bottom
            left: parent.left
            right: parent.right
        }
        height: panel.listHeight

        Loader {
            id: themes

            anchors.fill: parent
            anchors.margins: 6
            active: panel.active

            sourceComponent: ThemeList {
                query: search.text
                onApplied: LauncherState.close()
            }
        }

        // Vignette nach aussen, damit die Reihe an den Kartenraendern auslaeuft
        EdgeFade {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            implicitWidth: 56
        }

        EdgeFade {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            implicitWidth: 56
            mirrored: true
        }
    }

    // ---- Material-Varianten ----
    // Sie bestimmen, wie aus dem Wallpaper eine Palette wird – wirken also nur
    // auf das dynamische Schema. Bei allen anderen bleibt die Reihe sichtbar,
    // aber zurueckgenommen.
    Item {
        id: variantRow

        anchors {
            top: listWrapper.bottom
            left: parent.left
            right: parent.right
        }
        height: 46

        readonly property bool relevant: Themes.currentName === "dynamic"

        opacity: variantRow.relevant ? 1 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        Text {
            id: variantLabel

            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            text: variantRow.relevant ? "VARIANTE" : "VARIANTE · NUR DYNAMIC"
            color: Colors.fgSurfaceVariant
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 0.8
        }

        Row {
            anchors {
                left: variantLabel.right
                leftMargin: 14
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 5

            Repeater {
                model: Themes.variants

                Rectangle {
                    id: chip

                    required property string modelData

                    readonly property bool isCurrent: chip.modelData === Themes.currentVariant

                    implicitWidth: chipText.implicitWidth + 18
                    implicitHeight: 24
                    radius: height / 2
                    color: chip.isCurrent ? Colors.alpha(Colors.primary, 0.18)
                         : chipArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08)
                         : "transparent"
                    border.width: chip.isCurrent ? 1 : 0
                    border.color: Colors.alpha(Colors.primary, 0.5)

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }

                    Text {
                        id: chipText

                        anchors.centerIn: parent
                        text: chip.modelData
                        color: chip.isCurrent ? Colors.primary : Colors.fgSurfaceVariant
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Themes.setVariant(chip.modelData)
                    }
                }
            }
        }
    }
}
