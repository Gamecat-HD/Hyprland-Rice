pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config

// Zeile unter dem Raster der eingebetteten Steuerung.
//
// Normal: nur ein kleiner Stift rechts, der den Bearbeitungsmodus oeffnet
// (die zweite Tuer neben dem langen Druck auf eine Kachel).
// Bearbeiten: mittig die Pille mit den beiden Ansichten ("Bearbeiten" =
// Kacheln, "Layout" = Reihen), rechts "Fertig".
//
// Haelt ausserdem den Tastaturfokus waehrend des Bearbeitens: Esc beendet
// den Modus (statt die Notch zu schliessen). ControlPanel meldet den Modus
// als `typing`, damit die Leiste die Tastatur ueberhaupt bekommt.
Item {
    id: footer

    required property QuickEdit edit

    readonly property bool editing: footer.edit.editing

    implicitHeight: footer.editing ? 30 : 22

    Behavior on implicitHeight {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Connections {
        target: footer.edit

        function onStarted(): void {
            keys.forceActiveFocus();
        }
    }

    Item {
        id: keys

        focus: footer.editing
        Keys.onEscapePressed: event => {
            if (!footer.editing) {
                event.accepted = false;
                return;
            }
            footer.edit.finish();
        }
    }

    // ---- Normal: der Stift ----
    Rectangle {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: 24
        height: 24
        radius: 12
        color: Colors.alpha(Colors.fgSurface, pencilHover.hovered ? 0.14 : 0.05)
        opacity: footer.editing ? 0 : 1
        visible: opacity > 0

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: "edit"
            color: Colors.alpha(Colors.fgSurfaceVariant, pencilHover.hovered ? 1 : 0.65)
            font.family: "Material Symbols Outlined"
            font.pixelSize: 14

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        HoverHandler {
            id: pencilHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: footer.edit.begin("")
        }
    }

    // ---- Bearbeiten: Ansicht-Pille mittig ----
    Rectangle {
        id: pill

        readonly property var modes: ["tiles", "layout"]
        readonly property var labels: [I18n.tr("Bearbeiten"), I18n.tr("Layout")]
        readonly property int current: Math.max(0, pill.modes.indexOf(footer.edit.mode))
        // Beide Segmente gleich breit (der laengere Text gibt vor)
        readonly property real segmentWidth: Math.max(label0.implicitWidth, label1.implicitWidth) + 30
        readonly property real inset: 3

        anchors.centerIn: parent
        width: pill.segmentWidth * 2 + pill.inset * 2
        height: 30
        radius: 15
        color: Colors.alpha(Colors.fgSurface, 0.08)
        border.width: 1
        border.color: Colors.alpha(Colors.outline, 0.25)
        opacity: footer.editing ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        // Die Markierung wandert unter das gewaehlte Segment
        Rectangle {
            x: pill.inset + pill.current * pill.segmentWidth
            y: pill.inset
            width: pill.segmentWidth
            height: pill.height - pill.inset * 2
            radius: height / 2
            color: Colors.primary

            Behavior on x {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: label0

            x: pill.inset
            width: pill.segmentWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.font
            text: pill.labels[0]
            color: pill.current === 0 ? Colors.fgPrimary : Colors.fgSurface
            font.pixelSize: 12
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        Text {
            id: label1

            x: pill.inset + pill.segmentWidth
            width: pill.segmentWidth
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Config.font
            text: pill.labels[1]
            color: pill.current === 1 ? Colors.fgPrimary : Colors.fgSurface
            font.pixelSize: 12
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: pillTap

            onTapped: {
                const index = pillTap.point.position.x < pill.width / 2 ? 0 : 1;
                footer.edit.mode = pill.modes[index];
                footer.edit.selectedId = "";
            }
        }
    }

    // ---- Bearbeiten: Fertig ----
    EditButton {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        icon: "check"
        text: I18n.tr("Fertig")
        accent: true
        opacity: footer.editing ? 1 : 0
        visible: opacity > 0
        onClicked: footer.edit.finish()

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }
}
