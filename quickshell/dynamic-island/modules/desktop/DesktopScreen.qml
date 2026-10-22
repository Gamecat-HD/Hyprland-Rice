pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import qs
import qs.modules.services.config
import qs.modules.services.desktop
import qs.modules.services.hypr
import qs.modules.services.system

// Die Widget-Ebene eines Monitors.
//
// Normal: Layer "bottom" (ueber dem Wallpaper, unter allen Fenstern), ohne
// Eingabe (leere Maske – Klicks gehen auf den Desktop durch), ohne Tastatur.
// Bearbeiten: auf dem Monitor, auf dem es gestartet wurde, rutscht die Ebene
// nach "top" (ueber die Fenster), nimmt Maus und Tastatur und zeigt die
// Bearbeitungsleiste (EditBar.qml).
//
// Pausieren: sieht man den Desktop nicht (Fenster auf dem Workspace bzw. nur
// bei Vollbild, Einstellung desktop.pause; Game-Mode immer), bekommen alle
// Widgets `active: false` – Cava-/Songtext-Bedarf faellt weg, Timer stehen,
// externe Programme werden angehalten. So kosten Widgets beim Arbeiten und
// Spielen nichts.
PanelWindow {
    id: win

    required property ShellScreen modelData

    readonly property string screenName: win.modelData.name
    readonly property bool editingHere: Scenes.editing && Scenes.editScreen === win.screenName
    // Grundeinheit: 16 px bei 1440p
    readonly property real unit: 16 * win.modelData.height / 1440

    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(win.modelData)
    readonly property HyprlandWorkspace workspace: win.hyprMonitor?.activeWorkspace ?? null
    readonly property bool hasWindows: HyprIpc.windowsOn(win.workspace) > 0
                                       || HyprIpc.specialOn(win.hyprMonitor) !== ""
    readonly property bool fullscreen: win.workspace?.lastIpcObject?.hasfullscreen ?? false
    readonly property bool covered: SessionModes.gameMode || win.fullscreen
                                    || (Config.desktop.pause === "fenster" && win.hasWindows)
    readonly property bool active: Scenes.editing || !win.covered

    screen: win.modelData
    WlrLayershell.layer: win.editingHere ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "dynamic-island-desktop"
    WlrLayershell.keyboardFocus: win.editingHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    // Leere Maske = keine Eingabe; beim Bearbeiten das ganze Fenster
    mask: win.editingHere ? null : noInput

    Region {
        id: noInput
    }

    // Ohne Widgets und ausserhalb der Bearbeitung bleibt die Flaeche leer –
    // es wird nichts gezeichnet ausser dem ersten, durchsichtigen Frame
    Item {
        id: stage

        anchors.fill: parent
        focus: win.editingHere

        // Ausgewaehltes Widget (setzt WidgetHost) – fuer "Klick ins Leere"
        property Item selectedHost: null

        // Esc: erst Auswahl weg, dann Abbrechen (alles zurueck). Enter: Fertig.
        Keys.onPressed: event => {
            if (!win.editingHere)
                return;
            const sel = Scenes.selectedWidget;
            const step = event.modifiers & Qt.ShiftModifier ? 0.02 : 0.004;
            if (event.key === Qt.Key_Escape) {
                if (Scenes.selected !== "")
                    Scenes.selected = "";
                else
                    Scenes.cancel();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Scenes.done();
            } else if (sel && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
                Scenes.remove(sel.id);
            } else if (sel && event.key === Qt.Key_Left) {
                Scenes.patch(sel.id, { x: Math.max(0, sel.x - step) });
            } else if (sel && event.key === Qt.Key_Right) {
                Scenes.patch(sel.id, { x: Math.min(1, sel.x + step) });
            } else if (sel && event.key === Qt.Key_Up) {
                Scenes.patch(sel.id, { y: Math.max(0, sel.y - step) });
            } else if (sel && event.key === Qt.Key_Down) {
                Scenes.patch(sel.id, { y: Math.min(1, sel.y + step) });
            } else if (sel && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)) {
                Scenes.patch(sel.id, { size: Math.min(8, (sel.size ?? 1) * 1.1) });
            } else if (sel && event.key === Qt.Key_Minus) {
                Scenes.patch(sel.id, { size: Math.max(0.3, (sel.size ?? 1) / 1.1) });
            } else {
                return;
            }
            event.accepted = true;
        }

        // Bearbeiten: Grund leicht abdunkeln, Drittel-Linien andeuten
        Rectangle {
            id: backdrop

            anchors.fill: parent
            visible: win.editingHere
            color: Colors.alpha("#000000", 0.28)

            // Nur ein Klick auf freie Flaeche hebt die Auswahl auf – nicht auf
            // ein Widget, sein Optionsfeld oder die Leiste
            TapHandler {
                onTapped: point => {
                    const x = point.position.x, y = point.position.y;
                    const hit = stage.childAt(x, y);
                    if (hit && hit !== backdrop)
                        return;
                    if (stage.selectedHost && stage.selectedHost.optionsContain(x, y))
                        return;
                    Scenes.selected = "";
                }
            }

            Repeater {
                model: [1 / 3, 1 / 2, 2 / 3]

                Rectangle {
                    required property real modelData

                    x: Math.round(parent.width * modelData)
                    width: 1
                    height: parent.height
                    color: Colors.alpha("#ffffff", 0.07)
                }
            }

            Repeater {
                model: [1 / 3, 1 / 2, 2 / 3]

                Rectangle {
                    required property real modelData

                    y: Math.round(parent.height * modelData)
                    height: 1
                    width: parent.width
                    color: Colors.alpha("#ffffff", 0.07)
                }
            }
        }

        // Hilfslinien beim Einrasten (setzt WidgetHost waehrend des Ziehens)
        Rectangle {
            id: guideX

            property real at: -1

            visible: at >= 0
            x: Math.round(at)
            width: 1
            height: parent.height
            color: Colors.primary
        }

        Rectangle {
            id: guideY

            property real at: -1

            visible: at >= 0
            y: Math.round(at)
            height: 1
            width: parent.width
            color: Colors.primary
        }

        // Widgets. ListModel statt JS-Array als Modell: ein Array liesse den
        // Repeater bei jeder Aenderung (Ziehen, Option) alle Widgets neu
        // bauen – Matrix finge von vorn an, Bonsai wuechse neu.
        ListModel {
            id: ids
        }

        readonly property var shown: Scenes.widgetsFor(win.screenName)

        onShownChanged: stage.syncIds()
        Component.onCompleted: stage.syncIds()

        function syncIds(): void {
            const want = stage.shown.map(w => w.id);
            for (let i = ids.count - 1; i >= 0; i--)
                if (!want.includes(ids.get(i).wid))
                    ids.remove(i);
            const have = [];
            for (let i = 0; i < ids.count; i++)
                have.push(ids.get(i).wid);
            for (const id of want)
                if (!have.includes(id))
                    ids.append({ wid: id });
        }

        Repeater {
            model: ids

            WidgetHost {
                required property string wid

                widget: stage.shown.find(w => w.id === wid) ?? null
                screenName: win.screenName
                unit: win.unit
                active: win.active
                editing: win.editingHere
                guideX: guideX
                guideY: guideY
            }
        }

        // Bearbeitungsleiste unten mittig
        Loader {
            active: win.editingHere
            // ueber den Widgets (auch ueber dem Visualiser "unten")
            z: 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36

            sourceComponent: EditBar {
                screenName: win.screenName
            }
        }
    }
}
