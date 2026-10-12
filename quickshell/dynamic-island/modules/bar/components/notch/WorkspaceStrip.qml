pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs
import qs.modules.services.config
import qs.modules.widgets
import "SpecialIcons.js" as SpecialIcons

// Workspace-Leiste in der aufgeklappten Notch (Uebersicht): Nummern der
// Workspaces dieses Monitors zum Anklicken, dahinter die Special-Workspaces
// als Symbole (Klick toggelt sie). Der aktive Workspace ist eine breite Pille
// in der Akzentfarbe, ein offener Special die tertiaere Pille.
//
// Dieselbe Gruppenlogik wie WorkspaceSelector.qml und NotchWorkspaces.qml
// (bar.workspaceCount je Monitor). Die Hyprland-Listen haelt der
// WorkspaceSelector frisch (refreshWorkspaces/-Monitors bei Events) – er
// existiert auch im Notch-Layout, nur unsichtbar.
Item {
    id: root

    readonly property int perMonitor: Math.max(1, Math.min(10, Config.bar.workspaceCount))
    readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(root.QsWindow.window?.screen ?? null)
    readonly property int activeId: root.hyprMonitor?.activeWorkspace?.id ?? 1
    readonly property int groupOffset: Math.floor((root.activeId - 1) / root.perMonitor) * root.perMonitor
    readonly property string activeSpecial: root.hyprMonitor?.lastIpcObject.specialWorkspace?.name ?? ""

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hyprland.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    readonly property var specials: Hyprland.workspaces.values
        .filter(w => w.name.startsWith("special:"))
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property real chip: 26

    implicitWidth: content.implicitWidth + 12
    implicitHeight: 34

    function dispatch(lua: string, legacy: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.alpha(Colors.fgBackground, 0.05)
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 4

        // ---- normale Workspaces ----
        Repeater {
            model: root.perMonitor

            Item {
                id: slot

                required property int index
                readonly property int ws: root.groupOffset + slot.index + 1
                readonly property bool active: slot.ws === root.activeId && root.activeSpecial === ""
                readonly property bool current: slot.ws === root.activeId
                readonly property bool used: root.occupied[slot.ws] ?? false

                width: slot.current ? root.chip + 14 : root.chip
                height: root.chip

                Behavior on width {
                    NumberAnimation { duration: Appearance.morphDuration * 0.6; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: slot.current ? (root.activeSpecial === "" ? Colors.primary : Colors.alpha(Colors.primary, 0.35))
                         : slotHover.hovered ? Colors.alpha(Colors.fgBackground, 0.16)
                         : slot.used ? Colors.alpha(Colors.fgBackground, 0.09)
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    // Anzeige je Monitor 1..n (wie die Hypr-Config sie zaehlt)
                    text: slot.index + 1
                    color: slot.current ? Colors.fgPrimary
                         : slot.used || slotHover.hovered ? Colors.fgBackground
                         : Colors.alpha(Colors.fgSurfaceVariant, 0.55)
                    font.family: Config.font
                    font.pixelSize: 12
                    font.weight: slot.current ? Font.Bold : Font.DemiBold
                }

                HoverHandler {
                    id: slotHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        // Liegt gerade ein Special drueber, erst den schliessen –
                        // sonst wechselt nur der Workspace darunter
                        if (root.activeSpecial !== "") {
                            const key = root.activeSpecial.slice("special:".length);
                            root.dispatch(`hl.dsp.workspace.toggle_special("${key}")`,
                                          `togglespecialworkspace ${key}`);
                        }
                        if (slot.ws !== root.activeId)
                            root.dispatch(`hl.dsp.focus({ workspace = ${slot.ws} })`, `workspace ${slot.ws}`);
                    }
                }
            }
        }

        // ---- Trenner ----
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.specials.length > 0
            width: 1
            height: 16
            color: Colors.alpha(Colors.fgBackground, 0.15)
        }

        Item {
            visible: root.specials.length > 0
            width: 2
            height: 1
        }

        // ---- Special-Workspaces ----
        Repeater {
            model: root.specials

            Item {
                id: special

                required property var modelData   // HyprlandWorkspace
                readonly property string key: special.modelData.name.slice("special:".length)
                readonly property bool active: root.activeSpecial === special.modelData.name
                readonly property bool used: special.modelData.lastIpcObject.windows > 0

                width: special.active ? root.chip + 14 : root.chip
                height: root.chip

                Behavior on width {
                    NumberAnimation { duration: Appearance.morphDuration * 0.6; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: special.active ? Colors.tertiary
                         : specialHover.hovered ? Colors.alpha(Colors.fgBackground, 0.16)
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Appearance.fadeDuration }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: SpecialIcons.iconFor(special.key)
                    color: special.active ? Colors.fgTertiary
                         : special.used || specialHover.hovered ? Colors.fgBackground
                         : Colors.alpha(Colors.fgSurfaceVariant, 0.55)
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 15
                    font.variableAxes: ({ FILL: special.active ? 1 : 0 })
                }

                HoverHandler {
                    id: specialHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.dispatch(`hl.dsp.workspace.toggle_special("${special.key}")`,
                                            `togglespecialworkspace ${special.key}`)
                }
            }
        }
    }
}
