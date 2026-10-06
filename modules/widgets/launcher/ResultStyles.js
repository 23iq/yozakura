.pragma library

// Launcher result styles (layout.launcher.resultStyle): which look is really
// used for the current results, row metrics and grid keyboard navigation.
// Pure; tests/launcher-styles.test.cjs.

var STYLES = ["list", "cards", "grid"];

// "grid" is an app icon grid: any other provider's result falls back to list.
function effective(style, items) {
    if (STYLES.indexOf(style) < 0)
        return "list";
    if (style !== "grid")
        return style;
    if (!items || items.length === 0)
        return "list";
    for (var i = 0; i < items.length; i++) {
        if (items[i].provider !== "apps")
            return "list";
    }
    return "grid";
}

// Cards are one and a half rows tall (subtitle, badge row, larger icon).
function rowHeight(style, base) {
    return style === "cards" ? Math.round(base * 1.5) : base;
}

function columns(width, cell) {
    return Math.max(1, Math.floor(width / cell));
}

// Next selected index for an arrow key in a grid of `cols` columns.
function gridMove(index, dir, cols, count) {
    if (count <= 0)
        return -1;
    if (index < 0)
        return 0;
    var next = index;
    if (dir === "right")
        next = index + 1;
    else if (dir === "left")
        next = index - 1;
    else if (dir === "down")
        next = index + cols;
    else if (dir === "up")
        next = index - cols;
    if (dir === "down" && next >= count)
        // A partial last row: only step into it, never past it.
        next = Math.floor(index / cols) < Math.floor((count - 1) / cols) ? count - 1 : index;
    return next < 0 || next >= count ? index : next;
}
