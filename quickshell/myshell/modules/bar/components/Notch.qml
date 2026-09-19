pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "root:/"

Item {
    id: notch
    anchors.centerIn: parent
    height: parent.height - 20
    

    readonly property bool containsMouse: ma.containsMouse

    readonly property real borderWidth: 1
    readonly property real borderRad: height / 2
    
    Rectangle {
        id: pill
        anchors.fill: parent

        radius: borderRad
        border.width: borderWidth

        height: parent.height
        color: Colors.background
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: console.log("clicked")
    }
}

// Wrapper (die Pill) – Item als reiner Container, die beiden
// Rectangles (Rand-Ebene + Füllung) liegen als Geschwister darin.
// Z-Effekt = Deklarationsreihenfolge: unten Rand, darüber Füllung.
/*
Item {
    id: notch
    anchors.centerIn: parent
    height: parent.height

    // Breite setzt der Aufrufer (nur er kennt den Label-Text).
    // Ids sind pro Datei unsichtbar -> MouseArea nach außen exponieren.
    readonly property bool containsMouse: ma.containsMouse

    readonly property real borderWidth: 1   // Randbreite
    readonly property real borderRad: height / 2
    readonly property color faceColor: Colors.primary

    // Ebene 1: Randfarbe, volle Form
    Rectangle {
        anchors.fill: parent
        radius: notch.borderRad
        color: notch.faceColor
    }

    // obere Hälfte der Außenform platt machen (keine Rundung oben)
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: parent.height / 2
        color: notch.faceColor
    }

    // Ebene 2: Füllung, 3px kleiner -> übrig gebliebener Saum = Rand
    Rectangle {
        anchors.fill: parent
        anchors.margins: notch.borderWidth
        radius: notch.borderRad - notch.borderWidth
        color: Colors.background
    }

    // obere Hälfte der Füllung auch platt machen
    Rectangle {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: notch.borderWidth
            rightMargin: notch.borderWidth
        }
        height: parent.height / 2
        color: Colors.background
    }

    // MouseArea zuletzt = liegt oben und bekommt alle Klicks/Hover
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: console.log("clicked")
    }
}*/