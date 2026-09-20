pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "root:/"
import "root:/modules/launcher"

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

    readonly property bool containsMouse: ma.containsMouse
    readonly property alias clock: clock
    readonly property alias ma: ma

    // Datums-Ansicht (per Hover) und Launcher (per Zug nach unten) teilen sich
    // dieselbe Karte – der Launcher hat Vorrang.
    property bool expanded: false
    readonly property var hostScreen: notch.QsWindow.window?.screen ?? null
    readonly property bool launcherOpen: LauncherState.open && LauncherState.screen === hostScreen
    readonly property bool open: expanded || launcherOpen

    readonly property real cardRadius: 18
    // Die Uhr rutscht beim Aufklappen etwas nach unten
    readonly property real clockDropMax: 7
    readonly property real clockDrop: open ? clockDropMax : 0
    // Im Launcher-Modus ist die Uhr ausgeblendet, das Panel beginnt oben
    readonly property real launcherTop: 10

    // Maße: eingeklappt exakt wie vorher, ausgeklappt wächst die Karte nach
    // unten und mittig etwas in die Breite.
    readonly property real collapsedHeight: parent.height - verticalMargin
    readonly property real collapsedWidth: clock.implicitWidth + 50
    readonly property real expandedWidth: launcherOpen ? Math.max(collapsedWidth, launcher.outerWidth)
                                                       : Math.max(collapsedWidth, panel.outerWidth)
    readonly property real expandedHeight: launcherOpen ? launcherTop + launcher.outerHeight
                                                        : collapsedHeight + clockDropMax + panel.outerHeight
    // Reserve, die sich das Bar-Fenster nach unten nehmen muss (größter Fall)
    readonly property real maxDrop: Math.max(clockDropMax + panel.outerHeight,
                                             launcherTop + launcher.maxOuterHeight) + verticalMargin

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
            active: notch.launcherOpen
            opacity: notch.launcherOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    // Reiner Hover-Sensor: nimmt bewusst keine Klicks an, sonst würde er dem
    // DragHandler in der Karte den Druck wegschnappen.
    MouseArea {
        id: ma
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }
}
