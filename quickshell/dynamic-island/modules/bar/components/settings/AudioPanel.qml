pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

import qs.modules.services.audio
import qs
import qs.modules.services.config

// Eigene Settings-Ansicht fuer PipeWire-Ausgabe- und Eingabegeraete.
Item {
    id: panel

    property bool active: false
    readonly property real rowHeight: 48
    readonly property real listHeight: 268

    signal closed()

    implicitHeight: header.height + 6 + listWrapper.height

    Item {
        id: header

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 36

        Rectangle {
            id: backButton

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 30
            height: 30
            radius: 15
            color: backArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.1) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "chevron_left"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: Colors.fgBackground
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.closed()
            }
        }

        Text {
            font.family: Config.font
            anchors {
                left: backButton.right
                leftMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: "Audio"
            color: Colors.fgBackground
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    Item {
        id: listWrapper

        anchors {
            top: header.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
        }
        height: panel.listHeight

        Flickable {
            id: deviceList

            anchors.fill: parent
            contentHeight: devices.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const amount = event.angleDelta.y !== 0 ? event.angleDelta.y / 120
                                                            : event.pixelDelta.y / 40;
                    const maximum = Math.max(0, deviceList.contentHeight - deviceList.height);
                    deviceList.contentY = Math.max(0, Math.min(maximum,
                        deviceList.contentY - amount * panel.rowHeight));
                    event.accepted = true;
                }
            }

            Column {
                id: devices

                width: deviceList.width
                spacing: 4

                Text {
                    font.family: Config.font
                    text: "AUSGABE"
                    color: Colors.primary
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    leftPadding: 10
                    height: 22
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: Audio.sinks

                    DeviceRow {
                        width: devices.width
                        selected: Audio.isSinkSelected(modelData)
                        icon: "speaker"
                        onPicked: Audio.setSink(modelData)
                    }
                }

                Text {
                    font.family: Config.font
                    width: devices.width
                    height: Audio.sinks.length === 0 ? 36 : 0
                    visible: height > 0
                    text: "Kein Ausgabegerät gefunden"
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 11
                    leftPadding: 10
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    font.family: Config.font
                    text: "EINGABE"
                    color: Colors.secondary
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    leftPadding: 10
                    height: 26
                    verticalAlignment: Text.AlignBottom
                }

                Repeater {
                    model: Audio.sources

                    DeviceRow {
                        width: devices.width
                        selected: Audio.isSourceSelected(modelData)
                        icon: "mic"
                        onPicked: Audio.setSource(modelData)
                    }
                }

                Text {
                    font.family: Config.font
                    width: devices.width
                    height: Audio.sources.length === 0 ? 36 : 0
                    visible: height > 0
                    text: "Kein Eingabegerät gefunden"
                    color: Colors.fgSurfaceVariant
                    font.pixelSize: 11
                    leftPadding: 10
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row

        required property PwNode modelData
        required property bool selected
        required property string icon

        signal picked()

        height: panel.rowHeight
        radius: 14
        color: selected ? Colors.alpha(Colors.primary, 0.16)
                        : rowArea.containsMouse ? Colors.alpha(Colors.fgSurface, 0.08)
                                                : "transparent"
        border.width: selected ? 1 : 0
        border.color: Colors.alpha(Colors.primary, 0.45)

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            width: 32
            height: 32
            radius: 16
            color: row.selected ? Colors.primary : Colors.alpha(Colors.fgSurface, 0.12)

            Text {
                anchors.centerIn: parent
                text: row.icon
                color: row.selected ? Colors.fgPrimary : Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 17
            }
        }

        Text {
            font.family: Config.font
            anchors {
                left: parent.left
                leftMargin: 50
                right: radioButton.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: Audio.deviceLabel(row.modelData)
            color: Colors.fgBackground
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            id: radioButton

            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: row.selected ? Colors.primary : Colors.fgSurfaceVariant

            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            Rectangle {
                anchors.centerIn: parent
                width: row.selected ? 10 : 0
                height: width
                radius: width / 2
                color: Colors.primary

                Behavior on width {
                    NumberAnimation { duration: 140; easing.type: Easing.OutBack }
                }
            }
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked()
        }
    }
}
