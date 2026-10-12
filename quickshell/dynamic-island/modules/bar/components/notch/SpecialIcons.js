// Symbole der Special-Workspaces (Material Symbols), dieselben Defaults wie
// workspaceSelector/SpecialWorkspaces.qml bzw. caelestias utils/Icons.qml.
// "special:music" -> key "music". Unbekannte bekommen ihren Anfangsbuchstaben.
.pragma library

function iconFor(key) {
    const map = {
        "special": "star",
        "communication": "forum",
        "music": "music_cast",
        "todo": "checklist",
        "sysmon": "monitor_heart"
    };
    return map[key] ?? key.charAt(0).toUpperCase();
}
