pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.lock
import qs.modules.services.media

// Die Buehne des Anordnungs-Editors: der echte Sperrbildschirm als Vorschau
// (ohne Sperre, ohne PAM – `preview`), darueber ein Griff je Element
// (EditHandle.qml), Hilfslinien beim Einrasten und die Leiste rechts unten
// (LockEditBar.qml).
//
// Tasten: Pfeile verschieben das gewaehlte Element (Umschalt = grosse
// Schritte), + / - aendern die Groesse, Strg+Z / Strg+Umschalt+Z machen
// rueckgaengig / wieder her, Esc hebt erst die Auswahl auf, dann bricht es
// ab, Enter ist Fertig.
Item {
    id: stage

    focus: true

    readonly property Item selectedHandle: LockLayout.selected === "clock" ? clockHandle
                                         : LockLayout.selected === "media" ? mediaHandle : null
    // Maus ueber der Leiste: Griffe darunter nehmen nichts an
    readonly property bool overUi: bar.hovered

    // Sanft erscheinen – die Vorschau selbst springt (keine Szenen-Animation)
    opacity: 0

    NumberAnimation on opacity {
        to: 1
        duration: Appearance.morphDuration
        easing.type: Easing.OutCubic
    }

    // Liegt ein Punkt (Buehnenkoordinaten) auf der Leiste?
    function onUi(x: real, y: real): bool {
        const p = bar.mapFromItem(stage, x, y);
        return p.x >= 0 && p.y >= 0 && p.x <= bar.width && p.y <= bar.height;
    }

    Keys.onPressed: event => {
        const sel = stage.selectedHandle;
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const step = shift ? 0.02 : 0.004;
        if (ctrl && event.key === Qt.Key_Z) {
            if (shift)
                LockLayout.redo();
            else
                LockLayout.undo();
        } else if (ctrl && event.key === Qt.Key_Y) {
            LockLayout.redo();
        } else if (event.key === Qt.Key_Escape) {
            if (LockLayout.selected !== "")
                LockLayout.selected = "";
            else
                LockLayout.cancel();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            LockLayout.done();
        } else if (sel && event.key === Qt.Key_Left) {
            sel.nudge(-step, 0);
        } else if (sel && event.key === Qt.Key_Right) {
            sel.nudge(step, 0);
        } else if (sel && event.key === Qt.Key_Up) {
            sel.nudge(0, -step);
        } else if (sel && event.key === Qt.Key_Down) {
            sel.nudge(0, step);
        } else if (sel && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal)) {
            sel.grow(1.1);
        } else if (sel && event.key === Qt.Key_Minus) {
            sel.grow(1 / 1.1);
        } else {
            return;
        }
        event.accepted = true;
    }

    LockContext {
        id: previewContext
    }

    LockScreen {
        id: preview

        anchors.fill: parent
        context: previewContext
        preview: true
        focus: false
    }

    // Drittel-Linien andeuten – kein Schleier: die Vorschau soll genau so
    // aussehen wie nachher die Sperre. Die MouseArea nimmt jeden Druck an:
    // nichts davon erreicht die Vorschau (Medien-Knoepfe, Fokus-Griff des
    // Sperrbildschirms). Die Griffe liegen darueber und holen sich das
    // Ziehen (DragHandler) von ihr.
    Item {
        id: backdrop

        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            // Nur ein Druck auf freie Flaeche hebt die Auswahl auf – nicht
            // auf einen Griff samt Rahmen (der ragt ueber das Element
            // hinaus) und nicht auf die Leiste
            onPressed: mouse => {
                const x = mouse.x, y = mouse.y;
                if (stage.onUi(x, y) || clockHandle.owns(x, y) || mediaHandle.owns(x, y))
                    return;
                LockLayout.selected = "";
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

    // Hilfslinien beim Einrasten (setzt EditHandle waehrend des Ziehens)
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

    EditHandle {
        id: clockHandle

        name: "clock"
        title: I18n.tr("Uhr")
        target: preview.clockItem
        other: mediaHandle
        blocked: stage.overUi
        guideX: guideX
        guideY: guideY
    }

    EditHandle {
        id: mediaHandle

        name: "media"
        title: I18n.tr("Medien")
        target: preview.mediaItem
        other: clockHandle
        // Ohne Musik steht die Karte leer da – zurueckgenommen, als Platzhalter
        placeholder: !Media.available
        blocked: stage.overUi
        guideX: guideX
        guideY: guideY
    }

    // Leiste rechts unten: unten mittig steht die Karte
    LockEditBar {
        id: bar

        z: 20
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 36
    }
}
