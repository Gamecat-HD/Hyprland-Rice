pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.wallpaper

import "root:/"
import "root:/modules/bar/components/notch"

// Wallpaper-Auswahl der Notch: eigenes Suchfeld und darunter das Karussell.
//
// Steckt wie LauncherPanel und DatePanel in der Karte der Notch und ist deren
// dritte Ansicht – welche gilt, sagt LauncherState.mode. Bewusst ein eigenes
// Panel statt eines Modus im Launcher: eigenes Suchfeld, eigene Breite.
Item {
    id: panel

    // ---- Schnittstelle zur Notch ----
    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false          // true, solange diese Ansicht offen ist

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    // Die Hoehe steht fest (siehe listHeight), Reserve und Ist sind dasselbe.
    // Die Notch fragt trotzdem danach, wie beim LauncherPanel.
    readonly property alias maxOuterHeight: panel.outerHeight

    // Feste Hoehe fuer den Bildbereich. Bewusst nicht aus dem Karussell
    // gelesen: das steckt in einem Loader und ist im geschlossenen Zustand gar
    // nicht da – die Notch braucht die Reserve aber schon vorher, sonst
    // schneidet das Fenster die Karte beim Aufgehen einen Frame lang ab.
    readonly property real listHeight: 145

    // Breiter als der Launcher, damit fuenf Bilder nebeneinander passen:
    // 988 nutzbare Breite / 191 je Kachel = 5 (PathView braucht eine ungerade
    // Zahl, sonst sitzt keines in der Mitte).
    implicitWidth: 1000
    // Kachelbreite; die Hoehe darunter haengt daran (16:9 + Beschriftung)
    readonly property real imageWidth: 175
    implicitHeight: searchRow.height + 1 + listWrapper.implicitHeight

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
            text: "wallpaper_slideshow"
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
            Keys.onReturnPressed: walls.item?.apply()
            Keys.onEnterPressed: walls.item?.apply()
            // Die Pfeile blaettern hier im Karussell statt den Textcursor zu
            // bewegen – im Suchfeld steht ohnehin nur ein Filterwort.
            Keys.onLeftPressed: walls.item?.moveBy(-1)
            Keys.onRightPressed: walls.item?.moveBy(1)
            Keys.onUpPressed: walls.item?.moveBy(-1)
            Keys.onDownPressed: walls.item?.moveBy(1)
            Keys.onTabPressed: walls.item?.moveBy(1)

            Text {
                anchors.fill: parent
                visible: search.text === ""
                text: `Wallpaper suchen…   ${Wallpapers.list.length} Bilder`
                color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                font: search.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Zufallsbild – das Gegenstueck zum Favoriten-Stern im Launcher
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
                    Wallpapers.random();
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
        implicitHeight: panel.listHeight

        // Als Loader, damit das Karussell nur existiert, solange die Ansicht
        // offen ist: beim Zerstoeren nimmt es seine Hintergrund-Vorschau
        // zurueck und gibt die Vorschaubilder frei.
        Loader {
            id: walls

            anchors.fill: parent
            anchors.margins: 6
            active: panel.active

            sourceComponent: WallpaperList {
                imageWidth: panel.imageWidth
                query: search.text
                onApplied: LauncherState.close()
            }
        }

        // Vignette nach aussen, damit die Reihe an den Kartenraendern auslaeuft
        // statt hart abzubrechen (dasselbe Mittel wie im Datumsstreifen).
        EdgeFade {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            implicitWidth: 56
            cornerRadius: panel.cardRadius - panel.inset
        }

        EdgeFade {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            implicitWidth: 56
            mirrored: true
            cornerRadius: panel.cardRadius - panel.inset
        }
    }
}
