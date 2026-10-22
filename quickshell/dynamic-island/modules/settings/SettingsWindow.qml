pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Einstellungs-Fenster, mittig auf dem Bildschirm. Der Inhalt – Gruppen-
// leiste, Zeilen, Plugin-Verwaltung – ist SettingsCard.qml; hier steht nur
// die Layer-Oberflaeche, die sie traegt.
//
// Bewusst keine Anker: eine Layer-Oberflaeche ohne Anker setzt der Compositor
// mittig – genau das, was hier gebraucht wird. Das Fenster ist etwas groesser
// als die Karte, damit deren Schatten Platz hat.
//
// Gebaut wird es erst beim Oeffnen und nur auf dem Ziel-Monitor (LazyLoader) –
// frueher lebte es je Monitor versteckt mit, samt Gruppenleiste und Zeilen.
LazyLoader {
    active: SettingsState.open && SettingsState.screen !== null

    PanelWindow {
        id: win

        readonly property ShellScreen modelData: SettingsState.screen

        readonly property real inset: 28

        screen: win.modelData
        visible: SettingsState.open && SettingsState.screen === win.modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dynamic-island-settings"
        // Fuers Suchfeld. Exclusive, weil das Fenster ueber einen Klick in der
        // Leiste aufgeht – es gibt keinen Klick, der ihm den Fokus gaebe.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        // Etwas hoeher als frueher (580): die Gruppenleiste traegt jetzt auch
        // die Plugins
        implicitWidth: 880 + inset * 2
        implicitHeight: 640 + inset * 2

        onVisibleChanged: {
            if (visible)
                card.reset();
        }
        // Entsteht bereits sichtbar – dann kommt kein Wechsel-Signal
        Component.onCompleted: if (visible) Qt.callLater(win.visibleChanged)

        SettingsCard {
            id: card

            anchors {
                fill: parent
                margins: win.inset
            }
            shown: win.visible
        }
    }
}
