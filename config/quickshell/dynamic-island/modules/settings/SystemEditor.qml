pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.modules.services.config
import qs.modules.services.core
import qs.modules.services.system
import qs.modules.services.plugins
import qs.modules.settings.system

// Einstellungsseite System (Config.meta editor "system") – die "Über"-Seite
// der Shell, nach dem Vorbild von Caelestias AboutPage.
//
// Oben der Kopf: Logo (die Notch als Pille), "Dynamic Island" und die
// Versionszeile (git describe · Datum · Branch). Darunter die Karten:
//   Update    – Stand gegenueber dem Upstream, neue Commits, eigene
//               Aenderungen, "Nach Updates suchen" / "Aktualisieren" /
//               "Shell neu starten" (ShellUpdateCard, Dienst ShellUpdate)
//   System    – Hostname, Geraet, Distribution, Kernel, Firmware, CPU, GPU,
//               RAM, Pakete, Laufzeit (SystemInfo)
//   Software  – Shell-Commit, CLI, Quickshell, Qt, Hyprland
//   Plugins   – wie viele geladen sind und welche
//
// SystemInfo liest seine festen Daten und ShellUpdate den Git-Stand, sobald
// die Seite offen ist (DemandRequest, Muster Bar.qml). Die Bausteine
// (InfoLine, ActionChip, SectionCard, ShellUpdateCard) liegen in
// settings/system/ – eine Inline-`component` in einer schon geladenen Datei
// loest erst nach einem Neustart der Shell auf.
Item {
    id: editor

    implicitHeight: content.implicitHeight

    readonly property int gap: 12

    readonly property string versionLine: {
        if (!ShellUpdate.loaded)
            return "…";
        if (ShellUpdate.repo === "")
            return I18n.tr("Kein Git-Repo");
        const parts = [];
        if (ShellUpdate.describe !== "")
            parts.push(ShellUpdate.describe);
        if (ShellUpdate.commitDate !== "")
            parts.push(Qt.formatDate(new Date(ShellUpdate.commitDate + "T12:00:00"), "d. MMM yyyy"));
        if (ShellUpdate.branch !== "")
            parts.push(ShellUpdate.branch);
        return parts.join("  ·  ");
    }

    readonly property var enabledPlugins: Plugins.plugins.filter(p => p.enabled)

    DemandRequest {
        demand: SystemInfo.demand
        active: editor.visible
    }

    DemandRequest {
        demand: ShellUpdate.demand
        active: editor.visible
    }

    Column {
        id: content

        width: parent.width
        spacing: editor.gap
        bottomPadding: 4

        // ---- Kopf: Logo, Name, Version ----
        Item {
            width: parent.width
            height: 64

            Rectangle {
                id: logo

                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                radius: 16
                color: Colors.alpha(Colors.primary, 0.14)

                // Die Notch: eine Pille mit Kamera-Punkt
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 13
                    radius: height / 2
                    color: Colors.primary

                    Rectangle {
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Colors.alpha(Colors.fgPrimary, 0.8)
                    }
                }
            }

            Column {
                anchors {
                    left: logo.right
                    leftMargin: 14
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                Text {
                    width: parent.width
                    text: "Dynamic Island"
                    color: Colors.fgBackground
                    font.family: Config.font
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: editor.versionLine
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        ShellUpdateCard {
            width: parent.width
        }

        // ---- System ----
        SectionCard {
            width: parent.width
            title: I18n.tr("System")
            spacing: 0

            InfoLine {
                label: I18n.tr("Hostname")
                value: SystemInfo.hostname
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Gerät")
                value: SystemInfo.device
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Distribution")
                value: SystemInfo.distro
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Kernel")
                value: SystemInfo.kernel
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Firmware")
                value: SystemInfo.firmware
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "CPU"
                value: SystemInfo.cpuName
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "GPU"
                value: SystemInfo.gpuName
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "RAM"
                value: SystemInfo.memTotal > 0 ? SystemStats.formatBytes(SystemInfo.memTotal) : ""
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Pakete")
                value: SystemInfo.packages > 0
                    ? `${SystemInfo.packages} pacman` + (SystemInfo.hasFlatpak ? ` · ${SystemInfo.flatpaks} Flatpak` : "")
                    : ""
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: I18n.tr("Laufzeit")
                value: SystemInfo.uptime > 0 ? SystemInfo.formatUptime(SystemInfo.uptime) : ""
                pending: SystemInfo.uptime === 0
                last: true
            }
        }

        // ---- Software ----
        SectionCard {
            width: parent.width
            title: I18n.tr("Software")
            spacing: 0

            InfoLine {
                label: I18n.tr("Shell")
                value: ShellUpdate.commit !== ""
                    ? ShellUpdate.commit + (ShellUpdate.commitAge !== "" ? `  (${ShellUpdate.commitAge})` : "")
                    : ""
                pending: !ShellUpdate.loaded
            }

            InfoLine {
                label: "CLI"
                value: SystemInfo.cliKind !== ""
                    ? (SystemInfo.cliVersion !== "" ? `${SystemInfo.cliVersion} · ` : "") + SystemInfo.cliKind
                    : ""
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "Quickshell"
                value: SystemInfo.quickshell
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "Qt"
                value: SystemInfo.qt
                pending: !SystemInfo.loaded
            }

            InfoLine {
                label: "Hyprland"
                value: SystemInfo.hyprland
                pending: !SystemInfo.loaded
                last: true
            }
        }

        // ---- Plugins ----
        SectionCard {
            width: parent.width
            title: I18n.tr("Plugins")
            spacing: 0

            InfoLine {
                label: I18n.tr("Geladene Plugins")
                value: Plugins.plugins.length === 0
                    ? I18n.tr("keine")
                    : I18n.tr("%1 von %2").arg(editor.enabledPlugins.length).arg(Plugins.plugins.length)
                accent: editor.enabledPlugins.length > 0
                last: editor.enabledPlugins.length === 0
            }

            Text {
                width: parent.width
                visible: editor.enabledPlugins.length > 0
                topPadding: 8
                bottomPadding: 4
                text: editor.enabledPlugins.map(p => p.name).join("  ·  ")
                color: Colors.fgSurfaceVariant
                font.family: Config.font
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
    }
}
