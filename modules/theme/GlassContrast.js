.pragma library

// WCAG contrast for translucent surfaces on an unknown wallpaper.
//
// A surface of color S at opacity a over a backdrop B shows a*S + (1-a)*B
// (per sRGB channel). Relative luminance grows monotonically with every
// backdrop channel, so over ALL possible wallpapers (blurred or not) the
// composite luminance spans exactly [L(a, black), L(a, white)]. The worst
// case contrast against the text is therefore known without sampling the
// wallpaper, which is what lets the glass system guarantee legibility on
// any wallpaper. Colors are {r, g, b} with channels in [0, 1] (QML colors
// satisfy that shape).

var WCAG_AA = 4.5;

var BLACK = { "r": 0, "g": 0, "b": 0 };
var WHITE = { "r": 1, "g": 1, "b": 1 };

function linear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function luminance(c) {
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
}

function ratio(l1, l2) {
    const hi = Math.max(l1, l2), lo = Math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
}

function over(surface, backdrop, alpha) {
    return {
        "r": alpha * surface.r + (1 - alpha) * backdrop.r,
        "g": alpha * surface.g + (1 - alpha) * backdrop.g,
        "b": alpha * surface.b + (1 - alpha) * backdrop.b
    };
}

// Lowest text contrast of `text` on `surface` at `alpha` over any backdrop.
function worstContrast(surface, text, alpha) {
    const lt = luminance(text);
    const lb = luminance(over(surface, BLACK, alpha));
    const lw = luminance(over(surface, WHITE, alpha));
    if (lt >= lb && lt <= lw)
        return 1;
    return Math.min(ratio(lt, lb), ratio(lt, lw));
}

// Minimum surface opacity keeping `text` at >= target contrast on any
// wallpaper; 1 when even the opaque surface cannot reach it.
function minOpacity(surface, text, target) {
    const goal = target || WCAG_AA;
    if (!surface || !text || worstContrast(surface, text, 1) < goal)
        return 1;
    if (worstContrast(surface, text, 0) >= goal)
        return 0;
    let lo = 0, hi = 1;
    for (let i = 0; i < 24; i++) {
        const mid = (lo + hi) / 2;
        if (worstContrast(surface, text, mid) >= goal)
            hi = mid;
        else
            lo = mid;
    }
    return Math.ceil(hi * 1000) / 1000;
}
