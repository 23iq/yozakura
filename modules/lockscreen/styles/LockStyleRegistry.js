.pragma library

// Lock screen styles. Adding a style = one QML file in this directory
// (extending LockStyle.qml) + one entry below (+ its labelKey/descKey
// translations); `make schema` adds the id to the allowed values of
// `lockscreen.style`. The SDDM theme mirrors every id in
// assets/sddm/<theme>/styles/ (a missing one falls back to glass there).
//
// Entry fields:
//   id        config value (lockscreen.style)
//   labelKey  I18n key of the name shown in the settings gallery
//   descKey   I18n key of the one-line description
//   icon      Icons.* name
//   file      QML file next to this registry
//   tones     tones the style can draw, its own (natural) tone first

var DEFAULT_ID = "glass";
// lockscreen.tone: "style" = the style's own tone, "theme" = follow the
// shell's light/dark mode, "light"/"dark" = force one (when the style has it).
var TONES = ["style", "theme", "light", "dark"];
// lockscreen.blur: -1 = the style's own wallpaper blur.
var BLUR_STYLE_DEFAULT = -1;

var styles = [
    {
        id: "glass",
        labelKey: "lockscreen.style.glass",
        descKey: "lockscreen.style.glass.desc",
        icon: "drop",
        file: "GlassStyle.qml",
        tones: ["dark", "light"]
    },
    {
        id: "paper",
        labelKey: "lockscreen.style.paper",
        descKey: "lockscreen.style.paper.desc",
        icon: "paintBrush",
        file: "PaperStyle.qml",
        tones: ["light", "dark"]
    },
    {
        id: "terminal",
        labelKey: "lockscreen.style.terminal",
        descKey: "lockscreen.style.terminal.desc",
        icon: "terminal",
        file: "TerminalStyle.qml",
        tones: ["dark", "light"]
    },
    {
        id: "aurora",
        labelKey: "lockscreen.style.aurora",
        descKey: "lockscreen.style.aurora.desc",
        icon: "sparkle",
        file: "AuroraStyle.qml",
        tones: ["light", "dark"]
    },
    {
        id: "neon",
        labelKey: "lockscreen.style.neon",
        descKey: "lockscreen.style.neon.desc",
        icon: "lightning",
        file: "NeonStyle.qml",
        tones: ["dark"]
    },
    {
        id: "poster",
        labelKey: "lockscreen.style.poster",
        descKey: "lockscreen.style.poster.desc",
        icon: "textAa",
        file: "PosterStyle.qml",
        tones: ["dark", "light"]
    }
];

function ids() {
    return styles.map(function (s) {
        return s.id;
    });
}

function has(id) {
    return ids().indexOf(id) !== -1;
}

// The entry for `id`, or the default style for unknown ids.
function get(id) {
    for (var i = 0; i < styles.length; i++) {
        if (styles[i].id === id)
            return styles[i];
    }
    return styles[0];
}

// "light" | "dark" for a style, the configured tone and the shell mode.
// A tone the style cannot draw falls back to its own.
function resolveTone(id, tone, shellLight) {
    var entry = get(id);
    var natural = entry.tones[0];
    var want = natural;
    if (tone === "light" || tone === "dark")
        want = tone;
    else if (tone === "theme")
        want = shellLight ? "light" : "dark";
    return entry.tones.indexOf(want) !== -1 ? want : natural;
}

// Wallpaper blur (0..1): the configured one, or the style's own (-1).
function blurFor(configured, styleDefault) {
    if (typeof configured !== "number" || configured < 0)
        return styleDefault;
    return Math.max(0, Math.min(1, configured));
}
