pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower

import qs
import qs.modules.services.config

// Akku und Energieprofile.
//
// Beides kommt fertig aus Quickshell (Quickshell.Services.UPower) – weder
// `upower` noch `powerprofilesctl` muessen aufgerufen werden, `profile` ist
// sogar schreibbar.
//
// Zwei Fallen stecken in der UPower-API:
//   * `percentage` ist 0…1, nicht 0…100.
//   * Ohne Systemakku gibt es das `displayDevice` trotzdem – hier mit Typ
//     "unknown" und 0 %. Der richtige Test ist `isLaptopBattery`, nicht die
//     Prozentzahl.
//
// Benutzung:  import qs.modules.services.system
Singleton {
    id: root

    readonly property bool hasSystemBattery: UPower.displayDevice?.isLaptopBattery ?? false

    // Akkus in Geraeten (Maus, Tastatur, Headset ...) – am Desktop das
    // einzige, was es zu zeigen gibt
    readonly property var deviceBatteries: {
        const wanted = [UPowerDeviceType.Mouse, UPowerDeviceType.Keyboard, UPowerDeviceType.Headset,
            UPowerDeviceType.Headphones, UPowerDeviceType.GamingInput, UPowerDeviceType.Pen,
            UPowerDeviceType.Tablet, UPowerDeviceType.Speakers];

        const out = [];
        for (const d of UPower.devices?.values ?? [])
            if (d?.isPresent && wanted.includes(d.type))
                out.push(d);

        out.sort((a, b) => a.percentage - b.percentage);   // schwaechster zuerst
        return out;
    }

    // Schluessel eines Akkus fuer die Einstellung bar.batteryDevice. UPower
    // kennt keine Seriennummer; das Modell ueberlebt Neuverbindungen,
    // hidpp_battery_N dagegen zaehlt bei jedem Einstecken hoch.
    function deviceKey(device: var): string {
        return device?.model || device?.nativePath || "";
    }

    // Welcher Akku angezeigt wird (bar.batteryDevice):
    //   "auto"    Systemakku, sonst der schwaechste Geraete-Akku
    //   "system"  nur der Systemakku
    //   Modell    genau dieses Geraet ("Logitech G502 X PLUS")
    // Fehlt das gewaehlte Geraet (Maus aus), zeigt die Leiste gar keinen
    // Akku – ein anderer Wert unter demselben Symbol waere irrefuehrend.
    readonly property string target: Config.bar.batteryDevice || "auto"
    readonly property var shown: {
        if (root.target === "auto")
            return root.hasSystemBattery ? UPower.displayDevice : (root.deviceBatteries[0] ?? null);
        if (root.target === "system")
            return root.hasSystemBattery ? UPower.displayDevice : null;
        return root.deviceBatteries.find(d => root.deviceKey(d) === root.target) ?? null;
    }
    readonly property bool hasBattery: root.shown !== null
    // Zeigt die Anzeige den Systemakku oder ein Geraet (dann gehoert das
    // Geraetesymbol dazu)?
    readonly property bool showsSystem: root.hasBattery && root.shown === UPower.displayDevice

    // Auswahl fuer das Einstellungs-Menue (Config.meta source "batteries"):
    // Automatisch, Systemakku und alle Geraete, alphabetisch – nach Ladestand
    // sortiert sprangen die Chips bei jeder Aenderung umher
    readonly property var targetChoices: {
        const devices = root.deviceBatteries.map(d => root.deviceKey(d)).filter(k => k !== "");
        return ["auto"].concat(root.hasSystemBattery ? ["system"] : [],
                               [...new Set(devices)].sort((a, b) => a.localeCompare(b)));
    }
    readonly property var targetLabels: ({
        "auto": I18n.tr("Automatisch"),
        "system": I18n.tr("Systemakku")
    })

    readonly property int percent: Math.round((root.shown?.percentage ?? 0) * 100)
    readonly property bool activelyCharging: root.hasBattery
        && root.shown.state === UPowerDeviceState.Charging
    // UPower meldet die momentane Energieaenderung in Watt.
    readonly property real chargeRate: root.activelyCharging
        ? Math.max(0, root.shown.changeRate ?? 0) : 0
    readonly property bool charging: {
        const s = root.shown?.state ?? UPowerDeviceState.Unknown;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged
            || s === UPowerDeviceState.PendingCharge;
    }

    // Stufen, nach denen sich Farbe und Warnung richten. Am Kabel ist nichts
    // knapp – auch nicht, wenn ein Geraet dabei Unsinn meldet (die G915
    // sagt "fully-charged" bei 12 %).
    //   kritisch  unter 10 %   rot, Warnung
    //   knapp     bis 20 %     Mischton, Warnung
    readonly property bool critical: root.hasBattery && !root.charging && root.percent < 10
    readonly property bool low: root.hasBattery && !root.charging && root.percent <= 20

    // Material-Symbol fuer den Akkustand (fuer Stellen, die nur Symbole
    // setzen; sonst BatteryGlyph). Die Stufen sind ungleich breit: unten
    // fein, damit "fast leer" frueh zu sehen ist, oben grob.
    readonly property string batteryIcon: {
        if (!root.hasBattery)
            return "battery_unknown";
        const p = root.percent;
        if (root.charging) {
            // Material Symbols hat nur diese Ladestufen; Namen wie
            // battery_charging_40 erscheinen sonst als Klartext.
            const steps = [[95, "full"], [85, "90"], [70, "80"], [55, "60"], [40, "50"], [25, "30"]];
            const hit = steps.find(s => p >= s[0]);
            return `battery_charging_${hit ? hit[1] : "20"}`;
        }
        const steps = [[95, "full"], [80, "6_bar"], [65, "5_bar"], [50, "4_bar"],
                       [35, "3_bar"], [20, "2_bar"], [10, "1_bar"], [5, "0_bar"]];
        const hit = steps.find(s => p >= s[0]);
        return hit ? `battery_${hit[1]}` : "battery_alert";
    }

    // Womit der Akku steckt – am Desktop sagt "Maus" mehr als ein Akku-Symbol
    function deviceIcon(device: var): string {
        switch (device?.type ?? UPowerDeviceType.Unknown) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "headphones";
        case UPowerDeviceType.GamingInput:
            return "sports_esports";
        default:
            return "battery_full";
        }
    }

    function deviceName(device: var): string {
        const model = device?.model ?? "";
        if (model !== "")
            return model;
        return UPowerDeviceType.toString(device?.type ?? UPowerDeviceType.Unknown);
    }

    // ---- Energieprofile ----
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property bool degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    readonly property string degradedReason: PerformanceDegradationReason.toString(PowerProfiles.degradationReason)

    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, icon: "energy_savings_leaf", label: I18n.tr("Sparen") },
        { value: PowerProfile.Balanced, icon: "balance", label: I18n.tr("Ausgewogen") },
        { value: PowerProfile.Performance, icon: "rocket_launch", label: I18n.tr("Leistung") }
    ]

    function setProfile(value: int): void {
        PowerProfiles.profile = value;
    }
}
