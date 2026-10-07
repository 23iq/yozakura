.pragma library

// Pure rules of the bar's kit look (BarLook.qml / ModuleBox.qml). Unit
// tested in tests/bar-look.test.cjs.

// Whether the bar draws a visible surface under its modules: the strip /
// pill background (srBarBg) has some opacity, or the frame contains the bar.
function barSurface(barBgOpacity, containBar, frameEnabled) {
    return (Number(barBgOpacity) || 0) > 0 || (containBar === true && frameEnabled === true);
}

// Rest look of a module's box:
//   "none"     flat modules
//   "surface"  the theme's "bg" pill: classic, or a transparent bar where the
//              group box has to be the surface (except solid tiles)
//   "group"    the language's group box on a visible bar surface
function restLook(language, flat, surface, solidGroups) {
    if (flat)
        return "none";
    if (language === "classic")
        return "surface";
    if (surface || solidGroups)
        return "group";
    return "surface";
}

// Module text role: body, secondary on dense panels (< `denseBelow` px)
function textRole(moduleSize, denseBelow) {
    return moduleSize >= denseBelow ? "body" : "secondary";
}

// Glyph size for a module: the kit's body glyph, scaled gently with the
// module size (36 px = 1:1), never below 8 px
function iconSize(bodyIcon, moduleSize) {
    return Math.max(8, Math.round(bodyIcon * (0.4 + 0.6 * moduleSize / 36)));
}
