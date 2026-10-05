.pragma library

// Desktop clock styles. Adding a style = one QML file in this directory
// (extending ClockStyle.qml) + one entry below.
//
// Entry fields:
//   id          config value (desktop.depthClockStyle)
//   labelKey    I18n key shown in the settings selector
//   icon        Icons.* name for the selector
//   file        QML file next to this registry
//   needsDepth  draws its "behind" part under the wallpaper subject
//   sides       placements the style supports (scored per wallpaper)
//   layout(ctx) geometry in screen pixels, shared by the QML style (sizes,
//               anchors) and by placement scoring (ClockPlacement.js):
//                 ctx = { screenW, screenH, area: {x, y, w, h}, side, use12h }
//               returns at least
//                 behind: {x, y, w, h}  what goes under the subject
//                 bounds: {x, y, w, h}  the whole clock (ink probe)
//                 legible: [{x, y, w, h}, ...]  (optional) parts that must
//                          each stay readable when drawn behind the subject
//
// Reference geometry for every style is a 2560x1440 screen; `u` scales it.

var DEFAULT_ID = "yozakura";
var POSITIONS = ["auto", "left", "right"];
// desktop.depthClockInk: "auto" (light/dark ink from the backdrop) or one
// of these palette roles (Colors.*), so a preset can pick its clock colour.
var INKS = ["auto", "primary", "secondary", "tertiary", "primaryFixed", "secondaryFixed", "tertiaryFixed", "overBackground", "background"];

function box(x, y, w, h) {
    return {
        x: x,
        y: y,
        w: w,
        h: h
    };
}

// Vertical mincho column at the screen edge: stacked "21 時 47 分" behind
// the subject, a kanji date column + 夜桜 seal in front.
function yozakuraLayout(ctx) {
    var a = ctx.area;
    var u = Math.min(ctx.screenW, ctx.screenH) / 1440;
    var m = {
        u: u,
        edge: 132 * u,
        top: a.y + 80 * u,
        digitSize: 270 * u,
        digitLine: 0.92,
        digitTracking: -0.03,
        unitSize: 50 * u,
        unitGapAbove: 14 * u,
        unitGapBelow: 26 * u,
        gap: 54 * u,
        columnPadTop: 22 * u,
        columnGap: 34 * u,
        dateSize: 62 * u,
        dateTracking: 0.22,
        weekdaySize: 40 * u,
        weekdayTracking: 0.45,
        ruleWidth: Math.max(1, 1.5 * u),
        ruleHeight: 140 * u,
        sealSize: 36 * u,
        sealTracking: 0.06,
        sealPadX: 10 * u,
        sealPadY: 12 * u,
        sealRadius: 7 * u
    };
    // Estimates for scoring; the QML measures the real text.
    var unitBlock = m.unitSize + m.unitGapAbove + m.unitGapBelow;
    var timeW = 1.04 * m.digitSize;
    var timeH = 2 * m.digitLine * m.digitSize + 2 * unitBlock + (ctx.use12h ? m.unitSize + m.unitGapAbove : 0);
    var colW = 1.45 * m.dateSize;
    var colH = 841 * u;
    var totalW = timeW + m.gap + colW;
    var left = ctx.side === "left";
    // Outer edge the clock hangs from (left edge on the left, right edge on the right).
    m.anchorX = left ? a.x + m.edge : a.x + a.w - m.edge;
    var x0 = left ? m.anchorX : m.anchorX - totalW;
    var timeX = left ? x0 : x0 + totalW - timeW;
    var digitsH = m.digitLine * m.digitSize;
    var hoursY = m.top + (ctx.use12h ? m.unitSize + m.unitGapAbove : 0);
    m.behind = box(timeX, m.top, timeW, timeH);
    m.bounds = box(x0, m.top, totalW, Math.max(timeH, colH));
    m.legible = [box(timeX, hoursY, timeW, digitsH), box(timeX, hoursY + digitsH + unitBlock, timeW, digitsH)];
    return m;
}

// Condensed poster: hours over minutes filling the height, a vertical
// date line alongside.
function posterLayout(ctx) {
    var a = ctx.area;
    // Fills the height (860px on a 1440px screen); never wider than ~36%
    // of the screen so portrait/narrow screens keep breathing room.
    var size = Math.min(a.h * 0.6232, a.w * 0.6);
    var k = size / 860;
    var line = 0.79;
    var blockH = 2 * line * size;
    var spare = a.h - blockH;
    var top = a.y + (spare > a.h * 0.1 ? spare / 2 : 4 * k);
    // Keep the whole clock (numerals + date line) inside the area.
    var half = 0.45 * size;
    var cx = a.x + a.w * (ctx.side === "left" ? 0.17 : 0.83);
    cx = Math.min(Math.max(cx, a.x + half), a.x + a.w - half);
    var pairW = 0.62 * size;
    var m = {
        k: k,
        size: size,
        line: line,
        tracking: -0.005,
        top: top,
        centerX: cx,
        dateSize: Math.max(12, 24 * k),
        dateTracking: 0.42,
        dateX: ctx.side === "left" ? cx + 0.4186 * size : cx - 0.4535 * size,
        dateTop: top + 60 * k
    };
    m.behind = box(cx - pairW / 2, top, pairW, blockH);
    m.legible = [box(cx - pairW / 2, top, pairW, blockH / 2), box(cx - pairW / 2, top + blockH / 2, pairW, blockH / 2)];
    m.bounds = box(cx - 0.442 * size, a.y, 0.884 * size, a.h);
    return m;
}

var styles = [
    {
        id: "yozakura",
        labelKey: "shell.desktop.depth_clock_style_yozakura",
        icon: "moon",
        file: "YozakuraClock.qml",
        needsDepth: true,
        sides: ["left", "right"],
        layout: yozakuraLayout
    },
    {
        id: "poster",
        labelKey: "shell.desktop.depth_clock_style_poster",
        icon: "textT",
        file: "PosterClock.qml",
        needsDepth: true,
        sides: ["left", "right"],
        layout: posterLayout
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

// Unknown ids fall back to the default style.
function get(id) {
    for (var i = 0; i < styles.length; i++) {
        if (styles[i].id === id)
            return styles[i];
    }
    return get(DEFAULT_ID);
}
