.pragma library

// Key and modifier names: canonical forms for comparing combos (Hyprland
// matches key names case-insensitively and accepts several aliases), how a
// key is drawn on a keycap, and Qt key events -> Hyprland key names for the
// shortcut recorder. Pure: tested in tests/keybinds.test.cjs.

var MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT"];

var MOD_ALIASES = {
    "SUPER": "SUPER", "MOD4": "SUPER", "WIN": "SUPER", "LOGO": "SUPER", "META": "SUPER",
    "CTRL": "CTRL", "CONTROL": "CTRL",
    "ALT": "ALT", "MOD1": "ALT",
    "SHIFT": "SHIFT"
};

// Hyprland `modmask` bits (hyprctl binds -j).
var MODMASK = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]];

// Lower-case key name -> canonical (lower-case) name.
var KEY_ALIASES = {
    "enter": "return", "kp_enter": "return",
    "esc": "escape",
    ".": "period", ",": "comma", "/": "slash", ";": "semicolon", "'": "apostrophe",
    "[": "bracketleft", "]": "bracketright", "\\": "backslash", "-": "minus", "=": "equal", "`": "grave",
    " ": "space",
    "del": "delete", "ins": "insert",
    "prior": "page_up", "pgup": "page_up", "pageup": "page_up",
    "next": "page_down", "pgdn": "page_down", "pagedown": "page_down",
    "super_r": "super_l", "super": "super_l",
    "print": "print", "sysrq": "print",
    "mouse:272": "mouse:272", "mouse:273": "mouse:273", "mouse:274": "mouse:274"
};

function normalizeMod(mod) {
    var m = String(mod || "").trim().toUpperCase();
    return MOD_ALIASES[m] || m;
}

// Unique, ordered (SUPER CTRL ALT SHIFT, then the rest alphabetically).
function normalizeMods(mods) {
    var seen = {};
    var out = [];
    (mods || []).forEach(function (m) {
        var n = normalizeMod(m);
        if (n && !seen[n]) {
            seen[n] = true;
            out.push(n);
        }
    });
    return out.sort(function (a, b) {
        var ia = MOD_ORDER.indexOf(a), ib = MOD_ORDER.indexOf(b);
        if (ia === -1)
            ia = 99;
        if (ib === -1)
            ib = 99;
        return ia !== ib ? ia - ib : (a < b ? -1 : a > b ? 1 : 0);
    });
}

function normalizeKey(key) {
    var k = String(key === undefined || key === null ? "" : key);
    if (k !== " ")
        k = k.trim();
    var lower = k.toLowerCase();
    return KEY_ALIASES[lower] !== undefined ? KEY_ALIASES[lower] : lower;
}

// Identity of a key combo for conflict detection; "" for an empty key.
function comboId(mods, key) {
    var k = normalizeKey(key);
    if (k === "")
        return "";
    var m = normalizeMods(mods);
    // A lone Super press is bound as SUPER + Super_L; with or without the
    // modifier it is the same physical combo.
    if (k === "super_l" && m.indexOf("SUPER") === -1)
        m = normalizeMods(m.concat(["SUPER"]));
    return m.join("+") + "|" + k;
}

function modsFromMask(mask) {
    var out = [];
    MODMASK.forEach(function (p) {
        if (mask & p[0])
            out.push(p[1]);
    });
    return out;
}

// --- Keycap presentation --------------------------------------------------
//
// keycap(key) -> {kind, text, icon}
//   kind "super": the app logo glyph; "icon": `icon` names an Icons
//   property; "text": a short label.

var ICON_KEYS = {
    "up": "arrowUp", "down": "arrowDown", "left": "arrowLeft", "right": "arrowRight",
    "return": "keyReturn", "backspace": "backspace",
    "mouse:272": "mouseLeftClick", "mouse:273": "mouseRightClick", "mouse:274": "mouseMiddleClick",
    "mouse_up": "mouseScroll", "mouse_down": "mouseScroll",
    "xf86audioplay": "play", "xf86audiopause": "pause", "xf86audiomedia": "play",
    "xf86audionext": "next", "xf86audioprev": "previous", "xf86audiostop": "stop",
    "xf86audioraisevolume": "speakerHigh", "xf86audiolowervolume": "speakerLow", "xf86audiomute": "speakerSlash",
    "xf86monbrightnessup": "sun", "xf86monbrightnessdown": "sunDim",
    "xf86calculator": "calculator", "xf86audiomicmute": "micSlash"
};

// Short labels: everything else is shown as typed, capitalised.
var TEXT_KEYS = {
    "escape": "Esc", "tab": "Tab", "space": "Space", "delete": "Del", "insert": "Ins",
    "home": "Home", "end": "End", "page_up": "PgUp", "page_down": "PgDn", "print": "PrtSc",
    "period": ".", "comma": ",", "slash": "/", "semicolon": ";", "apostrophe": "'",
    "bracketleft": "[", "bracketright": "]", "backslash": "\\", "minus": "-", "equal": "=", "grave": "`",
    "caps_lock": "Caps", "menu": "Menu", "pause": "Pause"
};

// Small direction hint drawn next to an icon (scroll up/down).
var ICON_HINTS = {
    "mouse_up": "↑", "mouse_down": "↓"
};

function keycap(key) {
    var k = normalizeKey(key);
    if (k === "super_l")
        return { "kind": "super", "text": "", "icon": "" };
    if (ICON_KEYS[k])
        return { "kind": "icon", "text": ICON_HINTS[k] || "", "icon": ICON_KEYS[k] };
    if (TEXT_KEYS[k])
        return { "kind": "text", "text": TEXT_KEYS[k], "icon": "" };
    var raw = String(key || "").trim();
    // switch:[on:|off:]Lid Switch -> "Lid", "Lid on", "Lid off"
    var sw = /^switch:(on:|off:)?(.*)$/i.exec(raw);
    if (sw) {
        var name = sw[2].replace(/\s*switch$/i, "");
        return { "kind": "text", "text": name + (sw[1] ? " " + sw[1].slice(0, -1) : ""), "icon": "" };
    }
    var xf = /^XF86(.*)$/i.exec(raw);
    if (xf)
        return { "kind": "text", "text": xf[1], "icon": "" };
    var mouse = /^mouse:(\d+)$/i.exec(raw);
    if (mouse)
        return { "kind": "icon", "text": mouse[1], "icon": "mouse" };
    if (raw.length === 1)
        return { "kind": "text", "text": raw.toUpperCase(), "icon": "" };
    // F1, KP_1, Page_Down-style names: first letter up, rest as written.
    return { "kind": "text", "text": raw.charAt(0).toUpperCase() + raw.slice(1).replace(/_/g, " ").toLowerCase(), "icon": "" };
}

var MOD_CAPS = {
    "SUPER": { "kind": "super", "text": "", "icon": "" },
    "CTRL": { "kind": "text", "text": "Ctrl", "icon": "" },
    "ALT": { "kind": "text", "text": "Alt", "icon": "" },
    "SHIFT": { "kind": "text", "text": "Shift", "icon": "" }
};

function modcap(mod) {
    var m = normalizeMod(mod);
    return MOD_CAPS[m] || { "kind": "text", "text": m.charAt(0) + m.slice(1).toLowerCase(), "icon": "" };
}

// Keycaps of a combo in display order. A lone Super bind (SUPER + Super_L)
// shows one Super cap.
function caps(mods, key) {
    var m = normalizeMods(mods);
    var k = normalizeKey(key);
    if (k === "super_l")
        m = m.filter(function (x) {
            return x !== "SUPER";
        });
    var out = m.map(modcap);
    if (k !== "")
        out.push(keycap(key));
    return out;
}

// Plain-text form ("Super + Shift + S"), for search and accessibility.
function comboText(mods, key, superName) {
    return caps(mods, key).map(function (c) {
        if (c.kind === "super")
            return superName || "Super";
        return c.text || c.icon;
    }).join(" + ");
}

// Kit KeyHints of a combo ([{text, icon}], `icon` an Icons key): the Super
// key reads "Super", glyph keys (arrows, mouse) keep their icon.
function hints(mods, key, superName) {
    return caps(mods, key).map(function (c) {
        if (c.kind === "super")
            return { "text": superName || "Super", "icon": "" };
        if (c.kind === "icon")
            return { "text": "", "icon": c.icon };
        return { "text": c.text, "icon": "" };
    });
}

// --- Recorder: Qt key events -> Hyprland names ----------------------------

var QT_MODS = [[0x10000000, "SUPER"], [0x04000000, "CTRL"], [0x08000000, "ALT"], [0x02000000, "SHIFT"]];

// Qt::Key values of the modifier keys themselves.
var QT_MOD_KEYS = {
    "16777248": "SHIFT", "16777249": "CTRL", "16777250": "SUPER", "16777251": "ALT",
    "16777299": "SUPER", "16777300": "SUPER", "16781571": "ALT"
};

var QT_KEYS = {
    "16777216": "ESCAPE", "16777217": "TAB", "16777218": "TAB", "16777219": "BackSpace",
    "16777220": "Return", "16777221": "Return", "16777222": "Insert", "16777223": "Delete",
    "16777224": "Pause", "16777225": "Print", "16777232": "Home", "16777233": "End",
    "16777234": "Left", "16777235": "Up", "16777236": "Right", "16777237": "Down",
    "16777238": "Page_Up", "16777239": "Page_Down", "16777252": "Caps_Lock", "16777301": "Menu",
    "32": "SPACE",
    "16777328": "XF86AudioLowerVolume", "16777329": "XF86AudioMute", "16777330": "XF86AudioRaiseVolume",
    "16777344": "XF86AudioPlay", "16777345": "XF86AudioStop", "16777346": "XF86AudioPrev",
    "16777347": "XF86AudioNext", "16777349": "XF86AudioPause", "16777350": "XF86AudioPlay",
    "16777394": "XF86MonBrightnessUp", "16777395": "XF86MonBrightnessDown", "16777419": "XF86Calculator",
    "16777491": "XF86AudioMicMute"
};

// Printable keys by their unshifted symbol (Qt reports the shifted symbol
// while Shift is held; Hyprland binds the unshifted keysym).
var SYMBOLS = {
    ".": "PERIOD", ">": "PERIOD", ",": "COMMA", "<": "COMMA", "/": "SLASH", "?": "SLASH",
    ";": "SEMICOLON", ":": "SEMICOLON", "'": "APOSTROPHE", "\"": "APOSTROPHE",
    "[": "BRACKETLEFT", "{": "BRACKETLEFT", "]": "BRACKETRIGHT", "}": "BRACKETRIGHT",
    "\\": "BACKSLASH", "|": "BACKSLASH", "-": "MINUS", "_": "MINUS", "=": "EQUAL", "+": "EQUAL",
    "`": "GRAVE", "~": "GRAVE",
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0"
};

function modsFromQt(modifiers) {
    var out = [];
    QT_MODS.forEach(function (p) {
        if (modifiers & p[0])
            out.push(p[1]);
    });
    return out;
}

// The modifier a key press is (SUPER/CTRL/ALT/SHIFT), or "".
function qtModifierKey(qtKey) {
    return QT_MOD_KEYS[String(qtKey)] || "";
}

// Hyprland key name of a Qt key press, or "" when it cannot be bound.
function keyFromQt(qtKey, text) {
    if (QT_KEYS[String(qtKey)])
        return QT_KEYS[String(qtKey)];
    if (qtKey >= 0x41 && qtKey <= 0x5a)
        return String.fromCharCode(qtKey);
    if (qtKey >= 0x30 && qtKey <= 0x39)
        return String.fromCharCode(qtKey);
    // F1..F35
    if (qtKey >= 0x01000030 && qtKey <= 0x01000052)
        return "F" + (qtKey - 0x01000030 + 1);
    var sym = qtKey > 0x20 && qtKey < 0x7f ? String.fromCharCode(qtKey) : (text || "");
    if (SYMBOLS[sym])
        return SYMBOLS[sym];
    return "";
}

// Qt mouse button -> Hyprland mouse key.
function mouseKey(button) {
    if (button === 1)
        return "mouse:272";
    if (button === 2)
        return "mouse:273";
    if (button === 4)
        return "mouse:274";
    return "";
}
