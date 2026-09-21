-- Hyprland-Hauptconfig: Monitore + Profil-Weiche.
--
--   ~/.config/hypr/profile             Name des aktiven Profils
--   ~/.config/hypr/profiles/*.lua      die Profile selbst
--   ~/.local/bin/hypr-profile          Umschalter (Shell-Script)
--
-- Umschalten im laufenden Betrieb:  CTRL + SUPER + SHIFT + P (schaltet durch)
-- oder im Terminal:                 hypr-profile [<name>|toggle|status]
--
-- caelestia = volle Config + Caelestia-Quickshell-Shell (Bar, Notifications, Wallpaper)
-- simple    = eine schlanke Datei mit den wichtigsten Einstellungen, Shell dynamic-island
-- shell2    = dieselbe schlanke Basis, aber mit der neuen Shell shell2
--
-- Ein weiteres Profil braucht nur profiles/<name>.lua und einen Eintrag in
-- hypr-profile (PROFILE_SHELL + PROFILE_ORDER) — hier ist nichts zu aendern.

local home            = os.getenv("HOME")
local hypr            = home .. "/.config/hypr"
local profileFile     = hypr .. "/profile"
local defaultProfile  = "caelestia"
local switchBind      = "CTRL + SUPER + SHIFT + P"

--------------------------------------------------------------------------------
-- Monitore (gelten fuer beide Profile)
--------------------------------------------------------------------------------
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "2560x1440@60",
    position = "0x0",
    scale    = 1,
    vrr      = false,
})

hl.monitor({
    output   = "DP-1",
    mode     = "2560x1440@180",
    position = "2560x0",
    scale    = 1,
})

hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

--------------------------------------------------------------------------------
-- Profil bestimmen
--------------------------------------------------------------------------------
local function read_profile()
    local f = io.open(profileFile)
    if not f then
        return defaultProfile
    end

    local name = (f:read("*l") or ""):gsub("%s", "")
    f:close()

    -- Gueltig ist jeder schlichte Name, zu dem es auch eine Profildatei gibt.
    -- Das Muster haelt Pfadtrenner und Punkte heraus, damit `require` nicht
    -- irgendwo anders im Dateisystem landet.
    if name:match("^[%w_%-]+$") then
        local profileLua = io.open(hypr .. "/profiles/" .. name .. ".lua")
        if profileLua then
            profileLua:close()
            return name
        end
    end
    return defaultProfile
end

local function write_profile(name)
    local f = io.open(profileFile, "w")
    if f then
        f:write(name .. "\n")
        f:close()
    end
end

-- Bei `hyprctl reload` laeuft diese Datei erneut, `require` wuerde die Module aber
-- aus dem Cache nehmen und nichts mehr setzen. Darum vorher gezielt entladen.
local function flush_modules()
    for key in pairs(package.loaded) do
        if key == "variables"
            or key == "hypr-vars"
            or key == "hypr-user"
            or key:match("^hyprland%.")
            or key:match("^scheme%.")
            or key:match("^profiles%.")
        then
            package.loaded[key] = nil
        end
    end
end

local function load_profile(name)
    flush_modules()
    return pcall(require, "profiles." .. name)
end

local profile = read_profile()
local ok, err = load_profile(profile)

if not ok then
    local msg = "Hyprland-Profil '" .. profile .. "' fehlerhaft: " .. tostring(err)
    io.stderr:write(msg .. "\n")
    hl.exec_cmd("hyprctl notify -1 10000 'rgb(ff4444)' " .. string.format("%q", msg))

    -- Zurueck auf das Standardprofil, damit der naechste Start wieder hochkommt
    if profile ~= defaultProfile then
        write_profile(defaultProfile)
        local okFallback, errFallback = load_profile(defaultProfile)
        if not okFallback then
            io.stderr:write("Fallback-Profil ebenfalls fehlerhaft: " .. tostring(errFallback) .. "\n")
        end
    end
end

--------------------------------------------------------------------------------
-- Profil-Umschalter (nach dem Profil gesetzt, damit er immer gewinnt)
--------------------------------------------------------------------------------
hl.bind(switchBind, hl.dsp.exec_cmd(home .. "/.local/bin/hypr-profile toggle"), { release = true })
