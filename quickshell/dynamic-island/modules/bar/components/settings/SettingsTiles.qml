pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.modules.services.audio
import qs.modules.services.brightness
import qs.modules.services.vpn

import "root:/modules/settings"

import "root:/"

// Kacheln fuer das aufgeklappte Settings-Feld (Vorlage: Control-Center).
// Zwei Reihen: [Wi-Fi, Bluetooth] / [VPN, No-Sleep] als Pillen, rechts
// daneben Game-Mode und Nicht-stoeren als Kreise. Die No-Sleep-Pille traegt
// einen Dauer-Dropdown (Standard: nichts gewaehlt = unbegrenzt); das Menue
// haengt aus der Karte heraus, Bar.qml haelt es in der Eingabe-Maske offen
// und Settings.zaehlt seinen Hover zur Karte dazu.
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

    spacing: 10

    // Der Pfeil auf der Wi-Fi-Pille fuehrt in die Netzliste; die Karte
    // (Settings.qml) schaltet daraufhin ihre Ansicht um.
    signal openWifi()

    // ---------- Zustaende ----------
    property bool wifiOn: true
    property string wifiStatus: "…"

    property bool btOn: false

    property bool gameMode: false
    property bool noSleep: false

    // Gewaehlte Dauer in Sekunden; -1 = nichts gewaehlt (Standard),
    // 0 = unbegrenzt. sleepRemaining ist die Restlaufzeit in Sekunden.
    property int sleepDurationSec: -1
    property int sleepRemaining: 0

    // Dropdown-Zustand der No-Sleep-Pille (das Menue haengt aus der Karte
    // heraus und wird ueber Settings/Bar in die Eingabe-Maske gehaengt)
    property bool sleepMenuOpen: false
    readonly property alias sleepMenu: sleepMenuPanel
    // Maus ueber dem herausragenden Menue – Settings muss das kennen, sonst
    // klappt die Karte unter der Maus zu, sobald man ins Menue faehrt
    readonly property alias sleepMenuHovered: sleepMenuHover.hovered

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
        if (root.noSleep) {
            root.sleepRemaining = Math.max(0, root.sleepDurationSec);
            inhibitProc.running = true;
        } else {
            root.sleepRemaining = 0;
            inhibitProc.running = false;
        }
    }

    function pickDuration(sec: int): void {
        root.sleepDurationSec = sec;
        root.sleepMenuOpen = false;
        if (!root.noSleep) {
            root.noSleep = true;   // Auswahl aktiviert direkt mit
            root.sleepRemaining = Math.max(0, sec);
            inhibitProc.running = true;
        } else if (sec > 0) {
            root.sleepRemaining = sec;   // laufende Session umstellen
        }
    }

    function durationLabel(sec: int): string {
        if (sec === 1800)
            return "30m";
        if (sec === 3600)
            return "1h";
        if (sec === 14400)
            return "4h";
        if (sec === 0)
            return "∞";
        return "–";
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

    function fmtRemaining(sec: int): string {
        if (sec >= 3600) {
            const h = Math.floor(sec / 3600);
            const m = Math.round((sec % 3600) / 60);
            return m > 0 ? h + " h " + m + " min" : h + " h";
        }
        return Math.max(1, Math.round(sec / 60)) + " min";
    }

    // ---------- Prozesse ----------
    Process {
        id: evalRunner
    }

    // WLAN-Funk + Verbindung + Empfang in einem Rutsch
    Process {
        id: wifiPoll

        // LC_ALL=C fuer den GANZEN Aufruf: nmcli uebersetzt das Feld ACTIVE
        // (auf Deutsch "ja"/"nein"), der Vergleich unten auf "yes" ging sonst
        // nie auf – die Kachel schrieb immer "Getrennt".
        command: ["sh", "-c",
            "export LC_ALL=C; if nmcli -t radio wifi | grep -q enabled; then " +
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

    // Countdown: bei Ablauf No-Sleep sauber abschalten (ohne Dauer keiner)
    Timer {
        interval: 1000
        running: root.noSleep && root.sleepDurationSec > 0
        repeat: true
        onTriggered: {
            root.sleepRemaining = root.sleepRemaining - 1;
            if (root.sleepRemaining <= 0) {
                root.noSleep = false;
                inhibitProc.running = false;
            }
        }
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

        // false = die Kachel togglet nicht selbst (No-Sleep hat einen
        // eigenen Guard, damit Dropdown-Klicks nicht doppelt ausloesen)
        property bool tapEnabled: true
        signal toggled()

        Layout.fillWidth: true
        implicitHeight: 54
        radius: height / 2
        color: Colors.shade(Colors.background, 0.05)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: tile.active ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Text {
                    anchors.centerIn: parent

                    text: tile.icon
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 19
                    color: tile.active ? Colors.fgPrimary : Colors.fgSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: tile.title
                    color: Colors.fgBackground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: tile.subtitle
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        TapHandler {
            enabled: tile.tapEnabled
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

        Layout.preferredWidth: 54
        Layout.preferredHeight: 54
        radius: 27
        color: circle.active ? Colors.primary : Colors.shade(Colors.background, 0.05)

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        Text {
            anchors.centerIn: parent

            text: circle.icon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 24
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
        spacing: 10

        Tile {
            id: wifiTile

            tapEnabled: false   // Toggle macht der bewachte TapHandler unten

            icon: root.wifiOn ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            subtitle: root.wifiStatus
            active: root.wifiOn
            onToggled: root.toggleWifi()

            // Links schaltet den Funk, rechts fuehrt der Pfeil in die Liste
            // (dasselbe Muster wie bei der No-Sleep-Pille)
            TapHandler {
                id: wifiTap

                onTapped: {
                    if (wifiTap.point.position.x < wifiTile.width - 46)
                        root.toggleWifi();
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 34
                height: 34
                radius: height / 2
                color: wifiMore.containsMouse ? Colors.alpha(Colors.fgSurface, 0.16)
                                              : Colors.alpha(Colors.fgSurface, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent

                    text: "chevron_right"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 18
                    color: Colors.fgBackground
                }

                MouseArea {
                    id: wifiMore

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWifi()
                }
            }
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
        id: lowerTileRow

        Layout.fillWidth: true
        spacing: 10
        z: root.sleepMenuOpen ? 100 : 0

        Tile {
            icon: Vpn.connected ? "vpn_key" : "vpn_key_off"
            title: "VPN"
            subtitle: Vpn.connected ? "Verbunden" : "Getrennt"
            active: Vpn.connected
            onToggled: Vpn.toggle()
        }

        // No-Sleep mit integriertem Dauer-Dropdown. Der Klick auf die Pille
        // toggelt; ohne gewaehlte Dauer laeuft sie unbegrenzt. Taps auf den
        // Dropdown selbst feuern NICHT den Pillen-Toggle (x-Grenze unten).
        Tile {
            id: noSleepTile

            tapEnabled: false   // Toggle macht der bewachte TapHandler unten

            icon: "coffee"
            title: "No Sleep"
            subtitle: !root.noSleep ? "Aus"
                     : root.sleepDurationSec === -1 ? "Aktiv (unbegrenzt)"
                     : root.sleepDurationSec === 0 ? "Unendlich"
                     : "Noch " + root.fmtRemaining(root.sleepRemaining)
            active: root.noSleep
            onToggled: root.toggleNoSleep()

            TapHandler {
                id: pillTap

                // Taps im Dropdown-Bereich (rechts) gehoeren dem Dropdown
                onTapped: {
                    if (pillTap.point.position.x < noSleepTile.width - 96)
                        root.toggleNoSleep();
                }
            }

            // Dropdown-Knopf: zeigt "–", solange keine Dauer gewaehlt ist
            Rectangle {
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                implicitWidth: dropdownLabel.implicitWidth + arrow.implicitWidth + 22
                implicitHeight: 34
                radius: 17
                color: root.sleepMenuOpen ? Colors.alpha(Colors.fgSurface, 0.12) : Colors.alpha(Colors.fgSurface, 0.08)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        id: dropdownLabel

                        text: root.durationLabel(root.sleepDurationSec)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Colors.fgBackground
                    }

                    Text {
                        id: arrow

                        text: root.sleepMenuOpen ? "expand_less" : "expand_more"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: Colors.fgSurfaceVariant
                    }
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds   // exklusiv: kein Pillen-Toggle
                    onTapped: root.sleepMenuOpen = !root.sleepMenuOpen
                }
            }

            // Das Menue haengt schmal unter dem Dropdown-Knopf und ragt aus
            // der Karte heraus – Bar.qml haengt es in die Eingabe-Maske
            Rectangle {
                id: sleepMenuPanel

                visible: root.sleepMenuOpen
                anchors {
                    top: parent.bottom
                    topMargin: 4
                    right: parent.right
                    rightMargin: 10
                }
                width: 150
                implicitHeight: 140
                radius: 16
                color: Colors.shade(Colors.background, 0.08)
                border.width: 1
                border.color: Colors.outlineVariant

                HoverHandler {
                    id: sleepMenuHover
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    Repeater {
                        model: [
                            { label: "30m", sec: 1800 },
                            { label: "1h", sec: 3600 },
                            { label: "4h", sec: 14400 },
                            { label: "---", sec: 0 }
                        ]

                        Rectangle {
                            id: option

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 15
                            color: root.sleepDurationSec === option.modelData.sec ? Colors.primary : "transparent"
                            border.width: 1
                            border.color: optionHover.hovered
                                          ? Colors.alpha(Colors.fgSurfaceVariant, 0.55)
                                          : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            Behavior on border.color {
                                ColorAnimation { duration: 100 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 6

                                Text {
                                    text: option.modelData.label
                                    font.pixelSize: 12
                                    color: root.sleepDurationSec === option.modelData.sec ? Colors.fgPrimary : Colors.fgBackground
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "check"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    visible: root.sleepDurationSec === option.modelData.sec
                                    color: Colors.fgPrimary
                                }
                            }

                            TapHandler {
                                onTapped: root.pickDuration(option.modelData.sec)
                            }

                            HoverHandler {
                                id: optionHover
                            }
                        }
                    }
                }
            }
        }

        // Frueher "Nicht stoeren" (rein visuell, es gab keinen Daemon).
        // Der Schalter steht jetzt im Einstellungs-Fenster, das dieser Kreis
        // oeffnet – dort wirkt er auch wirklich.
        CircleToggle {
            icon: "tune"
            active: SettingsState.open
            onToggled: SettingsState.toggleOnFocused()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        LevelSlider {
            Layout.fillWidth: true
            title: "Lautstärke"
            icon: Audio.muted ? "volume_off"
                               : Audio.volume >= 0.5 ? "volume_up" : "volume_down"
            value: Audio.volume
            accent: Audio.muted ? Colors.error : Colors.primary
            foreground: Audio.muted ? Colors.fgError : Colors.fgPrimary
            onAdjusted: value => Audio.setVolume(value)
        }

        LevelSlider {
            Layout.fillWidth: true
            title: "Helligkeit"
            icon: "brightness_6"
            value: Brightness.value
            accent: Brightness.value > 0.5
                    ? Colors.alpha(Colors.primary, 0.78) : Colors.primaryDim
            foreground: Brightness.value > 0.5 ? Colors.fgPrimary : Colors.fgBackground
            enabled: Brightness.ready
            opacity: enabled ? 1 : 0.5
            onAdjusted: value => Brightness.setValue(value)
        }
    }
}
