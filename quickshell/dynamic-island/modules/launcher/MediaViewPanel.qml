pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.media
import qs.modules.bar.components.mediaPlayer

// Untermenue "Medien" der Notch: dieselbe Ansicht wie die aufgeklappte
// Medien-Pille – Player-Auswahl oben, Cover mit Visualiser-Ring, Titel,
// Fortschritt, Transport. Aufruf: SUPER+M, `>medien`, Blaettern.
ViewPanel {
    id: root

    title: "Medien"
    icon: "music_note"
    // Breite der Medien-Spalte: das Cover rechnet sich daraus, breiter = hoeher
    readonly property real columnWidth: 320

    contentWidth: root.columnWidth
    contentHeight: Media.available ? media.outerHeight : 60
    maxContentHeight: Math.max(60, media.outerHeight)

    // Im Notch-Layout ist die Karte so breit wie alle Blaetter-Seiten (548).
    // MediaPanel rechnet sein Cover aus der Breite – deshalb eine feste,
    // mittige Spalte, sonst wuerde das Cover riesig.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, root.columnWidth)
        height: media.outerHeight
        visible: Media.available

        MediaPanel {
            id: media

            topOffset: 0
            padding: 0
            tint: Appearance.notchLayout ? Appearance.notchColor : Colors.background
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !Media.available
        text: "Nichts spielt gerade"
        color: Colors.fgSurfaceVariant
        font.family: Config.font
        font.pixelSize: 12
    }
}
