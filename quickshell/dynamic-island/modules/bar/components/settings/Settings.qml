pragma ComponentBehavior: Bound
import QtQuick

import qs.modules.services.audio
import qs.modules.services.brightness
import qs.modules.services.config
import qs.modules.services.system
import qs.modules.services.vpn

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

    // Ein Klick oeffnet die Karte. Hover haelt eine geoeffnete Karte nur noch
    // offen; beim Verlassen greift weiterhin der kurze Schliess-Nachlauf.
    readonly property bool containsMouse: hoverSensor.hovered || tiles.sleepMenuHovered
    property bool expanded: false
    property bool showBrightness: false
    // Hovern zieht die Pille seitlich auf und zeigt die Statuszeile
    property bool peek: false

    // Zweite Ansicht der Karte: die WLAN-Liste. Zu macht sie der Zurueck-Pfeil
    // oder – wie bei den Kacheln – die Maus, die weggeht. Nur waehrend ein
    // Passwort getippt wird, bleibt sie stehen; dann haengt auch die Tastatur
    // an der Leiste (siehe Bar.qml).
    property bool wifiOpen: false
    property bool bluetoothOpen: false
    property bool audioOpen: false
    readonly property bool typingPassword: wifiOpen && wifi.passwordSsid !== ""
    readonly property bool typingPin: bluetoothOpen && bluetooth.pairingInputOpen

    function closeWifi(): void {
        settings.wifiOpen = false;
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            closeTimer.stop();
            peekClose.stop();
            if (!expanded && !wifiOpen && !bluetoothOpen && !audioOpen)
                peekTimer.restart();
        } else {
            peekTimer.stop();
            peekClose.restart();
            if (expanded)
                closeTimer.restart();
        }
    }

    // Erst nach kurzem Verweilen aufziehen, damit blosses Vorbeifahren die
    // Pille nicht zucken laesst (dasselbe Timing wie bei der Notch)
    Timer {
        id: peekTimer

        interval: 180
        onTriggered: settings.peek = true
    }

    Timer {
        id: peekClose

        interval: 260
        onTriggered: settings.peek = false
    }

    // Masse: eingeklappt der gewohnte Kreis, ausgeklappt die Karte. Hoehe =
    // Kachelreihen + Raender (kein Kreis-Vorlauf mehr, die Tiles stehen oben).
    readonly property real collapsedSize: parent.height - verticalMargin
    readonly property real expandedWidth: 520
    readonly property real expandedHeight: 10 + (wifiOpen ? wifi.implicitHeight
                                               : bluetoothOpen ? bluetooth.implicitHeight
                                               : audioOpen ? audio.implicitHeight
                                               : tiles.implicitHeight) + 10

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
    // Aufgeklappt die Karte, beim Hovern die Statuszeile, sonst der Kreis
    readonly property real peekWidth: status.implicitWidth + 12
    width: expanded || wifiOpen || bluetoothOpen || audioOpen ? expandedWidth
         : peek ? peekWidth
         : collapsedSize
    height: expanded || wifiOpen || bluetoothOpen || audioOpen ? expandedHeight : collapsedSize

    // Klappt die Karte zu, ist auch die WLAN-Ansicht und das Dauer-Menue vorbei
    onExpandedChanged: if (!expanded) {
        settings.wifiOpen = false;
        settings.bluetoothOpen = false;
        settings.audioOpen = false;
        tiles.sleepMenuOpen = false;
    } else {
        settings.showBrightness = false;
        settings.peek = false;          // die Karte loest die Statuszeile ab
        brightnessDisplayTimer.stop();
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

        opacity: settings.expanded || settings.showBrightness ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Audioslider {
        anchors.fill: parent
        arcWidth: 2
        arcGap: 3
        startAngle: 130
        sweepAngle: 280
        value: Brightness.value
        muted: false
        activeColor: Brightness.value > 0.5
                     ? Colors.fgSurfaceVariant
                     : Colors.alpha(Colors.fgSurfaceVariant, 0.45)

        opacity: !settings.expanded && settings.showBrightness ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    // Statuszeile: eingeklappt steht hier nur das WLAN-Symbol – und zwar
    // genau dort, wo es vorher mittig im Kreis sass, weil das erste Feld so
    // breit ist wie der Kreis. Beim Hovern kommen die anderen dazu und
    // schieben die Pille auf.
    Row {
        id: status

        anchors {
            left: parent.left
            top: parent.top
        }
        height: settings.collapsedSize
        spacing: 2
        opacity: settings.expanded ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        component StatusIcon: Text {
            id: icon

            property bool active: false
            property bool shown: true

            anchors.verticalCenter: parent?.verticalCenter ?? undefined
            width: settings.peek && icon.shown ? implicitWidth + 6 : 0
            visible: width > 0
            opacity: settings.peek && icon.shown ? 1 : 0
            horizontalAlignment: Text.AlignHCenter

            color: icon.active ? Colors.secondary : Colors.alpha(Colors.fgSurfaceVariant, 0.6)
            font.family: "Material Symbols Outlined"
            font.pixelSize: 15

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
        }

        // WLAN – das einzige, was immer zu sehen ist
        Item {
            width: settings.collapsedSize
            height: settings.collapsedSize

            Wifi {}
        }

        StatusIcon {
            text: tiles.btOn ? "bluetooth" : "bluetooth_disabled"
            active: tiles.btOn
        }

        StatusIcon {
            text: Vpn.connected ? "vpn_key" : "vpn_key_off"
            active: Vpn.connected
        }

        // Die beiden nur, wenn sie wirklich laufen
        StatusIcon {
            text: "coffee"
            active: true
            shown: tiles.noSleep
        }

        StatusIcon {
            text: "sports_esports"
            active: true
            shown: tiles.gameMode
        }

        // Akku zum Schluss – Symbol samt Prozentzahl, deshalb kein StatusIcon
        // (das ist ein reines Symbol). Gibt es keinen Akku, ist die Gruppe
        // null breit und damit ganz weg.
        Row {
            id: battery

            readonly property bool shown: settings.peek && Power.hasBattery && Config.bar.battery
            readonly property bool low: Power.percent <= 20 && !Power.charging

            anchors.verticalCenter: parent.verticalCenter
            width: battery.shown ? implicitWidth + 6 : 0
            visible: width > 0
            opacity: battery.shown ? 1 : 0
            spacing: 3
            clip: true

            Behavior on width {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                // Ohne Systemakku steckt der Akku in einem Geraet – dann sagt
                // das Maus- bzw. Tastatursymbol mehr als ein Akku-Symbol
                text: Power.hasSystemBattery ? Power.batteryIcon : Power.deviceIcon(Power.shown)
                color: battery.low ? Colors.error : Colors.secondary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: `${Power.percent} %`
                color: battery.low ? Colors.error : Colors.fgBackground
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    // VPN-Status unten im Kreis – in der Statuszeile steht er schon
    VpnIcon {
        opacity: settings.expanded || settings.showBrightness || settings.peek ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
        }
        text: "brightness_6"
        color: Brightness.value > 0.5
               ? Colors.fgSurfaceVariant
               : Colors.alpha(Colors.fgSurfaceVariant, 0.45)
        font.pixelSize: 8
        font.family: "Material Symbols Outlined"
        opacity: !settings.expanded && settings.showBrightness ? 1 : 0
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
        opacity: settings.expanded && !settings.wifiOpen && !settings.bluetoothOpen && !settings.audioOpen ? 1 : 0
        visible: opacity > 0

        onOpenWifi: {
            settings.bluetoothOpen = false;
            settings.audioOpen = false;
            settings.wifiOpen = true;
        }
        onOpenBluetooth: {
            settings.wifiOpen = false;
            settings.audioOpen = false;
            settings.bluetoothOpen = true;
        }
        onOpenAudio: {
            settings.wifiOpen = false;
            settings.bluetoothOpen = false;
            settings.audioOpen = true;
        }

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

    BluetoothPanel {
        id: bluetooth

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        active: settings.bluetoothOpen
        opacity: settings.bluetoothOpen ? 1 : 0
        visible: opacity > 0

        onClosed: settings.bluetoothOpen = false

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    AudioPanel {
        id: audio

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        active: settings.audioOpen
        opacity: settings.audioOpen ? 1 : 0
        visible: opacity > 0

        onClosed: settings.audioOpen = false

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    Timer {
        id: closeTimer

        interval: 700
        // Waehrend eines Passworts darf die Maus rausrutschen
        onTriggered: if (!settings.typingPassword && !settings.typingPin)
            settings.expanded = false
    }

    Timer {
        id: brightnessDisplayTimer

        interval: 3000
        onTriggered: settings.showBrightness = false
    }

    Connections {
        target: Brightness

        function onValueChanged(): void {
            if (Brightness.ready && !settings.expanded && !settings.wifiOpen
                    && !settings.bluetoothOpen && !settings.audioOpen) {
                settings.showBrightness = true;
                brightnessDisplayTimer.restart();
            }
        }
    }

    TapHandler {
        enabled: !settings.expanded && !settings.wifiOpen && !settings.bluetoothOpen && !settings.audioOpen
        onTapped: settings.expanded = true
    }

    WheelHandler {
        enabled: !settings.expanded && !settings.wifiOpen && !settings.bluetoothOpen && !settings.audioOpen
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property real acc: 0

        onWheel: event => {
            acc += event.angleDelta.y;
            if (Math.abs(acc) >= 120) {
                Audio.setVolume(Audio.volume + (acc > 0 ? 0.05 : -0.05));
                acc = 0;
            }
            event.accepted = true;
        }
    }

    // Reiner Hover-Sensor, zuletztdeklariert (Muster siehe Notch.qml)
    HoverHandler {
        id: hoverSensor
    }
}
