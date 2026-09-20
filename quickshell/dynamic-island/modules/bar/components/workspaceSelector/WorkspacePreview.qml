pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "root:/"

// Vorschau-Popup unter einem Workspace-Punkt.
//
// Zeigt den Workspace als verkleinerten Monitor: jedes Fenster sitzt an seiner
// echten Position und zeigt ein Live-Bild. Das geht auch fuer Workspaces, die
// gerade auf keinem Monitor liegen – Hyprlands toplevel-export rendert die
// Fenster dafuer eigens, ScreencopyView greift genau das ab (nachgemessen an
// btop auf special:sysmon, waehrend der Workspace versteckt war).
//
// Erzeugt wird das Popup vom Punkt selbst per Loader, erst nach kurzem
// Verweilen – so laufen nie mehrere Captures gleichzeitig.
PopupWindow {
    id: preview

    required property Item anchorItem
    required property int ws
    required property ShellScreen screen

    // Monitor, auf dem dieser Workspace liegt (fuer Groesse und Ursprung der
    // Fensterkoordinaten – Hyprland liefert `at` in globalen Layout-Pixeln).
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(preview.screen)
    readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === preview.ws) ?? null
    readonly property var windows: preview.workspace?.toplevels.values ?? []

    readonly property real contentWidth: 260
    readonly property real padding: 8
    readonly property real factor: preview.contentWidth / preview.screen.width

    anchor {
        item: preview.anchorItem
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.top: 6
    }

    implicitWidth: preview.contentWidth + preview.padding * 2
    implicitHeight: preview.screen.height * preview.factor + preview.padding * 2
    color: "transparent"

    // Die Geometrie der Fenster steht in `lastIpcObject` und ist erst nach
    // einem Refresh gefuellt – ohne den sind `at`/`size` undefined.
    Component.onCompleted: Hyprland.refreshToplevels()

    Rectangle {
        anchors.fill: parent

        radius: 12
        color: Colors.background
        border.width: 1
        border.color: Colors.outlineVariant

        // Die Monitorflaeche selbst – dunkler Grund, damit leere Bereiche
        // nicht wie ein Loch in der Karte aussehen.
        Rectangle {
            id: canvas

            anchors.fill: parent
            anchors.margins: preview.padding

            radius: 6
            color: Colors.surface
            clip: true

            Repeater {
                model: preview.windows

                delegate: Item {
                    id: win

                    required property var modelData

                    readonly property var geo: win.modelData?.lastIpcObject ?? null
                    readonly property bool placed: !!(win.geo?.at && win.geo?.size)

                    visible: win.placed

                    x: win.placed ? (win.geo.at[0] - preview.monitor.x) * preview.factor : 0
                    y: win.placed ? (win.geo.at[1] - preview.monitor.y) * preview.factor : 0
                    width: win.placed ? win.geo.size[0] * preview.factor : 0
                    height: win.placed ? win.geo.size[1] * preview.factor : 0

                    Rectangle {
                        anchors.fill: parent

                        radius: 3
                        color: Colors.surfaceContainer
                        border.width: 1
                        border.color: Colors.alpha(Colors.outline, 0.6)
                        clip: true

                        // Fenster mit eigener Transparenz (kitty!) bringen ihren
                        // Alpha-Kanal im Capture mit. Ohne eigene Ebene schreibt
                        // ScreencopyView den direkt in die Popup-Flaeche – dann
                        // stanzt die Vorschau ein Loch bis auf den Desktop
                        // durch. Mit layer.enabled wird sie erst in eine Textur
                        // gerendert und dann normal ueber diesen Grund geblendet.
                        layer.enabled: true

                        // constraintSize statt anchors.fill: ScreencopyView
                        // skaliert sein Bild auf diese Vorgabe. Ohne sie
                        // zeichnet es das Fenster in Originalgroesse und man
                        // sieht nur einen 1:1-Ausschnitt der linken oberen Ecke.
                        ScreencopyView {
                            id: capture

                            anchors.centerIn: parent

                            captureSource: win.modelData.wayland ?? null
                            constraintSize.width: win.width
                            constraintSize.height: win.height

                            // Sparsam: KEIN Dauerstrom. Der Capture laeuft nur,
                            // bis das erste Bild da ist, danach steht er still.
                            // (`captureFrame()` direkt aufzurufen geht nicht –
                            // der Aufnahme-Kontext ist beim Erzeugen noch nicht
                            // bereit: "no recording context is ready".)
                            // Die Vorschau ist ohnehin nur so lange da, wie der
                            // Zeiger auf dem Punkt steht.
                            live: true

                            onHasContentChanged: if (capture.hasContent) capture.live = false

                        }
                    }
                }
            }

            // Leerer Workspace: kein schwarzes Rechteck, sondern ein Hinweis
            Text {
                anchors.centerIn: parent
                visible: preview.windows.length === 0

                text: "leer"
                color: Colors.fgSurfaceVariant
                font.pixelSize: 11
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }
        }
    }
}
