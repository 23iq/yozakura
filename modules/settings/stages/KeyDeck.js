.pragma library
.import "../../keybinds/KeyNames.js" as KeyNames

// Pure model of the keyboard drawn from keycaps (stages/KeyDeck.qml, the
// Keys destination): the rows of a compact ANSI keyboard, each key
// [id, label, width in key units], and which keys a shortcut lights.
// Ids are KeyNames' canonical names (lower-case keys, upper-case
// modifiers), so a bind's combo maps straight onto the caps.
// Node-tested (tests/settings-keys.test.cjs).

var ROWS = [
    [["grave", "`", 1], ["1", "1", 1], ["2", "2", 1], ["3", "3", 1], ["4", "4", 1], ["5", "5", 1], ["6", "6", 1], ["7", "7", 1], ["8", "8", 1], ["9", "9", 1], ["0", "0", 1], ["minus", "-", 1], ["equal", "=", 1], ["backspace", "⌫", 2]],
    [["tab", "Tab", 1.5], ["q", "Q", 1], ["w", "W", 1], ["e", "E", 1], ["r", "R", 1], ["t", "T", 1], ["y", "Y", 1], ["u", "U", 1], ["i", "I", 1], ["o", "O", 1], ["p", "P", 1], ["bracketleft", "[", 1], ["bracketright", "]", 1], ["backslash", "\\", 1.5]],
    [["caps_lock", "Caps", 1.75], ["a", "A", 1], ["s", "S", 1], ["d", "D", 1], ["f", "F", 1], ["g", "G", 1], ["h", "H", 1], ["j", "J", 1], ["k", "K", 1], ["l", "L", 1], ["semicolon", ";", 1], ["apostrophe", "'", 1], ["return", "↵", 2.25]],
    [["SHIFT", "Shift", 2.25], ["z", "Z", 1], ["x", "X", 1], ["c", "C", 1], ["v", "V", 1], ["b", "B", 1], ["n", "N", 1], ["m", "M", 1], ["comma", ",", 1], ["period", ".", 1], ["slash", "/", 1], ["SHIFT", "Shift", 2.75]],
    [["CTRL", "Ctrl", 1.5], ["SUPER", "Super", 1.25], ["ALT", "Alt", 1.25], ["space", "", 6.5], ["ALT", "Alt", 1.25], ["SUPER", "Super", 1.25], ["CTRL", "Ctrl", 2]]
];

// Key units across a row (every row has the same).
var UNITS = 15;

// The ids a combo lights: its modifiers and its key ([] for none).
function lit(combo) {
    if (!combo)
        return [];
    var out = KeyNames.normalizeMods(combo.modifiers || []);
    var k = KeyNames.normalizeKey(combo.key);
    if (k === "super_l") {
        if (out.indexOf("SUPER") < 0)
            out.push("SUPER");
    }
    else if (k !== "")
        out.push(k);
    return out;
}

// The keys of a layout switch binding ("alt_shift_toggle", "grp:win_space_toggle", ...).
function switchKeys(bind) {
    var b = String(bind || "").toLowerCase();
    var out = [];
    if (/alt/.test(b))
        out.push("ALT");
    if (/shift/.test(b))
        out.push("SHIFT");
    if (/ctrl/.test(b))
        out.push("CTRL");
    if (/win|super/.test(b))
        out.push("SUPER");
    if (/caps/.test(b))
        out.push("caps_lock");
    if (/space/.test(b))
        out.push("space");
    return out;
}
