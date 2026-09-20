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
    // (dasselbe Timing wie die Notch, damit Vorbeifahren nicht flackert).
    // Das No-Sleep-Dropdown haengt UNTERHALB der Karte – sein Hover zaehlt
    // mit, sonst klappt die Karte unter der Maus zu, sobald man hinunter in
    // die Eintraege faehrt.
    readonly property bool containsMouse: hoverSensor.hovered || tiles.sleepMenuHovered
    property bool expanded: false

    // Zweite Ansicht der Karte: die WLAN-Liste. Zu macht sie der Zurueck-Pfeil
    // oder – wie bei den Kacheln – die Maus, die weggeht. Nur waehrend ein
    // Passwort getippt wird, bleibt sie stehen; dann haengt auch die Tastatur
    // an der Leiste (siehe Bar.qml).
    property bool wifiOpen: false
    readonly property bool typingPassword: wifiOpen && wifi.passwordSsid !== ""

    function closeWifi(): void {
        settings.wifiOpen = false;
    }

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
    readonly property real expandedWidth: 520
    readonly property real expandedHeight: 10 + (wifiOpen ? wifi.implicitHeight : tiles.implicitHeight) + 10

    // Groesster Fall der WLAN-Ansicht – so viel muss sich das Bar-Fenster nach
    // unten reservieren (siehe Bar.qml), sonst schneidet es die Liste ab.
    readonly property real maxHeight: 10 + 36 + 6 + 268 + 26 + 10
    readonly property real maxDrop: Math.max(0, verticalMargin / 2 + maxHeight - parent.height)

    // Das No-Sleep-Dropdown haengt aus der Karte heraus; Bar.qml haengt es
    // in die Fenster-Maske, damit man die Eintraege klicken kann
    readonly property alias sleepMenu: tiles.sleepMenu

    anchors {
        top: parent.top
        topMargin: verticalMargin / 2   // oben fix -> alles Wachstum geht nach unten
    }
    width: expanded || wifiOpen ? expandedWidth : collapsedSize
    height: expanded || wifiOpen ? expandedHeight : collapsedSize

    // Klappt die Karte zu, ist auch die WLAN-Ansicht und das Dauer-Menue vorbei
    onExpandedChanged: if (!expanded) {
        settings.wifiOpen = false;
        tiles.sleepMenuOpen = false;
    }

    // Eingeklappt greift die halbe Breite (Kreis), aufgeklappt cardRadius
    radius: Math.min(height / 2, cardRadius)
    color: Colors.background
    border.width: borderWidth
    border.color: Colors.outlineVariant
    clip: false   // muss offen sein: das Dropdown haengt unten raus

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
        id: tiles

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        opacity: settings.expanded && !settings.wifiOpen ? 1 : 0
        visible: opacity > 0

        onOpenWifi: settings.wifiOpen = true

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    WifiPanel {
        id: wifi

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        active: settings.wifiOpen
        opacity: settings.wifiOpen ? 1 : 0
        visible: opacity > 0

        onClosed: settings.wifiOpen = false

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
        // Waehrend eines Passworts darf die Maus rausrutschen
        onTriggered: if (!settings.typingPassword)
            settings.expanded = false
    }

    // Reiner Hover-Sensor, zuletztdeklariert (Muster siehe Notch.qml)
    HoverHandler {
        id: hoverSensor
    }
}
