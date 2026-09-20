pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.services.network

import "root:/"

// WLAN-Ansicht der Settings-Karte: Liste der Netze, verbinden, Passwort
// aendern, vergessen. Die Karte zeigt entweder die Kacheln oder das hier
// (siehe Settings.qml); die Daten kommen aus dem Network-Dienst.
Item {
    id: panel

    property bool active: false
    signal closed()

    // Welche Zeile ihr Menue bzw. ihr Passwortfeld offen hat (SSID oder "")
    property string menuSsid: ""
    property string passwordSsid: ""

    readonly property real rowHeight: 50
    // Feste Hoehe statt "so hoch wie der Inhalt": waehrend des ersten Scans
    // ist die Liste leer, die Karte waere winzig – und wer die Maus dorthin
    // bewegt, wo die Liste gleich auftaucht, waere schon draussen und haette
    // sie wieder zugeklappt.
    readonly property real listHeight: 268

    implicitHeight: header.height + 6 + listWrapper.height + (statusText.visible ? statusText.height + 6 : 0)

    onActiveChanged: {
        panel.menuSsid = "";
        panel.passwordSsid = "";
        Network.watching = active;
        if (active)
            Network.refresh(true);
    }

    // Knopf im Aktions-Menue einer Zeile. Inline-Komponenten muessen auf
    // der obersten Ebene der Datei stehen – steckte sie (wie zuerst) im
    // Flow, legt Qt sie stillschweigend nicht an und das Menue blieb leer.
    component Action: Rectangle {
        id: chip

        property string icon
        property string label
        property bool danger: false
        signal triggered()

        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 30
        radius: height / 2
        color: chipArea.containsMouse ? Colors.alpha(chip.danger ? Colors.error : Colors.fgSurface, 0.16)
                                      : Colors.shade(Colors.background, 0.08)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.family: "Material Symbols Outlined"
                font.pixelSize: 14
                color: chip.danger ? Colors.error : Colors.fgSurfaceVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.pixelSize: 11
                color: chip.danger ? Colors.error : Colors.fgBackground
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.triggered()
        }
    }

    function rowTapped(net: var): void {
        if (net.active) {
            // Verbundenes Netz: nur das Menue, Trennen ist eine bewusste Geste
            panel.toggleMenu(net.ssid);
        } else if (net.saved) {
            Network.connect(net, "");
        } else if (net.secured) {
            panel.passwordSsid = panel.passwordSsid === net.ssid ? "" : net.ssid;
            panel.menuSsid = "";
        } else {
            Network.connect(net, "");
        }
    }

    function toggleMenu(ssid: string): void {
        panel.menuSsid = panel.menuSsid === ssid ? "" : ssid;
        panel.passwordSsid = "";
    }

    // ---- Kopfzeile ----
    Item {
        id: header

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 36

        Rectangle {
            id: backButton

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 30
            height: 30
            radius: height / 2
            color: backArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.1) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "chevron_left"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: Colors.fgBackground
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.closed()
            }
        }

        Text {
            anchors {
                left: backButton.right
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: "WLAN"
            color: Colors.fgBackground
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: rescanButton

            anchors {
                right: radioToggle.left
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 30
            height: 30
            radius: height / 2
            color: rescanArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.1) : "transparent"
            opacity: Network.radioOn ? 1 : 0.4

            Text {
                id: rescanIcon

                anchors.centerIn: parent
                text: "refresh"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
                color: Colors.fgSurfaceVariant

                RotationAnimator {
                    target: rescanIcon
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: Network.busy
                    onRunningChanged: if (!running)
                        rescanIcon.rotation = 0
                }
            }

            MouseArea {
                id: rescanArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: Network.radioOn
                onClicked: Network.refresh(true)
            }
        }

        // Funk an/aus als Schiebeschalter
        Rectangle {
            id: radioToggle

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 40
            height: 22
            radius: height / 2
            color: Network.radioOn ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.18)

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: Network.radioOn ? parent.width - width - 3 : 3
                color: Network.radioOn ? Colors.fgPrimary : Colors.fgSurfaceVariant

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Network.setRadio(!Network.radioOn)
            }
        }
    }

    // ---- Meldung ----
    Text {
        id: statusText

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
        }
        text: Network.status
        visible: text !== ""
        color: text.startsWith("Error") || text.indexOf("Fehl") >= 0 ? Colors.error : Colors.fgSurfaceVariant
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    // ---- Liste ----
    Item {
        id: listWrapper

        anchors {
            top: statusText.visible ? statusText.bottom : header.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
        }
        height: panel.listHeight

        ListView {
            id: list

            anchors.fill: parent
            clip: true
            spacing: 4
            model: Network.radioOn ? Network.networks : []
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    const angle = event.angleDelta.y + event.angleDelta.x;
                    const pixels = event.pixelDelta.y + event.pixelDelta.x;
                    const delta = angle !== 0 ? angle / 120 : pixels / 40;

                    const max = Math.max(0, list.contentHeight - list.height);
                    list.contentY = Math.max(0, Math.min(max, list.contentY - delta * panel.rowHeight));
                    event.accepted = true;
                }
            }

            delegate: Column {
                id: row

                required property var modelData

                readonly property bool menuOpen: panel.menuSsid === row.modelData.ssid
                readonly property bool passwordOpen: panel.passwordSsid === row.modelData.ssid

                width: ListView.view.width
                spacing: 4

                // Zeile selbst
                Rectangle {
                    width: parent.width
                    height: panel.rowHeight
                    radius: 14
                    color: row.modelData.active ? Colors.alpha(Colors.primary, 0.16)
                         : rowArea.containsMouse ? Colors.shade(Colors.background, 0.08)
                         : Colors.shade(Colors.background, 0.05)

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.rowTapped(row.modelData)
                    }

                    Text {
                        id: signalIcon

                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: Network.signalIcon(row.modelData)
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 20
                        color: row.modelData.active ? Colors.primary : Colors.fgSurfaceVariant
                    }

                    Column {
                        anchors {
                            left: signalIcon.right
                            leftMargin: 12
                            right: menuButton.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 1

                        Text {
                            width: parent.width
                            text: row.modelData.ssid
                            color: Colors.fgBackground
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: {
                                const net = row.modelData;
                                const parts = [];
                                if (net.active)
                                    parts.push("Verbunden");
                                else if (net.saved)
                                    parts.push("Gespeichert");
                                if (!net.inRange)
                                    parts.push("nicht in Reichweite");
                                else
                                    parts.push(`${net.signal}%`);
                                if (net.duplicate)
                                    parts.push(`${net.profiles.length} Profile`);
                                return parts.join(" · ");
                            }
                            color: row.modelData.duplicate ? Colors.error : Colors.fgSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors {
                            right: menuButton.left
                            rightMargin: 2
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.secured ? "lock" : "lock_open"
                        visible: row.modelData.inRange
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 14
                        color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                    }

                    Rectangle {
                        id: menuButton

                        anchors {
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        width: 28
                        height: 28
                        radius: height / 2
                        color: row.menuOpen ? Colors.alpha(Colors.fgSurface, 0.14)
                             : menuArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.1)
                             : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "more_vert"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: Colors.fgSurfaceVariant
                        }

                        MouseArea {
                            id: menuArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.toggleMenu(row.modelData.ssid)
                        }
                    }
                }

                // Passwortfeld
                Rectangle {
                    width: parent.width
                    height: row.passwordOpen ? 42 : 0
                    visible: height > 0
                    radius: 14
                    color: Colors.shade(Colors.background, 0.08)
                    clip: true

                    onVisibleChanged: if (visible)
                        password.forceActiveFocus()

                    Text {
                        id: keyIcon

                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: "key"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 16
                        color: Colors.fgSurfaceVariant
                    }

                    TextInput {
                        id: password

                        anchors {
                            left: keyIcon.right
                            leftMargin: 10
                            right: connectButton.left
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        echoMode: TextInput.Password
                        color: Colors.fgBackground
                        font.pixelSize: 12
                        selectionColor: Colors.alpha(Colors.primary, 0.35)
                        clip: true

                        Keys.onEscapePressed: panel.passwordSsid = ""
                        Keys.onReturnPressed: connectButton.submit()
                        Keys.onEnterPressed: connectButton.submit()

                        Text {
                            anchors.fill: parent
                            visible: password.text === ""
                            text: "Passwort"
                            color: Colors.alpha(Colors.fgSurfaceVariant, 0.7)
                            font: password.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        id: connectButton

                        function submit(): void {
                            if (password.text === "")
                                return;
                            Network.connect(row.modelData, password.text);
                            password.text = "";
                            panel.passwordSsid = "";
                        }

                        anchors {
                            right: parent.right
                            rightMargin: 6
                            verticalCenter: parent.verticalCenter
                        }
                        width: 88
                        height: 30
                        radius: height / 2
                        color: password.text === "" ? Colors.alpha(Colors.fgSurface, 0.1) : Colors.primary

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Verbinden"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: password.text === "" ? Colors.fgSurfaceVariant : Colors.fgPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectButton.submit()
                        }
                    }
                }

                // Aktionen
                Flow {
                    width: parent.width
                    height: row.menuOpen ? implicitHeight : 0
                    visible: height > 0
                    spacing: 6

                    Action {
                        visible: row.modelData.active
                        icon: "link_off"
                        label: "Trennen"
                        onTriggered: {
                            Network.disconnect(row.modelData);
                            panel.menuSsid = "";
                        }
                    }

                    Action {
                        visible: !row.modelData.active && row.modelData.saved && row.modelData.inRange
                        icon: "wifi"
                        label: "Verbinden"
                        onTriggered: {
                            Network.connect(row.modelData, "");
                            panel.menuSsid = "";
                        }
                    }

                    Action {
                        visible: row.modelData.saved && row.modelData.secured
                        icon: "key"
                        label: "Passwort ändern"
                        onTriggered: {
                            panel.menuSsid = "";
                            panel.passwordSsid = row.modelData.ssid;
                        }
                    }

                    // Der eigentliche Grund fuer diese Ansicht: mehrere Profile
                    // auf denselben SSID. Weg mit denen, die nie funktioniert
                    // haben – das benutzte bleibt.
                    Action {
                        visible: row.modelData.duplicate && row.modelData.stale.length > 0
                        icon: "cleaning_services"
                        label: `${row.modelData.stale.length} doppeltes Profil entfernen`
                        onTriggered: {
                            Network.dropStale(row.modelData);
                            panel.menuSsid = "";
                        }
                    }

                    Action {
                        visible: row.modelData.saved
                        icon: "delete"
                        label: "Vergessen"
                        danger: true
                        onTriggered: {
                            Network.forget(row.modelData);
                            panel.menuSsid = "";
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Network.radioOn ? (Network.loaded ? "Keine Netze gefunden" : "Suche…") : "WLAN ist aus"
            color: Colors.fgSurfaceVariant
            font.pixelSize: 12
        }
    }
}
