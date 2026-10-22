import QtQuick
import QtQuick.Layouts

import qs
import qs.modules.services.config

// Kleine Versalien-Beschriftung vor einer Chip-Reihe
Text {
    color: Colors.fgSurfaceVariant
    font.family: Config.font
    font.pixelSize: 9
    font.weight: Font.DemiBold
    font.letterSpacing: 0.8
    font.capitalization: Font.AllUppercase
    Layout.alignment: Qt.AlignVCenter
}
