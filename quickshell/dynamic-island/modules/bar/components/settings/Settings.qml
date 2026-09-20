pragma ComponentBehavior: Bound
import QtQuick

import "root:/"

// Settings-Knopf rechts neben der Notch. Bei Hover waechst er wie die Notch
// zu einer (noch leeren) Karte – nach RECHTS und UNTEN: oben links fix
// (x kommt aus Bar.qml linksseitig, y haengt oben am Leistenrand).
// Eingeklappt zeigen Wifi- und VPN-Icon, aufgeklappt ist die Karte leer.
Rectangle {
    id: settings

    // Schnittstelle (Bar.qml setzt verticalMargin/cardRadius)
    required property real verticalMargin
    required property real cardRadius
    property real borderWidth: 1

    // Auf-/Zuklappen: kurzes Verweilen zum Oeffnen, Nachlauf beim Schliessen
    // (dasselbe Timing wie die Notch, damit Vorbeifahren nicht flackert)
    readonly property bool containsMouse: hoverSensor.hovered
    property bool expanded: false

    onContainsMouseChanged: {
        if (containsMouse) {
            closeTimer.stop();
            openTimer.restart();
        } else {
            openTimer.stop();
            closeTimer.restart();
        }
    }

    // Masse: eingeklappt der gewohnte Kreis, ausgeklappt die Karte. Hoehe =
    // Kachelreihen + Raender (kein Kreis-Vorlauf mehr, die Tiles stehen oben).
    readonly property real collapsedSize: parent.height - verticalMargin
    readonly property real expandedWidth: 360
    readonly property real expandedHeight: 120

    anchors {
        top: parent.top
        topMargin: verticalMargin / 2   // oben fix -> alles Wachstum geht nach unten
    }
    width: expanded ? expandedWidth : collapsedSize
    height: expanded ? expandedHeight : collapsedSize

    // Eingeklappt greift die halbe Breite (Kreis), aufgeklappt cardRadius
    radius: Math.min(height / 2, cardRadius)
    color: Colors.background
    border.width: borderWidth
    border.color: Colors.outlineVariant
    clip: true   // beim Schrumpfen duerfen die Icons kurz aus der Karte ragen

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Lautstaerke-Ring um den Kreis – reine ANZEIGE (Scrollen/Klicken ist
    // raus, das Volumen regelt man woanders). Blendet beim Aufklappen mit
    // den Icons aus, damit die Karte leer wirkt.
    Audioslider {
        anchors.fill: parent
        arcWidth: 2
        arcGap: 3
        startAngle: 130
        sweepAngle: 280

        opacity: settings.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    // Wifi-Status mittig im Kreis, blendet beim Aufklappen aus
    Wifi {
        opacity: settings.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    // VPN-Status unten im Kreis, dito
    VpnIcon {
        opacity: settings.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    // Der Kachel-Inhalt der ausgeklappten Karte (Wi-Fi, Bluetooth, VPN,
    // No-Sleep + Game-/DND-Kreise), fuellt die Karte komplett – oben beginnt
    // direkt die erste Reihe, kein Whitespace.
    SettingsTiles {
        anchors.fill: parent
        anchors.margins: 10
        opacity: settings.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Timer {
        id: openTimer

        interval: 180
        onTriggered: settings.expanded = true
    }

    Timer {
        id: closeTimer

        interval: 250
        onTriggered: settings.expanded = false
    }

    // Reiner Hover-Sensor, zuletztdeklariert (Muster siehe Notch.qml)
    HoverHandler {
        id: hoverSensor
    }
}
