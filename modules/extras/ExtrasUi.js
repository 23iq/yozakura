.pragma library

// Color helpers of the extras components (kept here so the catalog can be
// embedded outside the settings window, e.g. by onboarding steps).

// `c` with its alpha multiplied by `a`.
function alpha(c, a) {
    if (c === undefined || c === null)
        return Qt.rgba(0, 0, 0, 0);
    return Qt.rgba(c.r, c.g, c.b, c.a * a);
}

// Linear mix of two colors, t in [0, 1].
function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
}
