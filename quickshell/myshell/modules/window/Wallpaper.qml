pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "root:/"

// Hintergrund-Layer (Wallpaper) – enthält selbst die Pro-Monitor-Logik.
// Die `required property modelData` im Delegaten wird von `Variants`
// automatisch mit dem jeweiligen Screen befüllt (Caelestia-Stil).
// Bewusst nicht "Window.qml" genannt – der Name würde den QML-Typ `Window`
// aus QtQuick überdecken.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        screen: win.modelData
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "myshell-background"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Colors.background

        // Aktuelles Wallpaper (Caelestia-Pfad weiterverwendet, kann beliebig ersetzt werden)
        FileView {
            id: wallpaperFile
            path: Quickshell.env("HOME") + "/.local/state/caelestia/wallpaper/path.txt"
        }

        Image {
            anchors.fill: parent
            source: wallpaperFile.text().trim() !== "" ? "file://" + wallpaperFile.text().trim() : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
}
