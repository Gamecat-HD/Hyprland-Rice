pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.system

// Update-Karte der Systemseite (SystemEditor) fuer die Shell selbst, also
// das Git-Repo (ShellUpdate): Stand der Pruefung mit Symbol, darunter die
// neuen Commits des Upstreams (einklappbar, scrollt ab listMax), der
// Fehlertext von git, falls der Pull abgelehnt wurde, die eigenen
// Aenderungen (zugeklappt) und die Knoepfe "Shell neu starten", "Nach
// Updates suchen" und "Aktualisieren" (shellupdate.sh, abgekoppelt).
SectionCard {
    id: card

    property bool listOpen: true
    property bool changesOpen: false
    readonly property int listMax: 220

    readonly property bool checking: ShellUpdate.checking
    readonly property bool updating: ShellUpdate.updating
    readonly property bool done: ShellUpdate.updateDone && !card.updating
    readonly property bool failed: ShellUpdate.updateFailed
                                 || (ShellUpdate.checkState === "error" && !card.updating && !ShellUpdate.updateDone)
    readonly property int behind: ShellUpdate.behind
    readonly property bool hasList: card.behind > 0 && ShellUpdate.incoming.length > 0

    readonly property string statusText: {
        if (card.updating) {
            switch (ShellUpdate.updateStep) {
            case "build": return I18n.tr("Baue CLI-Helfer… (kann dauern)");
            case "hypr": return I18n.tr("Lade Hyprland neu…");
            case "restart": return I18n.tr("Starte Shell neu…");
            default: return I18n.tr("Lade Updates herunter…");
            }
        }
        if (ShellUpdate.updateFailed)
            return I18n.tr("Update fehlgeschlagen");
        if (card.done) {
            if (ShellUpdate.updatePulled === 1)
                return I18n.tr("Aktualisiert – 1 Commit übernommen");
            return I18n.tr("Aktualisiert – %1 Commits übernommen").arg(ShellUpdate.updatePulled);
        }
        if (card.checking)
            return I18n.tr("Suche nach Updates…");
        if (ShellUpdate.checkState === "error")
            return I18n.tr("Prüfung fehlgeschlagen");
        if (!ShellUpdate.loaded)
            return I18n.tr("Lade…");
        if (card.behind === 1)
            return I18n.tr("1 neuer Commit");
        if (card.behind > 1)
            return I18n.tr("%1 neue Commits").arg(card.behind);
        if (ShellUpdate.lastCheck === 0)
            return I18n.tr("Noch nicht geprüft");
        return I18n.tr("Shell ist aktuell");
    }

    readonly property string detailText: {
        if (card.updating || ShellUpdate.updateFailed)
            return "";
        if (card.done)
            return ShellUpdate.commit !== "" ? I18n.tr("Stand %1 · %2").arg(ShellUpdate.commit).arg(ShellUpdate.commitAge) : "";
        if (card.checking)
            return "";
        if (ShellUpdate.checkState === "error")
            return ShellUpdate.checkError;
        if (!ShellUpdate.loaded)
            return "";
        const parts = [];
        if (ShellUpdate.upstream !== "")
            parts.push(ShellUpdate.upstream);
        if (ShellUpdate.ahead === 1)
            parts.push(I18n.tr("1 eigener Commit"));
        else if (ShellUpdate.ahead > 1)
            parts.push(I18n.tr("%1 eigene Commits").arg(ShellUpdate.ahead));
        if (ShellUpdate.localCount === 1)
            parts.push(I18n.tr("1 eigene Änderung"));
        else if (ShellUpdate.localCount > 1)
            parts.push(I18n.tr("%1 eigene Änderungen").arg(ShellUpdate.localCount));
        if (ShellUpdate.lastCheck > 0)
            parts.push(I18n.tr("geprüft %1").arg(Qt.formatTime(new Date(ShellUpdate.lastCheck), "HH:mm")));
        return parts.join("  ·  ");
    }

    readonly property bool spinning: card.updating || card.checking
    readonly property string statusIcon: card.spinning ? "progress_activity"
                                       : card.failed ? "error"
                                       : card.done ? "check_circle"
                                       : card.behind > 0 ? "system_update"
                                       : "check_circle"

    // git-Fehler, bei dem eigene Aenderungen oder Commits im Weg stehen
    readonly property bool conflictHint: /overwritten|local changes|fast-forward|diverg|stash|commit your changes|überschrieben|lokale Änderungen|Vorspulen/i.test(ShellUpdate.updateError)

    title: I18n.tr("Update")
    spacing: 8

    // Statuszeile: Symbol, Text, Pfeil zum Auf- und Zuklappen der Liste
    Item {
        width: parent.width
        height: 36

        Rectangle {
            id: statusBadge

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 36
            height: 36
            radius: 12
            color: Colors.alpha(card.failed ? Colors.error : Colors.primary, 0.14)

            Text {
                id: statusIconText

                anchors.centerIn: parent
                text: card.statusIcon
                color: card.failed ? Colors.error : Colors.primary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                font.variableAxes: ({ FILL: card.behind > 0 && !card.spinning && !card.failed ? 1 : 0 })

                RotationAnimator {
                    target: statusIconText
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: card.spinning && statusIconText.visible
                    onRunningChanged: if (!running)
                        statusIconText.rotation = 0
                }
            }
        }

        Column {
            anchors {
                left: statusBadge.right
                leftMargin: 10
                right: chevron.visible ? chevron.left : parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 1

            Text {
                width: parent.width
                text: card.statusText
                color: Colors.fgBackground
                font.family: Config.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: card.detailText
                color: card.failed ? Colors.error : Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Text {
            id: chevron

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: card.hasList
            text: "expand_more"
            color: Colors.fgSurfaceVariant
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            rotation: card.listOpen ? 180 : 0

            Behavior on rotation {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
            }
        }

        HoverHandler {
            enabled: card.hasList
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: card.hasList
            onTapped: card.listOpen = !card.listOpen
        }
    }

    // Neue Commits: Hash, Betreff, Alter
    Item {
        id: listBox

        width: parent.width
        height: card.listOpen && card.hasList ? Math.min(card.listMax, list.contentHeight) : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }

        ListView {
            id: list

            anchors.fill: parent
            spacing: 0
            cacheBuffer: 2000
            boundsBehavior: Flickable.StopAtBounds
            model: ShellUpdate.incoming

            delegate: Item {
                id: entry

                required property var modelData

                width: list.width
                height: 24

                Rectangle {
                    id: hashTag

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: 60
                    height: 16
                    radius: height / 2
                    color: Colors.alpha(Colors.primary, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: entry.modelData.hash
                        color: Colors.primary
                        font.family: Config.font
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    anchors {
                        left: hashTag.right
                        leftMargin: 8
                        right: whenLabel.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: entry.modelData.subject
                    color: Colors.fgBackground
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: whenLabel

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.min(implicitWidth, entry.width * 0.35)
                    text: entry.modelData.when
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }
    }

    // Fehlertext von git/cargo (Pull abgelehnt, Build gescheitert)
    Rectangle {
        width: parent.width
        visible: ShellUpdate.updateError !== "" && (ShellUpdate.updateFailed || ShellUpdate.buildWarned) && !card.updating
        height: visible ? errorColumn.implicitHeight + 20 : 0
        radius: 12
        color: Colors.alpha(Colors.error, 0.08)

        Column {
            id: errorColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 6

            Text {
                width: parent.width
                visible: ShellUpdate.buildWarned && !ShellUpdate.updateFailed
                text: I18n.tr("Die Rust-Helfer konnten nicht neu gebaut werden – die alten bleiben. Später ./install.sh ausführen.")
                color: Colors.fgBackground
                font.family: Config.font
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                text: ShellUpdate.updateError
                color: Colors.error
                font.family: Config.font
                font.pixelSize: 10
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                visible: ShellUpdate.updateFailed && card.conflictHint
                text: I18n.tr("Eigene Änderungen an diesen Dateien zuerst sichern (git stash) – siehe README, Abschnitt „Updating“.")
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
    }

    // Eigene Aenderungen (git status), zugeklappt
    Item {
        width: parent.width
        visible: ShellUpdate.localCount > 0
        height: visible ? 22 : 0

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                color: Colors.fgSurfaceVariant
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                rotation: card.changesOpen ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ShellUpdate.localCount === 1
                    ? I18n.tr("1 eigene Änderung im Repo")
                    : I18n.tr("%1 eigene Änderungen im Repo").arg(ShellUpdate.localCount)
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: card.changesOpen = !card.changesOpen
        }
    }

    Item {
        width: parent.width
        height: card.changesOpen && ShellUpdate.localCount > 0 ? Math.min(160, changes.contentHeight) : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
        }

        ListView {
            id: changes

            anchors.fill: parent
            spacing: 0
            cacheBuffer: 2000
            boundsBehavior: Flickable.StopAtBounds
            model: ShellUpdate.localChanges

            delegate: Item {
                id: change

                required property var modelData

                width: changes.width
                height: 20

                Text {
                    id: statusLabel

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22
                    text: change.modelData.status
                    color: Colors.primary
                    font.family: Config.font
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors {
                        left: statusLabel.right
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: change.modelData.file
                    color: Colors.fgBackground
                    font.family: Config.font
                    font.pixelSize: 10
                    elide: Text.ElideLeft
                }
            }
        }
    }

    // Knoepfe
    Item {
        width: parent.width
        height: 28

        ActionChip {
            anchors.left: parent.left
            icon: "restart_alt"
            label: I18n.tr("Shell neu starten")
            enabled: !card.updating
            onClicked: ShellUpdate.restart()
        }

        Row {
            anchors.right: parent.right
            spacing: 6

            ActionChip {
                icon: "refresh"
                label: I18n.tr("Nach Updates suchen")
                enabled: !card.checking && !card.updating
                onClicked: ShellUpdate.check(true)
            }

            ActionChip {
                icon: "system_update_alt"
                label: card.updating ? I18n.tr("Läuft…") : I18n.tr("Aktualisieren")
                filled: true
                enabled: ShellUpdate.canUpdate
                onClicked: ShellUpdate.update()
            }
        }
    }
}
