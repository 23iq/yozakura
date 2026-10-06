.pragma library
.import "ColorUtils.js" as ColorUtils

// Terminal theme files (ghostty, foot, alacritty) from the shell palette.
// The mapping mirrors KittyGenerator.qml so every terminal looks the same:
// color0 is a raised surface, color8 dim text, 16-21 the accent colors.
// Pure functions of plain strings: tested with node (tests/terminal-themes.test.cjs).

// QML color -> "#rrggbb" (drops the alpha of "#aarrggbb").
function hex(c) {
    const s = String(c);
    return s.length === 9 ? "#" + s.slice(3) : s;
}

// `C` is the Colors singleton (or any object with the same properties).
function palette(C) {
    const dark = ColorUtils.isDark(ColorUtils.fromQml(hex(C.background)));
    return {
        "foreground": hex(C.overSurface),
        "background": hex(C.background),
        "cursor": hex(C.overSurface),
        "cursorText": hex(C.overSurfaceVariant),
        "selectionForeground": hex(C.overSecondary),
        "selectionBackground": hex(C.secondaryFixedDim),
        // black red green yellow blue magenta cyan white
        "normal": [dark ? C.surfaceContainerHigh : C.overSurface, C.red, C.green, C.yellow, C.blue, C.magenta, C.cyan, dark ? C.overSurfaceVariant : C.surfaceContainerHigh].map(hex),
        "bright": [C.outline, C.lightRed, C.lightGreen, C.lightYellow, C.lightBlue, C.lightMagenta, C.lightCyan, dark ? C.overSurface : C.surfaceContainerLowest].map(hex),
        // primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, tertiary
        "extended": [C.primary, C.overPrimary, C.primaryContainer, C.overPrimaryContainer, C.secondary, C.tertiary].map(hex)
    };
}

function cleanFont(font) {
    return String(font || "").replace(/[\r\n]+/g, " ").trim();
}

function fontSize(size) {
    return Math.max(4, Number(size) || 11);
}

function opacity(o) {
    const n = Number(o);
    return isFinite(n) ? Math.min(1, Math.max(0, n)) : 1;
}

function bare(c) {
    return c.replace("#", "");
}

function quote(s) {
    return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
}

// opts: {font, fontSize, opacity}
function ghostty(p, opts) {
    let t = "";
    if (cleanFont(opts.font) !== "") {
        t += "font-family = " + quote(cleanFont(opts.font)) + "\n";
        t += "font-size = " + fontSize(opts.fontSize) + "\n\n";
    }
    t += "background = " + p.background + "\n";
    t += "foreground = " + p.foreground + "\n";
    t += "background-opacity = " + opacity(opts.opacity) + "\n";
    t += "cursor-color = " + p.cursor + "\n";
    t += "cursor-text = " + p.cursorText + "\n";
    t += "selection-background = " + p.selectionBackground + "\n";
    t += "selection-foreground = " + p.selectionForeground + "\n\n";
    const all = p.normal.concat(p.bright, p.extended);
    for (let i = 0; i < all.length; i++)
        t += "palette = " + i + "=" + all[i] + "\n";
    return t;
}

function foot(p, opts) {
    let t = "[main]\n";
    if (cleanFont(opts.font) !== "")
        t += "font=" + cleanFont(opts.font) + ":size=" + fontSize(opts.fontSize) + "\n";
    t += "\n[colors]\n";
    t += "alpha=" + opacity(opts.opacity) + "\n";
    t += "background=" + bare(p.background) + "\n";
    t += "foreground=" + bare(p.foreground) + "\n";
    t += "cursor=" + bare(p.cursorText) + " " + bare(p.cursor) + "\n";
    t += "selection-foreground=" + bare(p.selectionForeground) + "\n";
    t += "selection-background=" + bare(p.selectionBackground) + "\n";
    for (let i = 0; i < 8; i++)
        t += "regular" + i + "=" + bare(p.normal[i]) + "\n";
    for (let i = 0; i < 8; i++)
        t += "bright" + i + "=" + bare(p.bright[i]) + "\n";
    return t;
}

var ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];

function alacritty(p, opts) {
    let t = "";
    if (cleanFont(opts.font) !== "") {
        t += "[font]\nsize = " + fontSize(opts.fontSize) + "\n\n";
        t += "[font.normal]\nfamily = " + quote(cleanFont(opts.font)) + "\n\n";
    }
    t += "[window]\nopacity = " + opacity(opts.opacity) + "\n\n";
    t += "[colors.primary]\nbackground = " + quote(p.background) + "\nforeground = " + quote(p.foreground) + "\n\n";
    t += "[colors.cursor]\ntext = " + quote(p.cursorText) + "\ncursor = " + quote(p.cursor) + "\n\n";
    t += "[colors.selection]\ntext = " + quote(p.selectionForeground) + "\nbackground = " + quote(p.selectionBackground) + "\n\n";
    t += "[colors.normal]\n";
    for (let i = 0; i < 8; i++)
        t += ANSI[i] + " = " + quote(p.normal[i]) + "\n";
    t += "\n[colors.bright]\n";
    for (let i = 0; i < 8; i++)
        t += ANSI[i] + " = " + quote(p.bright[i]) + "\n";
    return t;
}
