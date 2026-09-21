pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "root:/"

// Sitzungsmenue der Notch. Aufbau und Masse folgen den Auswahlkarten fuer
// Wallpaper und Themes; statt eines Karussells gibt es eine Reihe Aktionen.
Item {
    id: panel

    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    readonly property alias maxOuterHeight: panel.outerHeight

    readonly property var actions: [
        { label: "Sperren", icon: "lock", hue: Colors.primary,
          command: ["hyprlock"] },
        { label: "Abmelden", icon: "logout", hue: Colors.secondary,
          command: ["hyprctl", "dispatch", "exit"] },
        { label: "Standby", icon: "bedtime", hue: Colors.tertiary,
          command: ["systemctl", "suspend"] },
        { label: "Neustart", icon: "restart_alt",
          hue: Colors.mix(Colors.tertiary, Colors.error, 0.42),
          command: ["systemctl", "reboot"] },
        { label: "Ausschalten", icon: "power_settings_new", hue: Colors.error,
          command: ["systemctl", "poweroff"] }
    ]

    implicitWidth: 760
    implicitHeight: actionArea.height

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: panel.inset
        rightMargin: panel.inset
    }
    y: panel.topOffset

    onActiveChanged: if (active) panel.forceActiveFocus()

    Keys.onEscapePressed: LauncherState.close()

    function run(command: var): void {
        LauncherState.close();
        Quickshell.execDetached(command);
    }

    Item {
        id: actionArea

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 116

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Repeater {
                model: panel.actions

                Rectangle {
                    id: action

                    required property var modelData

                    readonly property bool hovered: actionMouse.containsMouse

                    width: (actionArea.width - 20 - 8 * 4) / 5
                    height: actionArea.height - 20
                    radius: Math.min(panel.cardRadius - 5, 13)
                    color: action.hovered ? Colors.alpha(action.modelData.hue, 0.16)
                                          : Colors.alpha(Colors.surfaceContainer, 0.55)
                    border.width: action.hovered ? 1 : 0
                    border.color: Colors.alpha(action.modelData.hue, 0.62)
                    scale: action.hovered ? 1.025 : 1

                    Behavior on color {
                        ColorAnimation { duration: 130 }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 130 }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: action.modelData.icon
                            color: action.hovered ? action.modelData.hue : Colors.fgSurfaceVariant
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 25
                            font.variableAxes: ({ wght: action.hovered ? 650 : 500 })

                            Behavior on color {
                                ColorAnimation { duration: 130 }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: action.modelData.label
                            color: action.hovered ? action.modelData.hue : Colors.fgSurfaceVariant
                            font.pixelSize: 11
                            font.weight: action.hovered ? Font.DemiBold : Font.Normal

                            Behavior on color {
                                ColorAnimation { duration: 130 }
                            }
                        }
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.run(action.modelData.command)
                    }
                }
            }
        }
    }
}
