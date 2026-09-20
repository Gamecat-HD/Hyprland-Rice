pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.modules.services.vpn

import "root:/"

// Kacheln fuer das aufgeklappte Settings-Feld (Vorlage: Control-Center).
// Oben zwei Reihen: [Wi-Fi, Bluetooth] / [VPN, No-Sleep] als Pillen, rechts
// daneben Game-Mode und Nicht-stoeren als Kreise.
//
// Hintergruenge zu den Aktionen:
//   - WLAN/Bluetooth: nmcli bzw. bluetoothctl, Status per Polling
//   - VPN: der bestehende Vpn-Service (nordvpn)
//   - No-Sleep: ein systemd-inhibit-Prozess (logind-Lock), der waehrend der
//     Aktivitaet am Leben gehalten wird
//   - Game-Mode: hyprctl eval 'hl.config{...}' (keyword ist im Lua-Parser
//     tot), Rueckweg ueber hyprctl reload
//   - DND: laeuft hier kein Notification-Daemon (mako/dunst/hypridle: nein),
//     ist der Kippschalter vorerst rein visuell
ColumnLayout {
    id: root

    spacing: 8

    // ---------- Zustaende ----------
    property bool wifiOn: true
    property string wifiStatus: "…"

    property bool btOn: false

    property bool gameMode: false
    property bool dnd: false
    property bool noSleep: false

    Component.onCompleted: {
        wifiPoll.running = true;
        btPoll.running = true;
    }

    // ---------- Aktionen ----------
    function toggleWifi(): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]);
        root.wifiOn = !root.wifiOn;   // optimistisch, der Poll korrigiert
        wifiPoll.running = true;
    }

    function toggleBt(): void {
        Quickshell.execDetached(["bluetoothctl", "power", root.btOn ? "off" : "on"]);
        root.btOn = !root.btOn;
        btPoll.running = true;
    }

    function toggleNoSleep(): void {
        root.noSleep = !root.noSleep;
        inhibitProc.running = root.noSleep;
    }

    function toggleGameMode(): void {
        root.gameMode = !root.gameMode;
        if (root.gameMode) {
            hyprEval('hl.config({ animations = { enabled = false } })');
            hyprEval('hl.config({ decoration = { shadow = { enabled = false } } })');
            hyprEval('hl.config({ decoration = { blur = { enabled = false } } })');
        } else {
            // Reload setzt alles aus dem Profil zurueck (caelestia macht es
            // genauso wie "message reload")
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    function hyprEval(code: string): void {
        evalRunner.command = ["hyprctl", "eval", code];
        evalRunner.running = true;
    }

    // ---------- Prozesse ----------
    Process {
        id: evalRunner
    }

    // WLAN-Funk + Verbindung + Empfang in einem Rutsch
    Process {
        id: wifiPoll

        command: ["sh", "-c",
            "if LC_ALL=C nmcli -t radio wifi | grep -q enabled; then " +
            "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no; " +
            "else echo OFF; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text === "OFF") {
                    root.wifiOn = false;
                    root.wifiStatus = "Aus";
                    return;
                }
                root.wifiOn = true;
                let connected = false;
                for (const line of text.split("\n")) {
                    const f = line.split(":");
                    if (f[0] === "yes") {
                        connected = true;
                        root.wifiStatus = f[1] + " · " + (f[2] ?? "0") + "%";
                        break;
                    }
                }
                if (!connected)
                    root.wifiStatus = "Getrennt";
            }
        }
    }

    Process {
        id: btPoll

        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]

        stdout: StdioCollector {
            onStreamFinished: root.btOn = this.text.trim() === "on"
        }
    }

    // Haltet den Schlaf wach: solange dieser Prozess laeuft, haelt er einen
    // logind-Inhibitor gegen idle/suspend
    Process {
        id: inhibitProc

        command: ["systemd-inhibit", "--what=idle:sleep", "--who=dynamic-island",
                  "--mode=block", "sleep", "infinity"]
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            wifiPoll.running = true;
            btPoll.running = true;
        }
    }

    // ---------- Kacheln ----------
    component Tile: Rectangle {
        id: tile

        property string icon
        property string title
        property string subtitle
        property bool active
        signal toggled()

        Layout.fillWidth: true
        implicitHeight: 46
        radius: height / 2
        color: Colors.shade(Colors.background, 0.05)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: tile.active ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Text {
                    anchors.centerIn: parent

                    text: tile.icon
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 16
                    color: tile.active ? Colors.fgPrimary : Colors.fgSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: tile.title
                    color: Colors.fgBackground
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: tile.subtitle
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        TapHandler {
            onTapped: tile.toggled()
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    component CircleToggle: Rectangle {
        id: circle

        property string icon
        property bool active
        signal toggled()

        Layout.preferredWidth: 46
        Layout.preferredHeight: 46
        radius: 23
        color: circle.active ? Colors.primary : Colors.shade(Colors.background, 0.05)

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        Text {
            anchors.centerIn: parent

            text: circle.icon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: circle.active ? Colors.fgPrimary : Colors.fgSurfaceVariant
        }

        TapHandler {
            onTapped: circle.toggled()
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Tile {
            icon: root.wifiOn ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            subtitle: root.wifiStatus
            active: root.wifiOn
            onToggled: root.toggleWifi()
        }

        Tile {
            icon: root.btOn ? "bluetooth" : "bluetooth_disabled"
            title: "Bluetooth"
            subtitle: root.btOn ? "An" : "Aus"
            active: root.btOn
            onToggled: root.toggleBt()
        }

        CircleToggle {
            icon: "sports_esports"
            active: root.gameMode
            onToggled: root.toggleGameMode()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Tile {
            icon: Vpn.connected ? "vpn_key" : "vpn_key_off"
            title: "VPN"
            subtitle: Vpn.connected ? "Verbunden" : "Getrennt"
            active: Vpn.connected
            onToggled: Vpn.toggle()
        }

        Tile {
            icon: "coffee"
            title: "No Sleep"
            subtitle: root.noSleep ? "Aktiv" : "Aus"
            active: root.noSleep
            onToggled: root.toggleNoSleep()
        }

        CircleToggle {
            icon: root.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
            active: root.dnd
            onToggled: root.dnd = !root.dnd   // kein Daemon vorhanden -> visuell
        }
    }
}
