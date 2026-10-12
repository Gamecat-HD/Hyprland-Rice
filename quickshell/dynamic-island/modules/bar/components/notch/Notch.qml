pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import qs.modules.services.config
import qs.modules.services.auth
import qs.modules.services.record
import qs.modules.services.system
import qs.modules.services.media
import qs.modules.services.audio
import qs.modules.services.notifications

import qs
import qs.modules.launcher
import qs.modules.widgets
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

    // Notch-Layout: die Karte haengt an der Oberkante (oben eckig, der Rand
    // liegt knapp ausserhalb des Bildschirms) und ist das einzige Element
    // der Leiste – Bar.qml blendet die anderen Pillen aus. Etwas hoeher und
    // breiter als die Insel, damit sie als Notch liest und nicht als Pille.
    readonly property bool docked: Config.appearance.layout === "notch"

    // ---- Angedockte Notch (saneAspect-Vorbild) ----
    // Schwarz wie der Displayrahmen, ohne Rand, mit gewoelbten Schultern an
    // der Oberkante (NotchShoulder links und rechts AUSSERHALB der Breite).
    // Eingeklappt ist sie eine breite, flache Leiste: links die Workspaces,
    // mittig die Uhr, rechts Datum und Hinweise. Beide Seiten sind gleich
    // breit (compactSide), damit die Uhr immer in der Mitte steht.
    readonly property real shoulder: open ? Appearance.notchShoulderOpen : Appearance.notchShoulder
    // Unter dem Zeiger waechst sie ein Stueck nach unten und zur Seite
    readonly property bool hoverGrow: docked && hoverSensor.hovered && !open
    readonly property real growth: hoverGrow ? Appearance.notchHoverLift : 0
    readonly property real compactEdge: 14   // Kante -> erstes Element
    readonly property real compactGap: 14    // Element -> Uhr
    readonly property real compactMinWidth: 196
    readonly property bool showWorkspaces: docked && Config.notch.workspaces
    readonly property real compactLeft: showMedia ? mediaArtSize - (compactEdge - mediaEdge)
                                      : showWorkspaces ? compactWorkspaces.implicitWidth
                                      : 0
    readonly property real compactSide: Math.max(compactLeft, compactRight.implicitWidth)
    // Hoehe des oberen Bands (eingeklappt plus Hover-Wachstum): Uhr und
    // Seitenelemente bleiben darin mittig
    readonly property real bandHeight: collapsedHeight + growth

    // Der Hub: im Notch-Layout parkt Bar.qml die anderen Pillen (Workspaces,
    // Tray, Settings, Medien, Benachrichtigungen, System) hier um – sie
    // erscheinen, sobald die Notch aufklappt, unter dem Datumsstreifen. Es
    // sind dieselben Instanzen wie in der Leiste, nur mit anderem `parent`;
    // deshalb funktionieren WLAN-Passwort, Tray-Menues und Tastaturfokus
    // weiter ueber die Referenzen in Bar.qml.
    //
    // Der Hub selbst bleibt immer 40 px hoch (= Leistenhoehe, die Pillen
    // rechnen ihre Kreisgroesse aus parent.height). Klappt eine Pille darin
    // auf, ragt sie nach unten heraus – die Karte waechst mit (hubBottom).
    readonly property alias hub: hub
    // Die Pillen sind ein eigenes Menue ("Steuerung"): aufgeklappt zeigt die
    // Notch zuerst nur Kopfzeile und Datum, der Umschalter unten wechselt
    // zwischen den Seiten. Beim Zuklappen geht es zurueck auf "date".
    property string page: "date"
    readonly property bool hubPage: docked && page === "hub"
    readonly property bool cardShown: expanded && !launcherOpen && !authOpen
    readonly property bool hubShown: docked && hubPage && cardShown
    readonly property bool dateShown: cardShown && !hubPage
    readonly property real hubMinWidth: 600
    readonly property real hubHeight: 40
    // Rechter Rand des breitesten Elements, setzt Bar.qml (Settings-Karte)
    property real hubContentWidth: 0
    readonly property real hubWidth: Math.max(hubMinWidth, hubContentWidth)
    readonly property real hubBottom: hub.childrenRect.y + hub.childrenRect.height
    // Unterkante der aktiven Seite, darunter sitzt der Seiten-Umschalter
    readonly property real panelBottom: collapsedHeight + clockDropMax + panel.outerHeight
    readonly property real pageBottom: hubPage ? hub.y + hubBottom : panelBottom
    readonly property real pageSwitchGap: 8

    // Kopfzeile der aufgeklappten Karte: runde Knoepfe links und rechts der Uhr
    readonly property real headerButtonSize: 30
    readonly property real headerInset: docked ? 12 : 8
    readonly property real headerSpacing: 6
    // Die Kopfzeile braucht Platz fuer je zwei Knoepfe links und rechts der
    // (aufgeklappt 1.3x grossen) Uhr
    readonly property real headerMinWidth: clock.implicitWidth * 1.3
        + 2 * (headerInset + 2 * headerButtonSize + headerSpacing + 18)

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
    // Angedockt sitzt der Punkt in der rechten Gruppe (compactRight)
    readonly property real recordReserve: recording && !docked ? recordDotSize + recordGap : 0

    // Live-Activity: laeuft Musik, zeigt die Insel links das Cover und rechts
    // drei Pegelbalken – die Dynamic-Island-Idee. Beides weicht, sobald die
    // Karte aufklappt, dort sitzen dann die Knoepfe. Die Pille wird dafuer
    // auf beiden Seiten gleich breiter, die Uhr bleibt also mittig.
    readonly property bool showMedia: docked && Config.notch.media && Media.playing
    readonly property real mediaArtSize: 20
    readonly property real mediaEdge: 8

    // Nachrichten-Zaehler rechts neben der Uhr (nur Notch-Layout, schaltbar)
    readonly property bool showMessages: docked && Config.notch.messages && Notifications.count > 0
    readonly property real messageBadgeSize: 16
    // Im Launcher-Modus ist die Uhr ausgeblendet, das Panel beginnt oben
    readonly property real launcherTop: 10

    // Maße: eingeklappt exakt wie vorher, ausgeklappt wächst die Karte nach
    // unten und mittig etwas in die Breite.
    // Angedockt: 1 px hoeher, weil der obere Rand ausserhalb liegt (y < 0)
    readonly property real collapsedHeight: docked ? parent.height - 8 : parent.height - verticalMargin
    readonly property real collapsedWidth: docked
        ? Math.max(compactMinWidth, clock.implicitWidth + 2 * (compactSide + compactGap + compactEdge))
        : clock.implicitWidth + 50 + recordReserve
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
                                                   : hubPage ? Math.max(collapsedWidth, hubWidth)
                                                   : docked ? Math.max(collapsedWidth, panel.outerWidth + 2 * headerInset, headerMinWidth)
                                                            : Math.max(collapsedWidth, panel.outerWidth)
    readonly property real expandedHeight: authOpen ? launcherTop + authPanel.outerHeight
                                                    : launcherOpen ? launcherTop + launcherHeight
                                                    : docked ? pageSwitch.y + pageSwitch.height + 10
                                                             : collapsedHeight + clockDropMax + panel.outerHeight
    // Reserve, die sich das Bar-Fenster nach unten nehmen muss (größter Fall)
    readonly property real maxDrop: Math.max(clockDropMax + panel.outerHeight,
                                             launcherTop + launcher.maxOuterHeight,
                                              launcherTop + wallpapers.maxOuterHeight,
                                              launcherTop + themes.maxOuterHeight,
                                              launcherTop + powerMenu.maxOuterHeight,
                                              launcherTop + authPanel.maxOuterHeight) + verticalMargin

    anchors.horizontalCenter: parent.horizontalCenter
    y: docked ? 0 : verticalMargin / 2
    width: open ? expandedWidth : collapsedWidth + 2 * growth
    height: open ? expandedHeight : collapsedHeight + growth

    // Die Insel reagiert sofort auf den Zeiger – noch bevor sie aufklappt.
    // Angedockt waechst sie stattdessen (growth): eine skalierte Notch
    // wuerde sich mitsamt Schultern von der Oberkante loesen.
    scale: !docked && hoverSensor.hovered && !open ? 1.04 : 1

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
    onExpandedChanged: {
        if (!expanded) {
            panel.dayOffset = 0;
            page = "date";
        }
    }
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

    Morph on width {}
    Morph on height {}
    Morph on scale {}

    // Pille, solange sie flach ist; ab 2 x cardRadius Hoehe eine Karte.
    // Verlauf, Rand und Schatten bringt Surface mit (modules/widgets).
    Surface {
        id: pill
        anchors.fill: parent

        maxRadius: notch.cardRadius
        // Angedockt: schwarz, flach und ohne Rand – sie soll wie ein Teil
        // des Displayrahmens wirken, die Schultern muessen nahtlos passen.
        baseColor: notch.docked ? Appearance.notchColor : Colors.background
        lift: notch.docked ? 0 : Appearance.lift
        borderWidth: notch.docked ? 0 : notch.borderWidth
        borderColor: notch.borderColor
        docked: notch.docked
        // Eingeklappt ist sie Rahmen, kein Objekt – Schatten erst, wenn sie
        // als Karte ueber den Fenstern liegt
        shadowStrength: !notch.docked || notch.open ? 1 : 0

        Behavior on shadowStrength {
            NumberAnimation { duration: Appearance.morphDuration * 0.65; easing.type: Easing.OutCubic }
        }

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
            y: (notch.bandHeight - height) / 2 + notch.clockDrop
            // Angedockt wird sie aufgeklappt zur Ueberschrift der Karte
            scale: notch.docked && notch.expanded ? 1.3 : 1
            // Aufgeklappt nimmt die Uhr die Akzentfarbe an
            color: notch.open ? Colors.primary : Colors.fgBackground
            opacity: notch.launcherOpen || notch.authOpen ? 0 : 1
            visible: opacity > 0

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            Behavior on y {
                NumberAnimation { duration: Appearance.morphDuration * 0.65; easing.type: Easing.OutCubic }
            }
            Morph on scale {}
            Behavior on opacity {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
            }
            // Gleiches Timing wie die Pille selbst, damit Uhr und Kante
            // zusammen wandern
            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation { duration: Appearance.morphDuration * 0.65; easing.type: Easing.OutCubic }
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
            opacity: notch.recording && !notch.docked && !notch.launcherOpen && !notch.authOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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

        // ---- Eingeklappt, links: Workspaces (Notch-Layout) ----
        // Die grosse Workspace-Pille parkt im Hub; das hier ist ihre
        // Kurzfassung, solange die Notch zu ist. Laeuft Musik, nimmt das
        // Cover (mediaArt) diesen Platz ein.
        NotchWorkspaces {
            id: compactWorkspaces

            anchors {
                left: parent.left
                leftMargin: notch.compactEdge + notch.growth
                verticalCenter: clock.verticalCenter
            }
            opacity: notch.showWorkspaces && !notch.showMedia && !notch.open ? 1 : 0
            visible: opacity > 0

            Fade on opacity {}
        }

        // ---- Eingeklappt, rechts: Hinweise + Datum bzw. Pegel ----
        // Von innen nach aussen: Aufnahme-Punkt, Nachrichten-Zaehler, dann
        // Datum – oder, solange Musik laeuft, die Cava-Pegel. Die Notch misst
        // ihre Breite an dieser Gruppe (compactSide), die Uhr bleibt mittig.
        Row {
            id: compactRight

            anchors {
                right: parent.right
                rightMargin: (notch.showMedia ? notch.mediaEdge + 3 : notch.compactEdge) + notch.growth
                verticalCenter: clock.verticalCenter
            }
            spacing: 8
            opacity: notch.docked && !notch.open ? 1 : 0
            visible: opacity > 0

            Fade on opacity {}

            // Aufnahme-Punkt, pulst langsam wie sein Gegenstueck im Insel-Layout
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: notch.recording
                width: notch.recordDotSize
                height: notch.recordDotSize
                radius: width / 2
                color: Colors.record

                SequentialAnimation on opacity {
                    running: notch.recording && notch.docked
                    loops: Animation.Infinite

                    NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            // Nachrichten-Zaehler
            Rectangle {
                id: messageBadge

                anchors.verticalCenter: parent.verticalCenter
                visible: notch.showMessages
                width: Math.max(notch.messageBadgeSize, badgeText.implicitWidth + 8)
                height: notch.messageBadgeSize
                radius: height / 2
                color: Colors.primary

                Text {
                    id: badgeText

                    anchors.centerIn: parent
                    font.family: Config.font
                    text: Notifications.count > 9 ? "9+" : Notifications.count
                    color: Colors.fgPrimary
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            // Wochentag und Tag, gedaempft – die Uhr bleibt der Blickfang
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.notch.date && !notch.showMedia
                text: Qt.formatDate(clock.date, "ddd d")
                color: Colors.alpha(Colors.fgBackground, 0.55)
                font.family: Config.font
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            // Live-Activity: Pegel als gespiegelte Wellenform
            Visualizer {
                id: mediaBars

                anchors.verticalCenter: parent.verticalCenter
                visible: notch.showMedia
                height: notch.mediaArtSize - 4
                count: 5
                barWidth: 3
                active: Media.playing
            }
        }

        // ---- Knoepfe der Kopfzeile ----
        // Runde Chips links und rechts der Uhr, sobald die Karte aufgeklappt
        // ist: aussen Wallpaper bzw. Power, innen (nur Notch-Layout) die
        // Schalter fuer das, was die eingeklappte Notch zeigt. Ein aktiver
        // Schalter fuellt sich in der Akzentfarbe, `danger` faerbt den Hover
        // rot (Power).
        //
        // TapHandler statt MouseArea, damit der Launcher-DragHandler in der
        // Karte seinen Druck behaelt: ein Zug nach unten bricht den Tap ab.
        component NotchButton: Item {
            id: button

            required property string icon
            property bool active: false
            property bool danger: false
            // Zusaetzliche Bedingung (die Schalter gibt es nur angedockt)
            property bool available: true
            signal clicked()

            readonly property bool shown: button.available && notch.expanded
                                          && !notch.launcherOpen && !notch.authOpen

            implicitWidth: notch.headerButtonSize
            implicitHeight: notch.headerButtonSize
            opacity: button.shown ? 1 : 0
            visible: opacity > 0
            scale: buttonHover.hovered ? 1.08 : 1

            Fade on opacity {}
            Morph on scale {}

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: button.active ? Colors.alpha(Colors.primary, 0.2)
                     : buttonHover.hovered ? Colors.alpha(button.danger ? Colors.error : Colors.fgBackground, 0.14)
                     : Colors.alpha(Colors.fgBackground, 0.06)

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }

            Text {
                anchors.centerIn: parent
                text: button.icon   // Material-Symbols-Ligatur
                color: button.active ? Colors.primary
                     : buttonHover.hovered ? (button.danger ? Colors.error : Colors.fgBackground)
                     : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                // Variable Font: Strichstaerke ueber die wght-Achse
                font.variableAxes: ({ wght: button.active ? 700 : 500, FILL: button.active ? 1 : 0 })

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }

            HoverHandler {
                id: buttonHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: button.clicked()
            }
        }

        // Wallpaper: oeffnet den Launcher direkt in der Wallpaper-Auswahl –
        // derselbe Weg wie `>wallpaper` im Suchfeld
        NotchButton {
            id: wallpaperButton

            anchors {
                left: parent.left
                leftMargin: notch.headerInset
                verticalCenter: clock.verticalCenter
            }
            icon: "wallpaper_slideshow"
            onClicked: LauncherState.showWallpapers(notch.QsWindow.window.screen)
        }

        NotchButton {
            anchors {
                left: wallpaperButton.right
                leftMargin: notch.headerSpacing
                verticalCenter: clock.verticalCenter
            }
            available: notch.docked
            icon: "music_note"
            active: Config.notch.media
            onClicked: Config.set("notch", "media", !Config.notch.media)
        }

        NotchButton {
            id: powerButton

            anchors {
                right: parent.right
                rightMargin: notch.headerInset
                verticalCenter: clock.verticalCenter
            }
            icon: "power_settings_new"
            danger: true
            onClicked: LauncherState.showPower(notch.QsWindow.window.screen)
        }

        NotchButton {
            anchors {
                right: powerButton.left
                rightMargin: notch.headerSpacing
                verticalCenter: clock.verticalCenter
            }
            available: notch.docked
            icon: "notifications"
            active: Config.notch.messages
            onClicked: Config.set("notch", "messages", !Config.notch.messages)
        }

        // ---- Seiten-Umschalter (Notch-Layout) ----
        // Kleiner Chip unten mittig: "Steuerung" oeffnet die Pillen-Seite,
        // dort fuehrt "Kalender" zurueck. Die Karte morpht dabei auf die
        // Groesse der jeweiligen Seite.
        Item {
            id: pageSwitch

            x: (parent.width - width) / 2
            y: notch.pageBottom + notch.pageSwitchGap
            width: switchRow.implicitWidth + 24
            height: 26
            opacity: notch.docked && notch.cardShown ? 1 : 0
            visible: opacity > 0
            scale: switchHover.hovered ? 1.05 : 1

            Fade on opacity {}
            Morph on scale {}

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: switchHover.hovered ? Colors.alpha(Colors.primary, 0.2)
                                           : Colors.alpha(Colors.fgBackground, 0.07)

                Behavior on color {
                    ColorAnimation { duration: Appearance.fadeDuration }
                }
            }

            Row {
                id: switchRow

                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: notch.hubPage ? "calendar_month" : "tune"
                    color: switchHover.hovered ? Colors.primary : Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                    font.variableAxes: ({ wght: 600 })
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: notch.hubPage ? "Kalender" : "Steuerung"
                    color: switchHover.hovered ? Colors.primary : Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: notch.hubPage ? "expand_less" : "expand_more"
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 14
                }
            }

            HoverHandler {
                id: switchHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: notch.page = notch.hubPage ? "date" : "hub"
            }
        }

        // ---- Hub: die umgeparkten Pillen (Notch-Layout) ----
        Item {
            id: hub

            x: (parent.width - width) / 2
            // Auf der Steuerungs-Seite direkt unter der Kopfzeile
            y: notch.collapsedHeight + notch.clockDropMax + 6
            width: notch.hubWidth
            height: notch.hubHeight
            opacity: notch.hubShown ? 1 : 0
            visible: opacity > 0

            Fade on opacity {}
        }

        // ---- Live-Activity: Cover links ----
        Item {
            id: mediaArt

            anchors {
                left: parent.left
                leftMargin: notch.mediaEdge + notch.growth
                verticalCenter: clock.verticalCenter
            }
            width: notch.mediaArtSize
            height: notch.mediaArtSize
            opacity: notch.showMedia && !notch.open ? 1 : 0
            visible: opacity > 0
            scale: notch.showMedia && !notch.open ? 1 : 0.5

            Fade on opacity {}
            Morph on scale {}

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Colors.surfaceContainer

                Text {
                    anchors.centerIn: parent
                    visible: !artEffect.visible

                    text: "music_note"
                    color: Colors.fgSurfaceVariant
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 11
                }
            }

            Image {
                id: artImage

                anchors.fill: parent
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: notch.mediaArtSize * 2
                sourceSize.height: notch.mediaArtSize * 2
                visible: false
            }

            // Rundes Cover: `clip` schneidet nur rechteckig, deshalb die
            // Rundung als Maske (dasselbe Muster wie der Kartengrund der
            // Medien-Karte).
            Rectangle {
                id: artMask

                anchors.fill: parent
                radius: 6
                color: "black"
                layer.enabled: true
                visible: false
            }

            MultiEffect {
                id: artEffect

                anchors.fill: parent
                source: artImage
                maskEnabled: true
                maskSource: artMask
                visible: artImage.status === Image.Ready
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

            opacity: notch.open || notch.docked || !Power.hasSystemBattery || !Config.bar.battery ? 0 : 1
            // Nicht ueber die aufklappende Karte mitstrecken. Beim Schliessen
            // darf der Ring weiterhin weich wieder eingeblendet werden.
            visible: !notch.open && !notch.docked && Power.hasSystemBattery && Config.bar.battery

            Behavior on opacity {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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

            opacity: notch.open || notch.docked || !Power.hasSystemBattery || !Config.bar.battery ? 0 : 1
            // Sofort ausblenden: Sonst wird der Wellenpfad waehrend der
            // breiten Launcher-Animation fuer jeden Frame neu berechnet.
            visible: !notch.open && !notch.docked && Power.hasSystemBattery && Config.bar.battery
        }

        // Effizienter Ladeimpuls: statt den SVG-Pfad pro Frame neu zu bauen,
        // bewegt sich nur ein kleines Rechteck entlang der vorhandenen
        // Ring-Geometrie. Die Weggeschwindigkeit skaliert mit der Ladeleistung.
        Item {
            id: batteryPulse

            readonly property real chargeProgress: Power.percent / 100
            readonly property bool running: Config.bar.batteryPulse
                && Config.bar.battery && Power.activelyCharging
                && chargeProgress < 0.995 && !notch.open && !notch.docked
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

        DatePanel {
            id: panel

            topOffset: notch.collapsedHeight + notch.clockDrop
            cardRadius: notch.cardRadius
            gestureArea: pill                 // Mausrad gilt auf der ganzen Karte
            fadeColor: pill.baseColor
            dragEnabled: !launcherDrag.active
            opacity: notch.dateShown ? 1 : 0
            // Beim Wechsel zum Launcher (oder zur Steuerungs-Seite) sofort aus
            // dem Renderpfad nehmen. So wird der Datumsstreifen nicht auf die
            // neue Kartenbreite mitanimiert.
            visible: notch.dateShown

            Behavior on opacity {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
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
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    // ---- Schultern (Notch-Layout) ----
    // Ausserhalb der Breite, damit die Notch selbst ein Rechteck bleibt
    // (Maske, Anker, Innenmasse). Nach der Karte deklariert, damit sie ueber
    // deren Schatten liegen und die Kante sauber schliessen.
    NotchShoulder {
        x: -width
        y: 0
        size: notch.shoulder
        color: Appearance.notchColor
        visible: notch.docked

        Morph on size {}
    }

    NotchShoulder {
        x: notch.width
        y: 0
        size: notch.shoulder
        color: Appearance.notchColor
        mirrored: true
        visible: notch.docked

        Morph on size {}
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
