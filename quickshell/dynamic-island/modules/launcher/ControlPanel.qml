pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray

import qs
import qs.modules.bar.components.settings
import qs.modules.bar.components.statusBar
import qs.modules.services.network

// Untermenue "Steuerung" der Notch: Tray-Icons und die Schnell-Kacheln der
// Settings-Karte (WLAN, Bluetooth, VPN, Audio-Geraete, Helligkeit ...).
// Beides sind eigene, eingebettete Instanzen (`embedded: true`) – die Pillen
// der Leiste bleiben fuer das Insel-Layout unangetastet.
// Aufruf: SUPER+A, `>steuerung`, Blaettern.
ViewPanel {
    id: root

    // Fuer Bar.qml: Tastaturfokus beim WLAN-Passwort/BT-PIN, Pairing-Anfragen
    readonly property alias settings: embeddedSettings
    readonly property bool typing: embeddedSettings.typingPassword || embeddedSettings.typingPin
    readonly property bool hasTray: SystemTray.items.values.length > 0
    readonly property real trayHeight: root.hasTray ? 40 : 0

    title: "Steuerung"
    icon: "toggle_on"
    contentWidth: embeddedSettings.expandedWidth
    contentHeight: root.trayHeight + embeddedSettings.height + embeddedSettings.dropdownReserve
    maxContentHeight: root.trayHeight + embeddedSettings.maxHeight

    // Unterseiten zuruecksetzen, wenn die Ansicht geht. Beim Oeffnen schon
    // mal die WLAN-Liste aus dem Cache holen (~60 ms) – klappt man die
    // WLAN-Seite auf, steht sie dann sofort da.
    onActiveChanged: if (active) {
        Network.refresh(false);
    } else {
        embeddedSettings.wifiOpen = false;
        embeddedSettings.bluetoothOpen = false;
        embeddedSettings.audioOpen = false;
    }

    Item {
        id: trayBox

        width: parent.width
        height: root.trayHeight
        visible: root.hasTray

        StatusBar {
            embedded: true
            verticalMargin: 10
        }
    }

    Item {
        y: root.trayHeight
        width: parent.width
        height: embeddedSettings.height

        Settings {
            id: embeddedSettings

            embedded: true
            expanded: true
            verticalMargin: 0
            cardRadius: root.cardRadius
            borderWidth: 0
        }
    }
}
