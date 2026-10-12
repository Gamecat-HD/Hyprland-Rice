pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.modules.services.config

// Gestalt-Singleton – ueberall per `Appearance.<wert>` nutzbar.
//
// Hier steht einmal, wie sich die Pillen und Karten der Shell anfuehlen:
// Rundung, Rand, Schatten, Verlauf und vor allem die Bewegung. Die
// Komponenten holen sich die Werte ueber Surface.qml und Morph.qml
// (modules/widgets), statt sie jede fuer sich zu kennen.
//
// Vorbild ist saneAspects "Dynamite": eine schwarze Insel, die mit echtem
// Nachschwingen auf- und zuklappt. Wie stark sie schwingt, stellt man im
// Einstellungs-Menue ein (appearance.bounce).
Singleton {
    id: root

    // ---- Form ----
    // Eckenrundung der Karten. Flache Pillen deckeln ohnehin auf height / 2.
    readonly property real radius: Config.appearance.radius
    readonly property real borderWidth: 1
    // Der Rand ist bewusst halbtransparent: er zeichnet die Kante nach,
    // ohne auf hellen Wallpapern als grauer Ring zu stehen.
    readonly property color borderColor: Colors.alpha(Colors.outline, 0.38)

    // Leichter Verlauf: oben eine Spur heller als der Grund, unten der Grund
    // selbst. Das gibt den Pillen eine Oberseite, auf der Licht liegt.
    readonly property real lift: 0.035

    // ---- Notch-Layout ----
    // Die angedockte Notch ist schwarz wie ein Displayrahmen und geht ueber
    // gewoelbte Schultern in die Oberkante ueber (saneAspect-Vorbild).
    readonly property bool notchLayout: Config.appearance.layout === "notch"
    readonly property color notchColor: "#000000"
    // Radius der Schultern (eingeklappt / aufgeklappt). Aufgeklappt folgt er
    // der Eckenrundung (appearance.radius), damit Ober- und Unterecken der
    // Karte zueinander passen.
    readonly property real notchShoulder: 10
    readonly property real notchShoulderOpen: Math.max(notchShoulder, Math.round(radius * 0.8))
    // So viel waechst die eingeklappte Notch unter dem Zeiger: nach unten
    // um den Wert, zur Seite um das Doppelte – statt zu skalieren, was die
    // Schultern von der Kante loesen wuerde.
    readonly property real notchHoverLift: 5

    // ---- Schatten ----
    readonly property bool shadow: Config.appearance.shadow
    readonly property color shadowColor: "#000000"
    readonly property real shadowBlur: 0.9
    readonly property real shadowOpacity: 0.5
    readonly property real shadowOffset: 4

    // ---- Bewegung ----
    // Dauer der Groessen-Animationen (Pille <-> Karte)
    readonly property real speed: Math.max(0.25, Config.appearance.speed)
    readonly property int morphDuration: Math.round(340 / speed)
    // Ein-/Ausblenden von Inhalten
    readonly property int fadeDuration: Math.round(160 / speed)

    // Nachschwingen beim Aufklappen. 0 = klassisch weich (OutCubic), sonst
    // OutBack mit diesem Overshoot (Qt-Default waere 1.70158 ~ 10 %).
    readonly property var bounceLevels: ({
        "aus": 0,
        "leicht": 0.7,
        "mittel": 1.3,
        "stark": 2.1
    })
    readonly property real overshoot: root.bounceLevels[Config.appearance.bounce] ?? 1.3
}
