.pragma library

// Key routing of the kit SearchField: which signal a key press emits, or ""
// to let the text field handle it (typing, cursor moves inside the text).
// Unit tested in tests/search-keys.test.cjs.
//   ctx.empty       the field holds no text
//   ctx.atStart     the cursor is at the start / ctx.atEnd at the end
//   ctx.tabNav      Tab / Shift+Tab are captured (handleTabNavigation)
//   ctx.freeCursor  Left / Right always navigate (disableCursorNavigation)

var KEY = {
    Escape: 0x01000000,
    Tab: 0x01000001,
    Backtab: 0x01000002,
    Backspace: 0x01000003,
    Return: 0x01000004,
    Enter: 0x01000005,
    Home: 0x01000010,
    End: 0x01000011,
    Left: 0x01000012,
    Up: 0x01000013,
    Right: 0x01000014,
    Down: 0x01000015,
    PageUp: 0x01000016,
    PageDown: 0x01000017,
    P: 0x50,
    R: 0x52
};
var SHIFT = 0x02000000;
var CTRL = 0x04000000;

// Keys that always emit their signal (no modifier needed).
var PLAIN = {};
PLAIN[KEY.Escape] = "escapePressed";
PLAIN[KEY.Down] = "downPressed";
PLAIN[KEY.Up] = "upPressed";
PLAIN[KEY.PageDown] = "pageDownPressed";
PLAIN[KEY.PageUp] = "pageUpPressed";
PLAIN[KEY.Home] = "homePressed";
PLAIN[KEY.End] = "endPressed";

// Ctrl shortcuts.
var CTRLS = {};
CTRLS[KEY.R] = "ctrlRPressed";
CTRLS[KEY.P] = "ctrlPPressed";
CTRLS[KEY.Up] = "ctrlUpPressed";
CTRLS[KEY.Down] = "ctrlDownPressed";

function action(key, mods, ctx) {
    var c = ctx || {};
    var shift = (mods & SHIFT) !== 0;
    var ctrl = (mods & CTRL) !== 0;
    if (key === KEY.Backspace)
        return c.empty ? "backspaceOnEmpty" : "";
    if (key === KEY.Tab || key === KEY.Backtab) {
        if (!c.tabNav)
            return "";
        return shift || key === KEY.Backtab ? "shiftTabPressed" : "tabPressed";
    }
    if (key === KEY.Return || key === KEY.Enter)
        return shift ? "shiftAccepted" : "accepted";
    if (ctrl && CTRLS[key])
        return CTRLS[key];
    if (key === KEY.Left)
        return c.freeCursor || c.atStart || c.empty ? "leftPressed" : "";
    if (key === KEY.Right)
        return c.freeCursor || c.atEnd || c.empty ? "rightPressed" : "";
    return PLAIN[key] || "";
}
