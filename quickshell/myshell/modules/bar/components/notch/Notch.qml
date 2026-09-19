pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "root:/"

// Notch mit Uhr. Nach kurzem Verweilen klappt sie nach unten auf und zeigt
// Monat, Wochentage und das Datum (heute hervorgehoben). Durch die Tage kommt
// man per Mausrad oder Ziehen. Die Karte bleibt dabei ein einziges Rechteck –
// kein zweites Fenster, deshalb keine Naht. Damit das geht, ist das Bar-Fenster
// höher als die Leiste (siehe Bar.qml).
Item {
    id: notch

    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor

    readonly property bool containsMouse: ma.containsMouse
    readonly property alias clock: clock
    readonly property alias ma: ma

    // Maße: eingeklappt exakt wie vorher, ausgeklappt wächst nur nach unten
    // (und etwas in die Breite, mittig um die Bildschirmmitte).
    readonly property real cardRadius: 18
    // Das Panel sitzt ein Stück innerhalb der Karte, sonst malt es (samt
    // Vignette) über Rand und Eckenrundung.
    readonly property real panelInset: 2
    // Die Uhr rutscht beim Aufklappen etwas nach unten
    readonly property real clockDrop: expanded ? 7 : 0

    readonly property real collapsedHeight: parent.height - verticalMargin
    readonly property real collapsedWidth: clock.implicitWidth + 50
    readonly property real expandedWidth: Math.max(collapsedWidth, panel.implicitWidth + panelInset * 2)
    readonly property real expandedHeight: collapsedHeight + 7 + panel.implicitHeight + panelInset
    // Reserve, die sich das Bar-Fenster nach unten nehmen muss
    readonly property real maxDrop: panel.implicitHeight + verticalMargin + 9

    property bool expanded: false

    anchors.horizontalCenter: parent.horizontalCenter
    y: verticalMargin / 2
    width: expanded ? expandedWidth : collapsedWidth
    height: expanded ? expandedHeight : collapsedHeight

    // Aufklappen erst nach kurzem Verweilen, Zuklappen mit Nachlauf
    onContainsMouseChanged: {
        if (containsMouse) {
            closeTimer.stop();
            if (!expanded)
                openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
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
            if (dragHandler.active)   // beim Ziehen darf die Maus rausrutschen
                closeTimer.restart();
            else
                notch.expanded = false;
        }
    }

    // Beim Zuklappen wieder auf heute zurückspringen
    onExpandedChanged: if (!expanded) panel.dayOffset = 0

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

        // Rad und Ziehen liegen auf der ganzen Karte, nicht nur auf dem
        // Datumsstreifen – sonst passiert nichts, solange der Zeiger noch
        // über der Uhr steht.
        WheelHandler {
            id: wheel

            enabled: notch.expanded
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            // Hi-Res-Räder (z.B. G502 im Free-Spin) liefern Bruchteile einer
            // Rastung pro Event. Einzeln gerundet wäre das immer 0 -> es würde
            // gar nichts passieren. Deshalb aufsummieren und erst bei einer
            // vollen Rastung einen Tag weiterschalten.
            property real accum: 0

            onWheel: event => {
                const angle = event.angleDelta.y + event.angleDelta.x;
                const pixels = event.pixelDelta.y + event.pixelDelta.x;
                wheel.accum += angle !== 0 ? angle / 120 : pixels / 40;

                const steps = wheel.accum > 0 ? Math.floor(wheel.accum) : Math.ceil(wheel.accum);
                if (steps !== 0) {
                    wheel.accum -= steps;
                    panel.shiftDays(-steps);
                }
                event.accepted = true;
            }
        }

        DragHandler {
            id: dragHandler

            enabled: notch.expanded
            target: null                  // nur Geste, nichts wird verschoben
            yAxis.enabled: false
            cursorShape: Qt.ClosedHandCursor

            property int startOffset: 0

            onActiveChanged: if (active) startOffset = panel.dayOffset
            onTranslationChanged: {
                if (!dragHandler.active)
                    return;
                const step = panel.columnWidth + panel.columnSpacing;
                panel.dayOffset = dragHandler.startOffset - Math.round(dragHandler.activeTranslation.x / step);
            }
        }

        Clock {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            // im eingeklappten Band zentriert, beim Aufklappen etwas tiefer
            y: (notch.collapsedHeight - height) / 2 + notch.clockDrop

            Behavior on y {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        DatePanel {
            id: panel

            anchors {
                top: parent.top
                topMargin: notch.collapsedHeight + notch.clockDrop
                left: parent.left
                right: parent.right
                leftMargin: notch.panelInset
                rightMargin: notch.panelInset
            }
            cornerRadius: notch.cardRadius - notch.panelInset
            opacity: notch.expanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    // Reiner Hover-Sensor: nimmt bewusst keine Klicks an, sonst würde er dem
    // DragHandler darunter den Druck wegschnappen.
    MouseArea {
        id: ma
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
    }
}
