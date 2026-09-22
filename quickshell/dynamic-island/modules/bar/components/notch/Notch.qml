pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.modules.services.config
import qs.modules.services.auth
import qs.modules.services.record
import qs.modules.services.system

import qs
import qs.modules.launcher
// Fuer den Ring um die Uhr – derselbe, der an der Settings-Pille haengt
import qs.modules.bar.components.settings

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
    readonly property bool powerOpen: launcherOpen && LauncherState.mode === "power"
    readonly property bool appsOpen: launcherOpen && !wallpaperOpen && !themeOpen && !powerOpen
    readonly property bool authOpen: Auth.active && Auth.screen === hostScreen
    readonly property bool open: expanded || launcherOpen || authOpen

    // Die Uhr rutscht beim Aufklappen etwas nach unten
    readonly property real clockDropMax: 7
    readonly property real clockDrop: open ? clockDropMax : 0

    // Roter Punkt neben der Uhr, solange eine Bildschirmaufnahme läuft.
    // Solange er da ist, wird die Pille um genau seinen Platz breiter und die
    // Uhr rückt um die Hälfte davon nach links – so steht das Paar aus Uhr
    // und Punkt weiterhin mittig in der Pille.
    readonly property bool recording: Recorder.active
    readonly property real recordDotSize: 8
    readonly property real recordGap: 7
    readonly property real recordReserve: recording ? recordDotSize + recordGap : 0
    // Im Launcher-Modus ist die Uhr ausgeblendet, das Panel beginnt oben
    readonly property real launcherTop: 10

    // Maße: eingeklappt exakt wie vorher, ausgeklappt wächst die Karte nach
    // unten und mittig etwas in die Breite.
    readonly property real collapsedHeight: parent.height - verticalMargin
    readonly property real collapsedWidth: clock.implicitWidth + 50 + recordReserve
    readonly property real launcherWidth: wallpaperOpen ? wallpapers.outerWidth
                                        : themeOpen ? themes.outerWidth
                                        : powerOpen ? powerMenu.outerWidth
                                        : launcher.outerWidth
    readonly property real launcherHeight: wallpaperOpen ? wallpapers.outerHeight
                                         : themeOpen ? themes.outerHeight
                                         : powerOpen ? powerMenu.outerHeight
                                         : launcher.outerHeight

    readonly property real expandedWidth: authOpen ? Math.max(collapsedWidth, authPanel.outerWidth)
                                                   : launcherOpen ? Math.max(collapsedWidth, launcherWidth)
                                                                  : Math.max(collapsedWidth, panel.outerWidth)
    readonly property real expandedHeight: authOpen ? launcherTop + authPanel.outerHeight
                                                    : launcherOpen ? launcherTop + launcherHeight
                                                                   : collapsedHeight + clockDropMax + panel.outerHeight
    // Reserve, die sich das Bar-Fenster nach unten nehmen muss (größter Fall)
    readonly property real maxDrop: Math.max(clockDropMax + panel.outerHeight,
                                             launcherTop + launcher.maxOuterHeight,
                                              launcherTop + wallpapers.maxOuterHeight,
                                              launcherTop + themes.maxOuterHeight,
                                              launcherTop + powerMenu.maxOuterHeight,
                                              launcherTop + authPanel.maxOuterHeight) + verticalMargin

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
    onAuthOpenChanged: {
        if (authOpen) {
            expanded = false;
            LauncherState.close();
        }
    }

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
            enabled: !LauncherState.open && !Auth.active

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
            // Platz für den Aufnahme-Punkt rechts daneben (0, wenn keiner da)
            anchors.horizontalCenterOffset: -notch.recordReserve / 2
            // im eingeklappten Band zentriert, beim Aufklappen etwas tiefer;
            // im Launcher-Modus macht sie ganz Platz
            y: (notch.collapsedHeight - height) / 2 + notch.clockDrop
            opacity: notch.launcherOpen || notch.authOpen ? 0 : 1
            visible: opacity > 0

            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            // Gleiches Timing wie die Pille selbst, damit Uhr und Kante
            // zusammen wandern
            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        // Der Aufnahme-Punkt. Er pulst langsam, damit er als Zustand lesbar
        // ist und nicht als Deko; im Launcher-Modus geht er mit der Uhr.
        Item {
            id: recordDot

            anchors {
                left: clock.right
                leftMargin: notch.recordGap
                verticalCenter: clock.verticalCenter
            }
            implicitWidth: notch.recordDotSize
            implicitHeight: notch.recordDotSize
            opacity: notch.recording && !notch.launcherOpen && !notch.authOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent

                radius: width / 2
                color: Colors.record

                SequentialAnimation on opacity {
                    running: notch.recording
                    loops: Animation.Infinite

                    NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
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
            showTrack: false
            value: Power.percent / 100
            muted: false
            activeColor: Colors.mix(Colors.primary, Colors.error, batteryRing.drain)

            opacity: notch.open || !Power.hasSystemBattery || !Config.bar.battery ? 0 : 1
            // Nicht ueber die aufklappende Karte mitstrecken. Beim Schliessen
            // darf der Ring weiterhin weich wieder eingeblendet werden.
            visible: !notch.open && Power.hasSystemBattery && Config.bar.battery

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        // Der leere Teil bleibt ein statischer Pfad und wird deshalb nur bei
        // einer Aenderung des Akkustands neu aufgebaut.
        Audioslider {
            id: batteryEmpty

            readonly property real progress: Power.percent / 100

            arcWidth: 2
            arcGap: 3
            showTrack: false
            muted: false
            fromValue: progress
            value: 1
            activeColor: Colors.alpha(batteryRing.activeColor, 0.55)

            opacity: notch.open || !Power.hasSystemBattery || !Config.bar.battery ? 0 : 1
            // Sofort ausblenden: Sonst wird der Wellenpfad waehrend der
            // breiten Launcher-Animation fuer jeden Frame neu berechnet.
            visible: !notch.open && Power.hasSystemBattery && Config.bar.battery
        }

        // Effizienter Ladeimpuls: statt den SVG-Pfad pro Frame neu zu bauen,
        // bewegt sich nur ein kleines Rechteck entlang der vorhandenen
        // Ring-Geometrie. Die Weggeschwindigkeit skaliert mit der Ladeleistung.
        Item {
            id: batteryPulse

            readonly property real chargeProgress: Power.percent / 100
            readonly property bool running: Config.bar.batteryPulse
                && Config.bar.battery && Power.activelyCharging
                && chargeProgress < 0.995 && !notch.open
            readonly property real rateFactor: Math.max(0, Math.min(1,
                (Power.chargeRate - 5) / 60))
            readonly property real pathStart: batteryRing.fromLength
                + (batteryRing.toLength - batteryRing.fromLength) * chargeProgress
            readonly property real pathLength: Math.max(0, batteryRing.toLength - pathStart)
            readonly property real distance: pathStart + pathLength * travel
            readonly property var point: batteryRing.pointAt(distance)
            readonly property int travelDuration: Math.round(750 - rateFactor * 400)
            readonly property int pulseInterval: Math.round(1800 - rateFactor * 1200)

            property real travel: 0

            anchors.fill: parent
            visible: running

            Rectangle {
                width: 7
                height: 7
                radius: width / 2
                x: batteryPulse.point.x - width / 2
                y: batteryPulse.point.y - height / 2
                color: Colors.alpha(batteryRing.activeColor, 0.22)
                opacity: pulseCore.opacity
            }

            Rectangle {
                id: pulseCore

                width: 3
                height: 3
                radius: width / 2
                x: batteryPulse.point.x - width / 2
                y: batteryPulse.point.y - height / 2
                color: Colors.mix(batteryRing.activeColor, Colors.fgBackground, 0.7)
                opacity: Math.max(0, Math.min(1,
                    Math.min(batteryPulse.travel / 0.1,
                             (1 - batteryPulse.travel) / 0.18)))
            }

            SequentialAnimation on travel {
                running: batteryPulse.running
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0
                    to: 1
                    duration: batteryPulse.travelDuration
                    easing.type: Easing.InOutSine
                }

                PauseAnimation {
                    duration: batteryPulse.pulseInterval
                }
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
            opacity: notch.expanded && !notch.launcherOpen && !notch.authOpen ? 1 : 0
            visible: notch.expanded && !notch.launcherOpen && !notch.authOpen

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

            // TapHandler statt MouseArea, damit der Launcher-DragHandler in der
            // Karte seinen Druck behaelt: ein Zug nach unten bricht den Tap ab.
            TapHandler {
                onTapped: LauncherState.showPower(notch.QsWindow.window.screen)
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
            opacity: notch.expanded && !notch.launcherOpen && !notch.authOpen ? 1 : 0
            visible: notch.expanded && !notch.launcherOpen && !notch.authOpen

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
            opacity: notch.expanded && !notch.launcherOpen && !notch.authOpen ? 1 : 0
            // Beim Wechsel zum Launcher sofort aus dem Renderpfad nehmen. So
            // wird der Datumsstreifen nicht auf Launcherbreite mitanimiert.
            visible: notch.expanded && !notch.launcherOpen && !notch.authOpen

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
            visible: notch.appsOpen

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
            visible: notch.wallpaperOpen

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
            visible: notch.themeOpen

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        PowerPanel {
            id: powerMenu

            topOffset: notch.launcherTop
            cardRadius: notch.cardRadius
            active: notch.powerOpen
            opacity: notch.powerOpen ? 1 : 0
            visible: notch.powerOpen

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }

        AuthPanel {
            id: authPanel

            topOffset: notch.launcherTop
            cardRadius: notch.cardRadius
            active: notch.authOpen
            flow: Auth.flow
            opacity: notch.authOpen ? 1 : 0
            visible: notch.authOpen

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
