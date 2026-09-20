pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import qs.modules.services.hypr

import "root:/"

// Karte links in der Leiste. Rundung, Randstärke und Randfarbe kommen aus
// Bar.qml, damit sie sich nichts mit der Notch ausdenken muss.
// Die Punkte selbst stecken in Workspace.qml; hier wird nur einmal der
// Zustand ermittelt und an alle durchgereicht.
Item {
    id: root
    anchors {
        left: parent.left
        leftMargin: HyprGaps.left
    }

    required property real verticalMargin // margin über bzw unter der notch
    required property real borderWidth   // von außen überschreibbar (Bar.qml macht das)
    required property color borderColor
    required property real cardRadius
    // Luft zwischen Punktreihe und Kartenrand (je Seite). Die Punkte bringen
    // selbst schon 6px Trefferrand mit, deshalb hier 14 statt 20.
    property real padding: 14

    // Größe einer Monitor-Gruppe. `wsMonitorOffset` in der Hypr-Config vergibt
    // je 10 am Stück (HDMI-A-1 ab 1, DP-1 ab 11).
    property int workspacesPerMonitor: 5

    // Der Monitor, auf dem DIESE Leiste sitzt – bewusst nicht der fokussierte.
    // Sonst zeigten beide Leisten dieselbe Gruppe an.
    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(root.QsWindow.window?.screen ?? null)
    readonly property int activeWsId: root.hyprMonitor?.activeWorkspace?.id ?? 1

    // Welche 10er-Gruppe gehört zu diesem Monitor: 0 bei ws 1-10, 10 bei 11-20
    readonly property int groupOffset: Math.floor((root.activeWsId - 1) / root.workspacesPerMonitor) * root.workspacesPerMonitor

    // { wsId: hatFenster } – einmal gebaut statt zehnmal pro Punkt gefiltert
    readonly property var occupied: {
        const occ = {};
        for (const ws of Hyprland.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }

    // Breite kommt von innen: das RowLayout rechnet sie aus seinen Punkten,
    // die Karte fuellt root. Andersherum (root von der Karte) waere es eine
    // Binding-Schleife.
    implicitWidth: layout.implicitWidth + root.padding * 2
    height: parent.height - verticalMargin
    y: verticalMargin / 2

    Rectangle {
        id: card
        anchors.fill: parent

        // Bei flacher Karte greift die halbe Breite, sonst bliebe die Rundung
        // an den kurzen Kanten hängen – dasselbe Muster wie in der Notch.
        radius: Math.min(width / 2, root.cardRadius)
        border.width: root.borderWidth
        border.color: root.borderColor
        color: Colors.background

        // Scrollen schaltet Workspaces. Touchpads/Hi-Res-Räder liefern viele
        // kleine Events pro Zug, oft mit angleDelta.y == 0 (nur pixelDelta
        // gefuellt) – deshalb nicht blind aufs Vorzeichen gehen, sondern
        // ansummern und pro Rasterung (120) genau einmal schalten.
        WheelHandler {
            id: wheel

            parent: card
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            property real acc: 0

            onWheel: event => {
                wheel.acc += event.angleDelta.y;
                if (Math.abs(wheel.acc) < 120)
                    return;

                const dir = wheel.acc > 0 ? "m-1" : "m+1";
                wheel.acc = 0;
                Hyprland.dispatch(`hl.dsp.focus({ workspace = "${dir}" })`);
            }
        }

        RowLayout {
            id: layout
            anchors.centerIn: parent

            // 0, weil der Abstand aus dem hitPadding der Punkte kommt –
            // so grenzen die Klickzonen lückenlos aneinander.
            spacing: 0

            Repeater {
                id: workspaces

                model: root.workspacesPerMonitor

                Workspace {
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                }
            }
        }
    }
}
