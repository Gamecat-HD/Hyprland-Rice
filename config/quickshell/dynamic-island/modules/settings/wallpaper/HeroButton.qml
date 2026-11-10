import QtQuick

import qs
import qs.modules.services.config

// Knopf der Kopfzeile "Aktuelles Wallpaper" (WallpaperHero.qml). Ein Bautyp
// fuer alle Varianten: flach (Ordner, Neu laden, Bibliothek), `on` getoent
// (Timer-Chip), `filled` in der Akzentfarbe (Zufall), `tonal` daneben als
// zweite Wahl; `big` fuer die 40-px-Pille.
//
// Eigene Datei statt `component` in der Kopfzeile: Inline-Components, die
// beim Hot-Reload zu einer bestehenden Datei dazukommen, loest Quickshell
// bis zum Neustart nicht auf ("... is not a type"). Eine neue Datei ist
// davon nicht betroffen.
Rectangle {
    id: button

    property string icon: ""
    property string label: ""
    property bool on: false
    property bool filled: false
    property bool tonal: false
    property bool big: false
    property bool spinning: false
    signal clicked()

    readonly property bool accent: button.on || button.tonal
    readonly property color fg: button.filled ? Colors.fgPrimary
                              : button.accent ? Colors.primary
                              : Colors.fgSurface
    readonly property color fgIcon: button.filled ? Colors.fgPrimary
                                  : button.accent || buttonHover.hovered ? Colors.primary
                                  : Colors.fgSurfaceVariant

    implicitWidth: buttonRow.implicitWidth + (button.big ? 34 : 20)
    implicitHeight: button.big ? 40 : 28
    radius: height / 2
    color: button.filled ? (buttonHover.hovered ? Colors.alpha(Colors.primary, 0.85) : Colors.primary)
         : button.accent ? Colors.alpha(Colors.primary, buttonHover.hovered ? 0.3 : 0.2)
         : buttonHover.hovered ? Colors.alpha(Colors.fgSurface, 0.12)
         : Colors.alpha(Colors.fgSurface, 0.06)

    Behavior on color {
        ColorAnimation { duration: Appearance.fadeDuration }
    }

    Row {
        id: buttonRow

        anchors.centerIn: parent
        spacing: button.big ? 7 : 5

        Text {
            id: buttonIcon

            anchors.verticalCenter: parent.verticalCenter
            visible: button.icon !== ""
            text: button.icon
            font.family: "Material Symbols Outlined"
            font.pixelSize: button.big ? 19 : 15
            color: button.fgIcon

            Behavior on color {
                ColorAnimation { duration: Appearance.fadeDuration }
            }

            // Dreht sich, solange etwas laeuft (Neu laden); danach wieder gerade
            RotationAnimation on rotation {
                id: spin

                running: button.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!spin.running) buttonIcon.rotation = 0
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.label !== ""
            text: button.label
            font.family: Config.font
            font.pixelSize: button.big ? 13 : 11
            font.weight: button.big ? Font.DemiBold : Font.Medium
            color: button.fg
        }
    }

    HoverHandler {
        id: buttonHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }
}
