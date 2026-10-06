.pragma library

// External app theming registry: one entry per user-facing app toggle
// (config `apps.theming.<id>`, config/defaults/apps.js). Colors.qml runs the
// listed generators (property names on Colors) only for enabled entries;
// the settings page (Terminal & Apps) shows each one with its install and
// last-written status from statusScript(). Adding an app theme = one
// *Generator.qml + one entry here + its default in config/defaults/apps.js.
//
// `detect` is an sh condition (is the app installed?) and `outputs` are sh
// globs of the files the generators write; both may use $C (XDG config),
// $D (XDG data), $K (the shell cache dir) and $A (the app id).

var APPS = [
    {
        "id": "gtk",
        "label": "GTK",
        "icon": "paintBrush",
        "generators": ["gtkGenerator"],
        "detect": "command -v gsettings",
        "outputs": ["$C/gtk-3.0/gtk.css", "$C/gtk-4.0/gtk.css"]
    },
    {
        "id": "qt",
        "label": "Qt (qt5ct / qt6ct)",
        "icon": "squaresFour",
        "generators": ["qtCtGenerator"],
        "detect": "command -v qt6ct || command -v qt5ct",
        "outputs": ["$C/qt6ct/colors/$A.colors", "$C/qt5ct/colors/$A.colors"]
    },
    {
        "id": "kitty",
        "label": "Kitty",
        "icon": "terminal",
        "generators": ["kittyGenerator"],
        "detect": "command -v kitty",
        "outputs": ["$K/kitty.conf"]
    },
    {
        "id": "ghostty",
        "label": "Ghostty",
        "icon": "terminal",
        "generators": ["ghosttyGenerator"],
        "detect": "command -v ghostty || [ -d \"$C/ghostty\" ]",
        "outputs": ["$K/ghostty.conf"]
    },
    {
        "id": "foot",
        "label": "Foot",
        "icon": "terminal",
        "generators": ["footGenerator"],
        "detect": "command -v foot || [ -d \"$C/foot\" ]",
        "outputs": ["$K/foot.ini"]
    },
    {
        "id": "alacritty",
        "label": "Alacritty",
        "icon": "terminal",
        "generators": ["alacrittyGenerator"],
        "detect": "command -v alacritty || [ -d \"$C/alacritty\" ]",
        "outputs": ["$K/alacritty.toml"]
    },
    {
        "id": "discord",
        "label": "Discord (Vesktop / Vencord)",
        "icon": "chatDots",
        "generators": ["discordGenerator"],
        "detect": "[ -d \"$C/vesktop\" ] || [ -d \"$C/equibop\" ] || [ -d \"$C/Equicord\" ] || [ -d \"$C/Vencord\" ]",
        "outputs": ["$C/vesktop/themes/$A.css", "$C/equibop/themes/$A.css", "$C/Equicord/themes/$A.css", "$C/Vencord/themes/$A.css"]
    },
    {
        "id": "spicetify",
        "label": "Spotify (Spicetify)",
        "icon": "spotify",
        "generators": ["spicetifyGenerator"],
        "detect": "command -v spicetify || [ -d \"$C/spicetify\" ]",
        "outputs": ["$C/spicetify/Themes/$A/color.ini"]
    },
    {
        "id": "telegram",
        "label": "Telegram",
        "icon": "telegram",
        "generators": ["telegramGenerator"],
        "detect": "command -v telegram-desktop || command -v ayugram-desktop || command -v 64gram-desktop || command -v kotatogram-desktop || command -v materialgram || command -v Telegram || [ -d \"$D/TelegramDesktop\" ] || [ -d \"$HOME/.var/app/org.telegram.desktop\" ]",
        "outputs": ["$K/$A.tdesktop-theme"]
    },
    {
        "id": "firefox",
        "label": "Firefox / Zen",
        "icon": "firefox",
        "generators": ["firefoxGenerator", "pywalZenGenerator"],
        "detect": "command -v firefox || command -v zen-browser || [ -d \"$HOME/.mozilla/firefox\" ] || [ -d \"$C/mozilla/firefox\" ]",
        "outputs": ["$HOME/.mozilla/firefox/*/chrome/$A.css", "$C/mozilla/firefox/*/chrome/$A.css", "$K/pywalzen.css"]
    },
    {
        "id": "papirus",
        "label": "Papirus folders",
        "icon": "folder",
        "generators": ["papirusGenerator"],
        "detect": "[ -d /usr/share/icons/Papirus ] || [ -d /usr/local/share/icons/Papirus ] || [ -d /run/current-system/sw/share/icons/Papirus ]",
        "outputs": ["$D/icons/*/.$A-papirus-folder-color"]
    },
    {
        "id": "nvim",
        "label": "Neovim",
        "icon": "code",
        "generators": ["nvChadGenerator", "nvimGenerator"],
        "detect": "command -v nvim",
        "outputs": ["$K/nvim-palette.lua", "$HOME/.cache/wal/base46-dark.lua", "$HOME/.cache/wal/base46-light.lua"]
    },
    {
        "id": "sddm",
        "label": "SDDM login",
        "icon": "lock",
        "generators": ["sddmGenerator"],
        "detect": "[ -d \"/var/lib/$A-sddm\" ]",
        "outputs": ["/var/lib/$A-sddm/theme.conf"]
    }
];

// Generators that always run: shared palettes other tools read.
var ALWAYS = ["pywalGenerator"];

function ids() {
    return APPS.map(function (a) {
        return a.id;
    });
}

function byId(id) {
    for (var i = 0; i < APPS.length; i++) {
        if (APPS[i].id === id)
            return APPS[i];
    }
    return null;
}

// `apps.theming` value (object or JsonObject) -> is this app themed?
// Unknown/missing keys count as enabled.
function enabled(theming, id) {
    if (!theming)
        return true;
    return theming[id] !== false;
}

// Generator property names (on Colors) to run for a theming config.
function generatorsFor(theming) {
    var out = ALWAYS.slice();
    APPS.forEach(function (a) {
        if (enabled(theming, a.id))
            out = out.concat(a.generators);
    });
    return out;
}

// Which app owns a generator (null for ALWAYS generators).
function appOfGenerator(name) {
    for (var i = 0; i < APPS.length; i++) {
        if (APPS[i].generators.indexOf(name) !== -1)
            return APPS[i].id;
    }
    return null;
}

// sh script printing one `id|installed(0/1)|newest output mtime (s, 0 = none)`
// line per app. Run as: sh -c <script> sh <cacheDir> <appId>.
function statusScript() {
    var lines = [
        "C=\"${XDG_CONFIG_HOME:-$HOME/.config}\"; D=\"${XDG_DATA_HOME:-$HOME/.local/share}\"; K=\"$1\"; A=\"$2\"",
        "newest() { t=0; for f in \"$@\"; do [ -e \"$f\" ] || continue; m=$(stat -c %Y \"$f\" 2>/dev/null || echo 0); [ \"$m\" -gt \"$t\" ] && t=$m; done; echo \"$t\"; }"
    ];
    APPS.forEach(function (a) {
        lines.push("i=0; ( " + a.detect + " ) >/dev/null 2>&1 && i=1; echo \"" + a.id + "|$i|$(newest " + a.outputs.join(" ") + ")\"");
    });
    return lines.join("\n");
}

// statusScript() output -> {id: {installed, written (ms epoch, 0 = never)}}
function parseStatus(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var p = line.trim().split("|");
        if (p.length !== 3 || !byId(p[0]))
            return;
        out[p[0]] = {
            "installed": p[1] === "1",
            "written": (parseInt(p[2], 10) || 0) * 1000
        };
    });
    return out;
}
