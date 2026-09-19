pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import "root:/"

// Ausklapp-Inhalt der Notch: Monat + Tagesstreifen als Karussell. In der Mitte
// steht der gewählte Tag (blau, volles Kürzel), heute ist immer rot. Nach außen
// werden die Tage kleiner und blasser und laufen in eine Vignette.
// Gescrollt/gezogen wird von der Notch aus – die ruft shiftDays().
Item {
    id: panel

    // Verschiebung gegenüber heute, in Tagen. Die Notch setzt das beim
    // Zuklappen zurück.
    property int dayOffset: 0

    readonly property date today: dateSource.date
    readonly property date focusDay: panel.addDays(today, dayOffset)

    readonly property real columnWidth: 30
    readonly property real columnSpacing: 2
    readonly property real step: columnWidth + columnSpacing
    readonly property int visibleColumns: 7
    readonly property int sideColumns: 4      // gerendert wird -4..+4, außen frisst die Vignette
    readonly property real topPadding: 8
    // Rundung der unteren Ecken – die Vignette muss der Karte folgen, sonst
    // füllt sie die Ecken wieder rechteckig auf
    property real cornerRadius: 16

    // Pixel-Versatz für die Einschub-Animation (siehe onDayOffsetChanged)
    property real slide: 0
    property int lastOffset: 0

    implicitWidth: visibleColumns * columnWidth + (visibleColumns - 1) * columnSpacing + 16
    implicitHeight: strip.y + strip.height + 10
    clip: true

    // Der Inhalt springt sofort um einen Tag, der Streifen startet dafür um
    // eine Spalte versetzt und fährt zurück auf 0 -> sieht aus wie geschoben.
    onDayOffsetChanged: {
        const delta = panel.dayOffset - panel.lastOffset;
        panel.lastOffset = panel.dayOffset;
        panel.slide = Math.max(-2 * panel.step, Math.min(2 * panel.step, panel.slide + delta * panel.step));
        slideAnim.restart();
    }

    NumberAnimation {
        id: slideAnim

        target: panel
        property: "slide"
        to: 0
        duration: 180
        easing.type: Easing.OutCubic
    }

    // Rad/Ziehen sitzen in der Notch und rufen das hier
    function shiftDays(days: int): void {
        panel.dayOffset += days;
    }

    function addDays(from: date, days: int): date {
        return new Date(from.getFullYear(), from.getMonth(), from.getDate() + days);
    }

    SystemClock {
        id: dateSource
        precision: SystemClock.Minutes   // reicht, um den Tageswechsel mitzubekommen
    }

    Text {
        id: header

        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.topPadding
        text: Qt.formatDate(panel.focusDay, "MMMM yyyy")
        color: Colors.fgSurfaceVariant
        font.pixelSize: 10
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    Row {
        id: strip

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: panel.slide
        y: header.y + header.implicitHeight + 7
        height: 40
        spacing: panel.columnSpacing

        Repeater {
            model: panel.sideColumns * 2 + 1

            Item {
                id: column

                required property int index

                readonly property int offset: index - panel.sideColumns
                readonly property int distance: Math.min(Math.abs(offset), 4)
                readonly property date day: panel.addDays(panel.focusDay, offset)
                readonly property bool isToday: day.getDate() === panel.today.getDate()
                                             && day.getMonth() === panel.today.getMonth()
                                             && day.getFullYear() === panel.today.getFullYear()
                readonly property bool isFocus: offset === 0

                // Je weiter außen, desto kleiner und blasser
                readonly property real numberSize: [15, 13, 11.5, 10, 9][distance]
                readonly property real labelSize: [9.5, 8.5, 8, 7.5, 7][distance]
                readonly property color accent: isToday ? Colors.error
                                              : isFocus ? Colors.primary
                                              : Colors.fgSurface

                width: panel.columnWidth
                height: strip.height
                opacity: [1, 0.72, 0.48, 0.3, 0.18][distance]

                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                // Wochentag: nur der gewählte Tag bekommt das volle Kürzel
                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: 1
                    }
                    text: {
                        const name = Qt.formatDate(column.day, "ddd").replace(".", "").toUpperCase();
                        return column.isFocus ? name : name.charAt(0);
                    }
                    color: column.isToday ? Colors.error
                         : column.isFocus ? Colors.primary
                         : Colors.fgSurfaceVariant
                    font.pixelSize: column.labelSize
                    font.weight: column.isFocus || column.isToday ? Font.Bold : Font.Normal
                    font.letterSpacing: 0.5
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 15
                    width: 26
                    height: 22
                    radius: height / 2
                    color: column.isFocus ? Colors.alpha(Colors.primary, 0.16) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: column.day.getDate()
                        color: column.accent
                        font.pixelSize: column.numberSize
                        font.weight: column.isFocus || column.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }

    // Vignette: weicher Übergang an beiden Rändern, damit die Spalten nicht
    // hart abgeschnitten wirken
    Rectangle {
        anchors {
            left: parent.left
            top: strip.top
            bottom: parent.bottom
        }
        width: 36
        bottomLeftRadius: panel.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.background }
            GradientStop { position: 0.5; color: Colors.alpha(Colors.background, 0.8) }
            GradientStop { position: 1; color: Colors.alpha(Colors.background, 0) }
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            top: strip.top
            bottom: parent.bottom
        }
        width: 36
        bottomRightRadius: panel.cornerRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Colors.alpha(Colors.background, 0) }
            GradientStop { position: 0.5; color: Colors.alpha(Colors.background, 0.8) }
            GradientStop { position: 1; color: Colors.background }
        }
    }
}
