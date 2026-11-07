pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs
import qs.modules.services.config
import qs.modules.services.hypr
import qs.modules.settings.keybinds
import "keybinds/KeyLayout.js" as Layout

// Einstellungsseite Tastenkürzel (Config.meta editor "keybinds").
//
// Oben die Tastatur-Vorschau: sie zeigt je Ebene (Modifier-Maske, Klick auf
// Super/Strg/Alt/Shift schaltet) was auf jeder Taste liegt; die Tasten des
// gewaehlten Befehls leuchten. Darunter links die Liste aller Befehle (Suche,
// Filter), rechts der gewaehlte Befehl mit seinen Kombinationen und den
// Knoepfen zum Neu-Belegen, An/Aus, Zuruecksetzen, Entfernen.
//
// Zwei Wege zu einer neuen Belegung: Aufnehmen (KeyCapture, Hyprland steht
// solange in einer leeren Submap, Esc bricht ab) oder "Auf Tastatur wählen"
// (`pick`): der naechste Klick auf eine freie Taste der Vorschau speichert
// Ebene + Taste. Beides schreibt ueber Keybinds.qml in keybinds.json.
Item {
    id: editor

    implicitHeight: content.implicitHeight

    // ---- Zustand ----
    property string selectedId: ""
    property int mask: 64
    // Laufendes "Auf Tastatur wählen": { mode, ref, title, payload } | null
    property var pick: null
    property string pickError: ""
    property bool adding: false
    property alias listQuery: list.queryText

    readonly property var selected: HyprBinds.commands.find(c => c.id === editor.selectedId) ?? null
    // Waehrend der Aufnahme folgt die Ebene den gehaltenen Modifiern
    readonly property int shownMask: capture.active ? capture.heldMask : editor.mask
    readonly property bool narrow: editor.width < 680
    readonly property real paneHeight: 420

    // Canon "64:q" -> Belegung, einmal fuer alle Ebenen
    readonly property var index: {
        const out = {};
        for (const c of HyprBinds.commands)
            for (const combo of c.combos)
                out[combo.canon] = { id: c.id, title: c.title, group: c.group, disabled: combo.disabled, changed: combo.changed, source: combo.source, unnamed: false };
        for (const u of HyprBinds.unnamed)
            if (!out[u.canon])
                out[u.canon] = { id: "", title: "", group: "", disabled: false, changed: false, source: "config", unnamed: true };
        return out;
    }

    // Volltext je Befehl fuer die Suche: Titel/Text/Gruppe (deutsch und
    // uebersetzt), Tasten, Befehlstext
    readonly property var searchIndex: {
        const out = {};
        for (const c of HyprBinds.commands) {
            const parts = [c.title, I18n.tr(c.title), c.text, I18n.tr(c.text), c.group, I18n.tr(c.group), c.pluginName];
            for (const combo of c.combos)
                parts.push(combo.keysText, combo.keys.join(" "));
            const action = HyprBinds.actionOf(c);
            if (action)
                parts.push(action.text);
            out[c.id] = parts.join(" ").toLowerCase();
        }
        return out;
    }

    // Tasten des gewaehlten Befehls (Modifier links + Taste jeder Kombination)
    readonly property var litKeys: {
        const out = {};
        if (!editor.selected)
            return out;
        for (const combo of editor.selected.combos) {
            out[combo.key] = true;
            if (combo.modmask & 64)
                out.super_l = true;
            if (combo.modmask & 4)
                out.control_l = true;
            if (combo.modmask & 8)
                out.alt_l = true;
            if (combo.modmask & 1)
                out.shift_l = true;
        }
        return out;
    }

    function select(id: string): void {
        editor.selectedId = id;
        const c = HyprBinds.commands.find(x => x.id === id);
        if (c && c.combos.length > 0)
            editor.mask = c.combos[0].modmask;
        list.scrollTo(id);
    }

    function startPick(mode: string, ref: string, title: string, payload: var): void {
        capture.cancel();
        editor.pick = { mode, ref, title, payload: payload ?? null };
        editor.pickError = "";
    }

    function cancelPick(): void {
        editor.pick = null;
        editor.pickError = "";
    }

    // Klick auf eine Taste der Vorschau
    function keyClicked(id: string): void {
        const canon = `${editor.mask}:${id}`;
        const info = editor.index[canon] ?? null;
        if (editor.pick) {
            // Die eigene Taste noch einmal waehlen ist kein Konflikt
            const own = editor.pick.mode === "set" && info && !info.unnamed
                && HyprBinds.commands.some(c => c.combos.some(x => x.canon === canon && x.ref === editor.pick.ref));
            if (info && !own) {
                editor.pickError = I18n.tr("Schon belegt: %1").arg(info.unnamed ? I18n.tr("einem Bind ohne Beschreibung") : `${I18n.tr(info.group)} › ${I18n.tr(info.title)}`);
                return;
            }
            const plain = editor.mask & (64 | 4 | 8);
            if (plain === 0 && !Layout.standalone(id)) {
                editor.pickError = I18n.tr(editor.mask & 1 ? "Nur Shift reicht nicht – das braucht man zum Tippen" : "Ohne Super/Strg/Alt nur F-Tasten, Druck und Medientasten");
                return;
            }
            const error = capture.saveAs(editor.pick.mode, editor.pick.ref, Layout.keysText(editor.mask, id), editor.pick.payload);
            if (error !== "") {
                editor.pickError = error;
                return;
            }
            if (editor.pick.mode === "new")
                editor.closeForm();
            editor.pick = null;
            editor.pickError = "";
            return;
        }
        if (info && !info.unnamed)
            editor.select(info.id);
    }

    function closeForm(): void {
        editor.adding = false;
        newName.text = "";
        newExec.text = "";
    }

    readonly property bool formReady: newName.text.trim() !== "" && newExec.text.trim() !== ""

    Component.onCompleted: HyprBinds.refresh()
    onVisibleChanged: if (visible) HyprBinds.refresh()
    Component.onDestruction: capture.cancel()

    // ---- Aufnahme ----
    KeyCapture {
        id: capture

        onFinished: {
            editor.closeForm();
            if (editor.selected && editor.selected.combos.length > 0)
                editor.mask = editor.selected.combos[0].modmask;
        }
    }

    Connections {
        target: capture

        function onActiveChanged(): void {
            if (capture.active) {
                editor.pick = null;
                editor.pickError = "";
                catcher.forceActiveFocus();
            }
        }
    }

    Item {
        id: catcher

        focus: capture.active
        Keys.onPressed: e => capture.press(e)
        Keys.onReleased: e => capture.release(e)
    }

    // Hyprland-Profil: Aenderungen wirken nur unter "simple"
    property string profile: "simple"

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/profile"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: editor.profile = text().trim()
    }

    Column {
        id: content

        width: parent.width
        spacing: 12
        bottomPadding: 6

        // ---- Hinweis: anderes Profil ----
        Rectangle {
            width: parent.width
            visible: editor.profile !== "" && editor.profile !== "simple"
            height: visible ? profileText.implicitHeight + 20 : 0
            radius: 10
            color: Colors.alpha(Colors.tertiary, 0.12)
            border.width: 1
            border.color: Colors.alpha(Colors.tertiary, 0.4)

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: "warning"
                color: Colors.tertiary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
            }

            Text {
                id: profileText

                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 40
                    rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text: I18n.tr("Hyprland läuft mit dem Profil „%1“ – Änderungen hier wirken erst im Profil „simple“.").arg(editor.profile)
                color: Colors.fgSurface
                font.family: Config.font
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }

        // ---- Banner: Aufnahme / Auf Tastatur wählen ----
        Rectangle {
            id: banner

            readonly property bool shown: capture.active || editor.pick !== null
            readonly property string error: capture.active ? capture.error : editor.pickError

            width: parent.width
            height: banner.shown ? 48 : 0
            visible: height > 0
            clip: true
            radius: 10
            color: Colors.alpha(Colors.primary, 0.1)
            border.width: 1
            border.color: Colors.alpha(Colors.primary, 0.45)

            Behavior on height {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
            }

            Text {
                id: bannerIcon

                anchors {
                    left: parent.left
                    leftMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                text: capture.active ? "radio_button_checked" : "ads_click"
                color: capture.active && capture.done === "" ? Colors.error : Colors.primary
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
            }

            Row {
                anchors {
                    left: bannerIcon.right
                    leftMargin: 10
                    right: bannerCancel.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (capture.active)
                            return capture.done !== "" ? I18n.tr("„%1“ liegt jetzt auf").arg(capture.title)
                                 : I18n.tr("Drücke die neue Kombination für „%1“ – Esc bricht ab").arg(capture.title);
                        if (editor.pick)
                            return I18n.tr("Klicke eine freie Taste für „%1“ – Super, Strg, Alt und Shift wechseln die Ebene").arg(editor.pick.title);
                        return "";
                    }
                    color: Colors.fgSurface
                    font.family: Config.font
                    font.pixelSize: 12
                }

                Repeater {
                    model: capture.active ? (capture.done !== "" ? capture.done.split("+").map(p => {
                        const t = p.trim();
                        const names = { SUPER: "Super", CTRL: I18n.tr("Strg"), ALT: "Alt", SHIFT: "Shift" };
                        return names[t] ?? HyprBinds.keyLabel(t) ?? t;
                    }) : capture.held) : []

                    Keycap {
                        required property string modelData

                        anchors.verticalCenter: parent?.verticalCenter
                        text: I18n.tr(modelData)
                        accent: capture.done !== ""
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: capture.active && capture.done === "" && capture.held.length > 0
                    text: "+ …"
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: banner.error !== ""
                    text: banner.error
                    color: Colors.error
                    font.family: Config.font
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            KbChip {
                id: bannerCancel

                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                size: 26
                icon: "close"
                label: I18n.tr("Abbrechen")
                onClicked: {
                    capture.cancel();
                    editor.cancelPick();
                }
            }
        }

        // ---- Ebene + Legende ----
        Item {
            width: parent.width
            height: 26

            Row {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Ebene")
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    rightPadding: 2
                }

                Repeater {
                    model: Layout.modLabels(editor.shownMask)

                    Keycap {
                        required property string modelData

                        anchors.verticalCenter: parent?.verticalCenter
                        text: I18n.tr(modelData)
                        size: 20
                        accent: true
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: editor.shownMask === 0
                    text: I18n.tr("ohne Modifier")
                    color: Colors.fgSurfaceVariant
                    font.family: Config.font
                    font.pixelSize: 11
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+ …"
                    color: Colors.alpha(Colors.fgSurfaceVariant, 0.6)
                    font.family: Config.font
                    font.pixelSize: 11
                }
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 12

                Repeater {
                    model: [
                        { color: Colors.primary, label: "Geändert" },
                        { color: Colors.secondary, label: "Plugin" },
                        { color: Colors.tertiary, label: "Eigenes" }
                    ]

                    Row {
                        id: legend

                        required property var modelData

                        spacing: 5

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: legend.modelData.color
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr(legend.modelData.label)
                            color: Colors.fgSurfaceVariant
                            font.family: Config.font
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // ---- Tastatur ----
        VirtualKeyboard {
            id: board

            width: parent.width
            mask: editor.shownMask
            index: editor.index
            litKeys: editor.litKeys
            pick: editor.pick !== null
            interactive: !capture.active
            onKeyClicked: id => editor.keyClicked(id)
            onModifierToggled: bit => editor.mask = editor.mask ^ bit
        }

        // ---- Eigenes Kuerzel ----
        Rectangle {
            width: parent.width
            height: editor.adding ? 48 : 0
            visible: height > 0
            clip: true
            radius: 10
            color: Colors.alpha(Colors.fgSurface, 0.04)
            border.width: 1
            border.color: Colors.alpha(Colors.outline, 0.2)

            Behavior on height {
                NumberAnimation { duration: Appearance.fadeDuration; easing.type: Easing.OutCubic }
            }

            Row {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                KbField {
                    id: newName

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(140, parent.width * 0.26)
                    icon: "label"
                    placeholder: I18n.tr("Name")
                    onAccepted: newExec.input.forceActiveFocus()
                    onEscaped: editor.closeForm()
                }

                KbField {
                    id: newExec

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - newName.width - newRecord.width - newPick.width - newClose.width - parent.spacing * 4
                    icon: "terminal"
                    placeholder: I18n.tr("Befehl, z.B. kitty btop")
                    mono: true
                    onAccepted: if (editor.formReady) newRecord.clicked()
                    onEscaped: editor.closeForm()
                }

                KbChip {
                    id: newRecord

                    anchors.verticalCenter: parent.verticalCenter
                    enabled: editor.formReady
                    icon: "radio_button_checked"
                    label: I18n.tr("Aufnehmen")
                    primary: true
                    onClicked: capture.start("new", "", newName.text.trim(), { title: newName.text.trim(), exec: newExec.text.trim() })
                }

                KbChip {
                    id: newPick

                    anchors.verticalCenter: parent.verticalCenter
                    enabled: editor.formReady
                    icon: "ads_click"
                    label: I18n.tr("Auf Tastatur wählen")
                    onClicked: editor.startPick("new", "", newName.text.trim(), { title: newName.text.trim(), exec: newExec.text.trim() })
                }

                KbIconButton {
                    id: newClose

                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    onClicked: editor.closeForm()
                }
            }
        }

        // ---- Liste + Details ----
        Item {
            width: parent.width
            height: editor.narrow ? editor.paneHeight * 2 + 12 : editor.paneHeight

            CommandList {
                id: list

                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: editor.narrow ? parent.width : Math.max(300, Math.round(parent.width * 0.45))
                height: editor.paneHeight
                selectedId: editor.selectedId
                searchIndex: editor.searchIndex
                adding: editor.adding
                onSelected: id => editor.select(id)
                onAddToggled: {
                    editor.adding = !editor.adding;
                    if (editor.adding)
                        newName.input.forceActiveFocus();
                }
            }

            CommandDetail {
                anchors {
                    left: editor.narrow ? parent.left : list.right
                    right: parent.right
                    top: editor.narrow ? list.bottom : parent.top
                    leftMargin: editor.narrow ? 0 : 12
                    topMargin: editor.narrow ? 12 : 0
                }
                height: editor.paneHeight
                command: editor.selected
                capture: capture
                onPickRequested: (mode, ref, title, payload) => editor.startPick(mode, ref, title, payload)
            }
        }
    }
}
