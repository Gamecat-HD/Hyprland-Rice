pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services.theme
import qs.modules.services.wallpaper

import qs
import qs.modules.bar.components.notch
import qs.modules.services.config

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
    implicitHeight: searchRow.height + 1 + listWrapper.implicitHeight + 1 + styleRow.height

    // Stil-Reihe unten: "auto" und die Material-Varianten. Sie gilt fuer das
    // markierte Bild, nicht fuer alle – die CLI merkt sich die Wahl je Bild.
    readonly property string targetPath: walls.item?.currentPath ?? ""
    readonly property var styles: [{ name: "auto", icon: "auto_awesome" }].concat(Themes.variants)

    // Feste Wahl des markierten Bilds, sonst "auto"
    readonly property string pinnedStyle: Wallpapers.variantFor(panel.targetPath) || "auto"

    // Was "auto" fuer das markierte Bild ergibt: aus der Vorschau, beim
    // gerade gesetzten Bild ohne Vorschau aus scheme.json
    readonly property string resolvedStyle: Wallpapers.previewPath === panel.targetPath && Wallpapers.previewVariant !== ""
        ? Wallpapers.previewVariant
        : panel.targetPath === Wallpapers.actualCurrent ? Themes.currentVariant : ""

    function pickStyle(name: string): void {
        Wallpapers.setVariant(panel.targetPath, name);
    }

    function cycleStyle(delta: int): void {
        const names = panel.styles.map(v => v.name);
        const at = Math.max(0, names.indexOf(panel.pinnedStyle));
        panel.pickStyle(names[(at + delta + names.length) % names.length]);
    }

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: panel.inset
        rightMargin: panel.inset
    }
    y: panel.topOffset

    // Per LazyPanel entsteht die Ansicht bereits aktiv – dann gibt es kein
    // Wechsel-Signal, die Startarbeit (Fokus, Suchfeld) wird nachgeholt
    Component.onCompleted: if (panel.active) Qt.callLater(panel.activeChanged)

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
            font.family: Config.font

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
            // Mit Strg waehlen sie den Stil des markierten Bilds.
            Keys.onLeftPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    panel.cycleStyle(-1);
                else
                    walls.item?.moveBy(-1);
            }
            Keys.onRightPressed: event => {
                if (event.modifiers & Qt.ControlModifier)
                    panel.cycleStyle(1);
                else
                    walls.item?.moveBy(1);
            }
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

    Rectangle {
        id: separator2

        anchors {
            top: listWrapper.bottom
            left: parent.left
            right: parent.right
        }
        height: 1
        color: Colors.alpha(Colors.outline, 0.35)
    }

    // ---- Stil ----
    // Wie aus dem markierten Bild die Palette wird. Ein Klick legt den Stil
    // fuer dieses Bild fest (beim aktuellen faerbt es gleich um, sonst zeigt
    // die Vorschau ihn); "auto" rechnet ihn aus der Farbigkeit aus, der
    // ausgerechnete Stil ist dann duenn umrandet. Strg+Pfeile im Suchfeld
    // schalten durch. Wirkt nur beim dynamischen Schema – sonst bleibt die
    // Reihe sichtbar, aber zurueckgenommen (wie in der Theme-Auswahl).
    Item {
        id: styleRow

        anchors {
            top: separator2.bottom
            left: parent.left
            right: parent.right
        }
        height: 46

        opacity: Themes.currentName === "dynamic" ? 1 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        Text {
            id: styleIcon

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

        // Die Chips behalten ihre natuerliche Breite, der Abstand dazwischen
        // verteilt den Rest (wie in ThemePanel.qml)
        Row {
            id: chips

            anchors {
                left: styleIcon.right
                leftMargin: 14
                right: parent.right
                rightMargin: 14
                verticalCenter: parent.verticalCenter
            }

            property var widths: ({})
            readonly property real naturalWidth: {
                let sum = 0;
                for (const key in chips.widths)
                    sum += chips.widths[key];
                return sum;
            }

            function report(index: int, width: real): void {
                const next = Object.assign({}, chips.widths);
                next[index] = width;
                chips.widths = next;
            }

            spacing: Math.max(4, (chips.width - chips.naturalWidth) / (panel.styles.length - 1))

            Repeater {
                model: panel.styles

                delegate: Rectangle {
                    id: chip

                    required property int index
                    required property var modelData

                    readonly property bool selected: panel.pinnedStyle === chip.modelData.name
                    // Bei "auto": der Stil, den das Bild tatsaechlich bekommt
                    readonly property bool resolved: panel.pinnedStyle === "auto"
                        && panel.resolvedStyle === chip.modelData.name

                    implicitWidth: chipContent.implicitWidth + 20
                    implicitHeight: 28

                    onImplicitWidthChanged: chips.report(chip.index, chip.implicitWidth)
                    Component.onCompleted: chips.report(chip.index, chip.implicitWidth)

                    radius: height / 2
                    color: chip.selected ? Colors.primary
                        : chipArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08)
                        : Colors.alpha(Colors.fgSurface, 0.04)
                    border.width: chip.resolved ? 1 : 0
                    border.color: Colors.alpha(Colors.primary, 0.6)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    Row {
                        id: chipContent

                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.icon
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 14
                            color: chip.selected ? Colors.fgPrimary
                                : chip.resolved ? Colors.primary
                                : Colors.fgSurfaceVariant
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.name
                            font.family: Config.font
                            font.pixelSize: 11
                            color: chip.selected ? Colors.fgPrimary
                                : chip.resolved ? Colors.primary
                                : Colors.fgSurface
                        }
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.pickStyle(chip.modelData.name)
                    }
                }
            }
        }
    }
}
