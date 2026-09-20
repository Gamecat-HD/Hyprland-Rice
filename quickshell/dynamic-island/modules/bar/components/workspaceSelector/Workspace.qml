pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

import "root:/"

// Ein Workspace im Selektor: leer ein Punkt, aktiv die Pille, belegt die
// App-Icons seiner Fenster (caelestia haengt sie unter dem Label, hier
//inline – die Leiste ist ja horizontal).
//
// Den Zustand bekommt die Komponente komplett durchgereicht (activeWsId,
// occupied, groupOffset, windowClasses) statt Hyprland selbst zu fragen –
// sonst wuerde jeder der fuenf Punkte dieselbe Abfrage nochmal machen.
Item {
    id: root

    required property int index          // liefert der Repeater
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    required property var windowClasses

    readonly property int ws: root.groupOffset + root.index + 1
    readonly property bool isActive: root.activeWsId === root.ws
    readonly property bool isOccupied: root.occupied[root.ws] ?? false

    // Fensterklassen dieses Workspaces, gekappt – mehr als drei Icons passen
    // in der horizontalen Leiste nicht sinnvoll unter
    readonly property var classes: (root.windowClasses[root.ws] ?? []).slice(0, 3)
    readonly property bool hasIcons: !root.isActive && root.classes.length > 0

    readonly property real dotSize: 5
    readonly property real activeWidth: 18
    readonly property real iconSize: 13

    // Primaerton wie gehabt fuer die Pille, die Icons im abgeschwaechten
    // Sekundaerton (dieselbe Stufung wie vorher die belegten Punkte), leer
    // bleibt neutral-grau.
    readonly property color colourActive: Colors.primary
    readonly property color colourIcon: Colors.alpha(Colors.secondary, 0.75)
    readonly property color colourEmpty: Colors.outlineVariant

    // Sichtbarer Inhalt und Trefferfläche sind absichtlich entkoppelt: das Item
    // ist deutlich größer als der Inhalt, damit man nicht zielen muss. Das
    // RowLayout hat dafür spacing 0 – der Abstand zwischen den Punkten kommt
    // komplett aus diesem Rand, sonst lägen tote Zonen dazwischen.
    readonly property real hitPadding: 6
    readonly property real hitHeight: 24

    // Ohne Alignment würde das RowLayout den Punkt auf volle Kartenhöhe ziehen
    Layout.alignment: Qt.AlignVCenter

    // Breite: aktiv die Pille, belegt die Icon-Reihe (n * iconSize plus Luft
    // dazwischen), leer der Punkt. Weil die Breite aus dem Zustand kommt,
    // waechst das Layout – und damit die Karte – automatisch mit.
    implicitWidth: (root.isActive ? root.activeWidth
                   : root.hasIcons ? root.classes.length * root.iconSize + (root.classes.length - 1) * 2
                   : root.dotSize) + root.hitPadding * 2
    implicitHeight: root.hitHeight + root.hitPadding * 2

    Behavior on implicitWidth {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Aktiv: die Pille als Anker zum Orientieren
    Rectangle {
        visible: root.isActive
        anchors.centerIn: parent

        width: root.activeWidth
        height: root.dotSize
        radius: height / 2
        color: root.colourActive

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    // Belegt: die App-Icons der Fenster auf diesem Workspace
    Row {
        visible: root.hasIcons
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.classes

            Text {
                required property string modelData

                width: root.iconSize
                text: root.iconFor(modelData)
                font.family: "Material Symbols Outlined"
                font.pixelSize: root.iconSize - 1
                horizontalAlignment: Text.AlignHCenter
                color: root.colourIcon

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }
        }
    }

    // Leer: der Punkt
    Rectangle {
        visible: !root.isActive && !root.hasIcons
        anchors.centerIn: parent

        width: root.dotSize
        height: root.dotSize
        radius: height / 2
        color: root.colourEmpty

        // Leer reagiert auf Hover – die Icons und die Pille sind schon
        // unterscheidbar genug
        scale: hover.hovered ? 1.4 : 1

        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    // Fensterklasse -> Material-Symbol. Grob nach Kategorien ueber
    // Substring-Match, dieselbe Idee wie caelestias
    // Icons.getAppCategoryIcon, nur ohne Desktop-Eintraegelei direkt auf
    // dem Klassennamen.
    function iconFor(cls: string): string {
        const c = cls.toLowerCase();
        const map = [
            ["firefox", "language"], ["zen", "language"], ["librewolf", "language"],
            ["chrom", "language"], ["brave", "language"],
            ["kitty", "terminal"], ["alacritty", "terminal"], ["foot", "terminal"],
            ["konsole", "terminal"], ["wezterm", "terminal"],
            ["dolphin", "folder"], ["thunar", "folder"], ["nautilus", "folder"],
            ["code", "code"], ["vscod", "code"], ["zed", "code"],
            ["discord", "chat"], ["vesktop", "chat"], ["equicord", "chat"],
            ["telegram", "chat"], ["whatsapp", "chat"],
            ["spotify", "music_note"],
            ["steam", "sports_esports"], ["lutris", "sports_esports"],
            ["heroic", "sports_esports"], ["minecraft", "sports_esports"],
            ["mpv", "movie"], ["vlc", "movie"],
            ["thunderbird", "mail"], ["geary", "mail"],
            ["obs", "videocam"], ["zoom", "videocam"], ["teams", "videocam"],
            ["gimp", "brush"], ["inkscape", "brush"], ["krita", "brush"],
            ["idea", "code"], ["pycharm", "code"], ["java", "code"]
        ];
        for (const [needle, icon] of map)
            if (c.includes(needle))
                return icon;
        return "terminal";   // derselbe Fallback wie in caelestia
    }

    // Handler statt MouseArea: die beiden verhandeln den Grab untereinander
    // und nehmen sich nichts weg (siehe Kommentar in Notch.qml).
    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            // Aktiver Punkt = Eintritt in den generischen Special (die
            // Chips, siehe SpecialWorkspaces.qml). FRUEHER stand hier ein
            // "dynamic-island toggle specialws" CLI-Aufruf - den gibt es
            // nicht, der Klick tat deshalb sichtbar nichts.
            if (root.isActive) {
                Hyprland.dispatch(Hyprland.usingLua
                    ? 'hl.dsp.workspace.toggle_special("special")'
                    : "togglespecialworkspace special");
                return;
            }

            // Lua-Config versteht nur Lua – dieselbe Weiche wie in
            // caelestia/services/Hypr.qml
            Hyprland.dispatch(Hyprland.usingLua
                ? `hl.dsp.focus({ workspace = ${root.ws} })`
                : `workspace ${root.ws}`);
        }
    }
}
