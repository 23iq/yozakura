.pragma library

// Lock screen styles of the SDDM theme. Mirrors the shell registry
// (modules/lockscreen/styles/LockStyleRegistry.js): adding a style = one
// file in styles/ (extending SddmStyle.qml) + one entry below. The ids and
// tones must match the shell's; scripts/sddm-sync.sh exports the active id
// and the resolved tone into theme.conf.

var DEFAULT_ID = "glass";

var styles = {
    "glass": {
        "file": "GlassStyle.qml",
        "tones": ["dark", "light"]
    },
    "paper": {
        "file": "PaperStyle.qml",
        "tones": ["light", "dark"]
    },
    "terminal": {
        "file": "TerminalStyle.qml",
        "tones": ["dark", "light"]
    },
    "aurora": {
        "file": "AuroraStyle.qml",
        "tones": ["light", "dark"]
    },
    "neon": {
        "file": "NeonStyle.qml",
        "tones": ["dark"]
    },
    "poster": {
        "file": "PosterStyle.qml",
        "tones": ["dark", "light"]
    }
};

function has(id) {
    return Object.prototype.hasOwnProperty.call(styles, id);
}

// Known id, or the default style.
function resolve(id) {
    return has(id) ? id : DEFAULT_ID;
}

function file(id) {
    return styles[resolve(id)].file;
}

// "light" | "dark": the requested tone when the style has it, else its own.
function tone(id, wanted) {
    var tones = styles[resolve(id)].tones;
    return tones.indexOf(wanted) !== -1 ? wanted : tones[0];
}
