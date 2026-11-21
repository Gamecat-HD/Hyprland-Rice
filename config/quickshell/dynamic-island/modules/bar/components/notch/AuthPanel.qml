pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs
import qs.modules.services.config
import qs.modules.widgets
import qs.modules.settings.system

Item {
    id: panel

    property real topOffset: 0
    property real cardRadius: 18
    property real inset: 2
    property bool active: false
    property var flow: null

    readonly property real outerWidth: implicitWidth + inset * 2
    readonly property real outerHeight: implicitHeight + inset
    readonly property alias maxOuterHeight: panel.outerHeight

    implicitWidth: 440
    implicitHeight: buttons.y + buttons.height + 18

    // Fehlschlag: rot + schuetteln wie im Lock; Pruefen: Punkte als Welle
    property bool failed: false
    property bool checking: false

    anchors {
        left: parent.left
        right: parent.right
        leftMargin: inset
        rightMargin: inset
    }
    y: topOffset

    // Per LazyPanel entsteht die Ansicht bereits aktiv – dann gibt es kein
    // Wechsel-Signal, die Startarbeit (Fokus, Suchfeld) wird nachgeholt
    Component.onCompleted: if (panel.active) Qt.callLater(panel.activeChanged)

    onActiveChanged: {
        password.clear();
        panel.failed = false;
        panel.checking = false;
        if (active)
            Qt.callLater(password.forceActiveFocus);
    }

    Keys.onEscapePressed: panel.flow?.cancelAuthenticationRequest()

    // Kopf wie ein Eintrag der Einstellungs-Leiste: Symbol im 38-px-Kreis,
    // daneben die polkit-Meldung (sagt schon, wofuer – kein eigener Titel)
    Rectangle {
        id: shield

        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 20
            topMargin: 18
        }
        width: 38
        height: 38
        radius: 19
        color: Colors.alpha(Colors.primary, 0.18)

        Text {
            anchors.centerIn: parent
            text: "shield_lock"
            color: Colors.primary
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            // ungefuellt: gefuellt stanzt Material Symbols das Schloss als Loch aus
            font.variableAxes: { "wght": 500 }
        }
    }

    Column {
        id: heading

        anchors {
            left: shield.right
            right: parent.right
            verticalCenter: shield.verticalCenter
            leftMargin: 12
            rightMargin: 20
        }
        spacing: 2

        Text {
            id: message

            width: parent.width
            text: panel.flow?.message || I18n.tr("Eine Anwendung benötigt zusätzliche Berechtigungen.")
            color: Colors.fgSurface
            font.family: Config.font
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        // Nur wenn nicht das eigene Konto gefragt ist (z. B. root)
        Text {
            width: parent.width
            visible: text !== ""
            text: panel.flow?.selectedIdentity
                  && panel.flow.selectedIdentity.string !== "unix-user:" + Quickshell.env("USER")
                ? I18n.tr("Als %1").arg(panel.flow.selectedIdentity.displayName) : ""
            color: Colors.fgSurfaceVariant
            font.family: Config.font
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    // Wie das Passwortfeld des Sperrbildschirms: Punkte-Pille
    PasswordField {
        id: password

        // So breit wie das Feld im Lock, nicht die ganze Karte
        width: 268
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: shield.bottom
            // Mehrzeilige Meldung ragt unter den Kreis
            topMargin: 16 + Math.max(0, heading.y + heading.height - shield.y - shield.height)
        }
        enabled: panel.flow?.isResponseRequired ?? false
        reveal: panel.flow?.responseVisible ?? false
        error: panel.failed
        checking: panel.checking
        placeholder: panel.checking ? ""
            : panel.flow?.isResponseRequired
                ? ((panel.flow.inputPrompt ?? "").replace(/:\s*$/, "") || I18n.tr("Passwort"))
                : I18n.tr("Authentifizierung wird vorbereitet…")
        onTextChanged: if (text !== "") panel.failed = false
        onAccepted: panel.submit()
    }

    Text {
        id: supplementary
        font.family: Config.font
        anchors {
            left: password.left
            right: password.right
            top: password.bottom
            topMargin: text !== "" ? 6 : 0
        }
        height: text !== "" ? 16 : 0
        horizontalAlignment: Text.AlignHCenter
        text: panel.flow?.supplementaryMessage || (panel.failed ? I18n.tr("Falsches Passwort") : "")
        color: panel.flow?.supplementaryIsError || panel.failed ? Colors.error : Colors.fgSurfaceVariant
        font.pixelSize: 11
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    // Textknoepfe wie in den Einstellungen; Bestaetigen ist die Hauptaktion
    Row {
        id: buttons

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: supplementary.bottom
            topMargin: 14
        }
        spacing: 8

        TextButton {
            label: I18n.tr("Abbrechen")
            onClicked: panel.flow?.cancelAuthenticationRequest()
        }

        TextButton {
            filled: true
            label: I18n.tr("Bestätigen")
            enabled: (panel.flow?.isResponseRequired ?? false) && !panel.checking
            onClicked: panel.submit()
        }
    }

    Connections {
        target: panel.flow
        enabled: panel.active

        function onIsResponseRequiredChanged(): void {
            if (panel.flow?.isResponseRequired) {
                panel.checking = false;
                password.clear();
                Qt.callLater(password.forceActiveFocus);
            }
        }

        function onAuthenticationFailed(): void {
            panel.checking = false;
            panel.failed = true;
            password.clear();
            password.shake();
            Qt.callLater(password.forceActiveFocus);
        }
    }

    function submit(): void {
        if (!flow?.isResponseRequired)
            return;

        flow.submit(password.text);
        panel.checking = true;
    }
}
