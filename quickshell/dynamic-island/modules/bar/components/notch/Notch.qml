pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.modules.services.system

import "root:/"
import "root:/modules/launcher"
// Fuer den Ring um die Uhr – derselbe, der an der Settings-Pille haengt
import "root:/modules/bar/components/settings"

// Notch mit Uhr: Karte, Hover-Logik und Auf-/Zuklapp-Animation. Den Inhalt des
// ausgeklappten Teils bringt DatePanel komplett selbst mit (Datum, Gesten,
// eigene Einrückung) – hier steht nur, wie groß die Karte dafür wird.
// Es bleibt ein einziges Rechteck, deshalb gibt es keine Naht. Damit die Karte
// unter die Leiste ragen kann, ist das Bar-Fenster höher (siehe Bar.qml).
Item {
    id: notch

    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor
    required property real cardRadius

    readonly property bool containsMouse: hoverSensor.hovered
    readonly property alias clock: clock

    // Datums-Ansicht (per Hover) und Launcher (per Zug nach unten) teilen sich
    // dieselbe Karte – der Launcher hat Vorrang.
    property bool expanded: false
    readonly property var hostScreen: notch.QsWindow.window?.screen ?? null
    readonly property bool launcherOpen: LauncherState.open && LauncherState.screen === hostScreen
    // Die Karte hat im Launcher-Modus drei Ansichten (siehe LauncherState.mode)
    readonly property bool wallpaperOpen: launcherOpen && LauncherState.mode === "wallpaper"
    readonly property bool themeOpen: launcherOpen && LauncherState.mode === "theme"
    readonly property bool appsOpen: launcherOpen && !wallpaperOpen && !themeOpen
    readonly property bool open: expanded || launcherOpen

    // Die Uhr rutscht beim Aufklappen etwas nach unten
    readonly property real clockDropMax: 7
    readonly property real clockDrop: open ? clockDropMax : 0
    // Im Launcher-Modus ist die Uhr ausgeblendet, das Panel beginnt oben
    readonly property real launcherTop: 10

    // Maße: eingeklappt exakt wie vorher, ausgeklappt wächst die Karte nach
    // unten und mittig etwas in die Breite.
    readonly property real collapsedHeight: parent.height - verticalMargin
    readonly property real collapsedWidth: clock.implicitWidth + 50
    readonly property real launcherWidth: wallpaperOpen ? wallpapers.outerWidth
                                        : themeOpen ? themes.outerWidth
                                        : launcher.outerWidth
    readonly property real launcherHeight: wallpaperOpen ? wallpapers.outerHeight
                                         : themeOpen ? themes.outerHeight
                                         : launcher.outerHeight

    readonly property real expandedWidth: launcherOpen ? Math.max(collapsedWidth, launcherWidth)
                                                       : Math.max(collapsedWidth, panel.outerWidth)
    readonly property real expandedHeight: launcherOpen ? launcherTop + launcherHeight
                                                        : collapsedHeight + clockDropMax + panel.outerHeight
    // Reserve, die sich das Bar-Fenster nach unten nehmen muss (größter Fall)
    readonly property real maxDrop: Math.max(clockDropMax + panel.outerHeight,
                                             launcherTop + launcher.maxOuterHeight,
                                             launcherTop + wallpapers.maxOuterHeight,
                                             launcherTop + themes.maxOuterHeight) + verticalMargin

    anchors.horizontalCenter: parent.horizontalCenter
    y: verticalMargin / 2
    width: open ? expandedWidth : collapsedWidth
    height: open ? expandedHeight : collapsedHeight

    // Aufklappen erst nach kurzem Verweilen, Zuklappen mit Nachlauf
    onContainsMouseChanged: {
        if (containsMouse) {
            closeTimer.stop();
            if (!expanded && !launcherOpen)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    // Beim Zuklappen wieder auf heute zurückspringen
    onExpandedChanged: if (!expanded) panel.dayOffset = 0
    // Der Launcher übernimmt die Karte: Datums-Ansicht dabei einklappen
    onLauncherOpenChanged: if (launcherOpen) expanded = false

    Timer {
        id: openTimer
        interval: 200
        onTriggered: notch.expanded = true
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: {
            if (panel.dragging)   // beim Ziehen darf die Maus rausrutschen
                closeTimer.restart();
            else
                notch.expanded = false;
        }
    }

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: pill
        anchors.fill: parent

        // Pille, solange sie flach ist; ab ~36px Höhe wird daraus eine Karte.
        // Als Formel statt Zustand, damit sie während der Animation mitwandert.
        radius: Math.min(height / 2, notch.cardRadius)
        border.width: notch.borderWidth
        border.color: notch.borderColor   // vom Aufrufer, z.B. Colors.outlineVariant
        color: Colors.background
        clip: true

        // Nach unten ziehen öffnet den Launcher. Solange diese Geste läuft,
        // ist das Ziehen im Datumsstreifen stillgelegt.
        DragHandler {
            id: launcherDrag

            target: null
            xAxis.enabled: false
            enabled: !LauncherState.open

            readonly property real threshold: 55
            property bool triggered: false

            onActiveChanged: if (active) triggered = false
            onTranslationChanged: {
                if (!launcherDrag.active || launcherDrag.triggered)
                    return;
                if (launcherDrag.activeTranslation.y > launcherDrag.threshold) {
                    launcherDrag.triggered = true;
                    LauncherState.show(notch.QsWindow.window.screen);
                }
            }
        }

        Clock {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            // im eingeklappten Band zentriert, beim Aufklappen etwas tiefer;
            // im Launcher-Modus macht sie ganz Platz
            y: (notch.collapsedHeight - height) / 2 + notch.clockDrop
            opacity: notch.launcherOpen ? 0 : 1
            visible: opacity > 0

            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }

        // Akku-Ring am Aussenrand der Pille, wenn ein Systemakku da ist.
        // Derselbe Ring wie an der Settings-Pille: die Stadion-Form legt sich
        // um die flache Pille, die Luecke sitzt unten in der Mitte.
        //
        // Nur eingeklappt – aufgeklappt waere es ein Rahmen um eine grosse
        // Karte, und die Uhr ist dann ohnehin nicht mehr der Inhalt.
        //
        // `value` und `muted` ueberschreiben die Audio-Vorgaben der Datei
        // (so macht es Settings.qml schon fuer die Helligkeit).
        Audioslider {
            id: batteryRing

            // Voll = Primaerfarbe, leer = Fehlerfarbe. Der Umschlag ist bei
            // 20 % erreicht, bei 60 % haelt sich beides die Waage; die 0.8
            // unten ist die einzige Stellschraube dafuer.
            // Der Exponent haelt die Mitte ausgewogen: linear waere bei 50 %
            // schon fast alles rot.
            readonly property real drain: Math.pow(Math.max(0, Math.min(1,
                (1 - Power.percent / 100) / 0.8)), 1.5)

            arcWidth: 2
            arcGap: 3
            value: Power.percent / 100
            muted: false
            activeColor: Colors.mix(Colors.primary, Colors.error, batteryRing.drain)

            opacity: notch.open || !Power.hasSystemBattery ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        // Power-Knopf: sitzt auf der Uhr-Zeile, rechts in der Karte.
        // Eingeklappt ist die Pille nur `clock.implicitWidth + 50` breit – dort
        // waere kein Platz, deshalb haengt er an derselben Bedingung wie das
        // DatePanel und fadet mit ihm ein.
        //
        // Der Hover haengt am Item, nicht am Text: das gibt eine Trefferflaeche,
        // die groesser ist als der 15px-Glyph (dasselbe Muster wie bei den
        // Workspace-Punkten), und damit auch die Cursor-Form eine Flaeche hat,
        // auf der sie greift. Der rechte Rand ist so gewaehlt, dass der Glyph
        // selbst ~14px von der Kartenkante steht.
        Item {
            id: powerButton

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: clock.verticalCenter
            }
            implicitWidth: 28
            implicitHeight: 28
            opacity: notch.expanded && !notch.launcherOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent

                text: "power_settings_new"   // Material-Symbols-Ligatur, genau so
                color: powerHover.hovered ? Colors.error : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
                // Material Symbols ist eine Variable Font: die Strichstaerke
                // haengt an der wght-Achse (100-700), nicht an font.weight.
                font.variableAxes: ({ wght: 700 })

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            HoverHandler {
                id: powerHover

                cursorShape: Qt.PointingHandCursor
            }

            // Noch ohne Funktion: der Klick meldet sich vorerst nur im Log
            // (`qs -c dynamic-island log`). TapHandler statt MouseArea, damit
            // der Launcher-DragHandler in der Karte seinen Druck behaelt –
            // ein Zug nach unten bricht den Tap ab, statt ihn wegzuschnappen.
            TapHandler {
                onTapped: console.log("Power-Knopf: geklickt (noch ohne Funktion)")
            }
        }

        // Wallpaper-Knopf: das Gegenstueck zum Power-Knopf, linke Seite
        // derselben Zeile. Oeffnet den Launcher direkt in der Wallpaper-
        // Auswahl – derselbe Weg wie `>wallpaper` im Suchfeld.
        Item {
            id: wallpaperButton

            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: clock.verticalCenter
            }
            implicitWidth: 28
            implicitHeight: 28
            opacity: notch.expanded && !notch.launcherOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent

                // Dasselbe Symbol, das caelestia im Launcher nimmt. "wallpaper"
                // gaebe es auch (mit pango-view geprueft) – ein einzelner
                // Bilderrahmen statt zweier.
                text: "wallpaper_slideshow"   // Material-Symbols-Ligatur, genau so
                color: wallpaperHover.hovered ? Colors.primary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
                font.variableAxes: ({ wght: 700 })

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            HoverHandler {
                id: wallpaperHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: LauncherState.showWallpapers(notch.QsWindow.window.screen)
            }
        }

        DatePanel {
            id: panel

            topOffset: notch.collapsedHeight + notch.clockDrop
            cardRadius: notch.cardRadius
            gestureArea: pill                 // Mausrad gilt auf der ganzen Karte
            dragEnabled: !launcherDrag.active
            opacity: notch.expanded && !notch.launcherOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        LauncherPanel {
            id: launcher

            topOffset: notch.launcherTop
            cardRadius: notch.cardRadius
            active: notch.appsOpen
            opacity: notch.appsOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        WallpaperPanel {
            id: wallpapers

            topOffset: notch.launcherTop
            cardRadius: notch.cardRadius
            active: notch.wallpaperOpen
            opacity: notch.wallpaperOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        ThemePanel {
            id: themes

            topOffset: notch.launcherTop
            cardRadius: notch.cardRadius
            active: notch.themeOpen
            opacity: notch.themeOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    // Reiner Hover-Sensor fuer das Auf-/Zuklappen.
    //
    // Frueher eine MouseArea mit `hoverEnabled` – die nimmt Hover-Events aber
    // exklusiv an. Dadurch kam der HoverHandler des Power-Knopfs darunter nie
    // zum Zug: kein Farbwechsel, keine Cursor-Form. HoverHandler blockieren
    // sich gegenseitig nicht, beide sehen denselben Zeiger. Klicks nimmt der
    // hier ohnehin keine, der DragHandler in der Karte behaelt seinen Druck.
    HoverHandler {
        id: hoverSensor
    }
}
