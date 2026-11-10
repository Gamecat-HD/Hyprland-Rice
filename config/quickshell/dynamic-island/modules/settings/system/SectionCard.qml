pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config

// Karte innerhalb der Systemseite, im Stil von GroupCard (wie die Karten im
// MonitorsEditor): Titel klein oben links, darunter der Inhalt als Spalte.
// Die Hoehe darf von aussen groesser gesetzt werden (zwei Karten nebeneinander
// gleich hoch), der Inhalt bleibt oben.
Rectangle {
    id: card

    property string title: ""
    default property alias content: cardColumn.data
    property alias spacing: cardColumn.spacing

    implicitHeight: cardColumn.anchors.topMargin + cardColumn.implicitHeight + 14
    radius: 16
    color: Colors.alpha(Colors.fgSurface, 0.035)
    border.width: 1
    border.color: Colors.alpha(Colors.outline, 0.14)

    Text {
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 14
            topMargin: 10
        }
        visible: card.title !== ""
        text: card.title
        color: Colors.fgSurfaceVariant
        font.family: Config.font
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    Column {
        id: cardColumn

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14
            rightMargin: 14
            topMargin: card.title !== "" ? 34 : 14
        }
        spacing: 10
    }
}
