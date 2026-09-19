pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

import "root:/"

// Systemtray im Settings-Stil: Pille mit Border, kollabiert auf einen Kreis
// (nur die zuletzt gestartete Tray-App sichtbar), Hover klappt nach links auf.
// Menue: natives Popup via QsMenuAnchor (Wayland-Grab -> kein Hover-Scrollen
// im Menue selbst, schliessen durch Klick daneben).
Rectangle {
    id: root

    // Schnittstelle (Bar.qml setzt verticalMargin / borderWidth – wie bei Settings)
    required property real verticalMargin
    property real borderWidth: 1

    readonly property real iconSize: 16
    readonly property real padding: 7     // 7 + 16 + 7 = 30 = Höhe -> kollabiert exakt Kreis
    // Zählung offener Menüs: Während der Wayland-Grab des Menüs uns den Hover
    // klaut, hält dieser Zähler die Pill bewusst ausgeklappt.
    property int openMenus: 0
    readonly property bool expanded: hover.hovered || openMenus > 0
    readonly property var trayItems: SystemTray.items.values
    readonly property var current: trayItems.length ? trayItems[trayItems.length - 1] : null

    anchors {
        verticalCenter: parent.verticalCenter
    }
    implicitWidth: expanded ? trayRow.implicitWidth + padding * 2 : height
    height: parent.height - verticalMargin
    radius: height / 2                       // Kreis (kollabiert) -> Pille (ausgeklappt)
    color: Colors.background
    border.width: borderWidth
    border.color: Colors.outlineVariant
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    HoverHandler { id: hover }

    Row {
        id: trayRow
        anchors {
            right: parent.right              // fix rechts -> Wachstum nach links
            rightMargin: root.padding
            verticalCenter: parent.verticalCenter
        }
        spacing: 8

        Repeater {
            model: root.trayItems

            MouseArea {
                id: trayEntry

                required property SystemTrayItem modelData
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true

                // kollabiert: nur das neueste Item bleibt sichtbar
                opacity: root.expanded || trayEntry.modelData === root.current ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                // Hover mit Verzögerung -> Menü; onExited stoppt nur den Timer
                // (KEIN close – der Grab des offenen Menüs feuert ohnehin ein
                // exit; schließen tut das Menü selbst durch Klick woanders).
                onEntered: if (trayEntry.modelData.hasMenu) hoverTimer.restart()
                onExited: hoverTimer.stop()

                Timer {
                    id: hoverTimer
                    interval: 300
                    onTriggered: if (trayEntry.containsMouse && !menuAnchor.visible) menuAnchor.open() else if (!menuAnchor.visible) menuAnchor.close() else hoverTimer.restart()
                }

                onClicked: event => {
                    if (event.button === Qt.LeftButton)
                        trayEntry.modelData.activate();
                    else if (trayEntry.modelData.hasMenu)
                        menuAnchor.open();
                    else
                        trayEntry.modelData.secondaryActivate();
                }

                IconImage {
                    anchors.fill: parent
                    source: trayEntry.modelData.icon
                }

                // Natives Menü der App unterhalb des Icons;
                // anchor.item lässt Quickshell die Position selbst ausrechnen.
                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayEntry.modelData.hasMenu ? trayEntry.modelData.menu : null
                    anchor.item: trayEntry
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                    anchor.margins.top: 6
                    onVisibleChanged: root.openMenus += visible ? 1 : -1
                }
            }
        }
    }
}
