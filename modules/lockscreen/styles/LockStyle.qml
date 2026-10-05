import QtQuick
import qs.modules.lockscreen
import qs.modules.theme
import qs.config

// Base interface of every lock screen style (see LockStyleRegistry.js).
//
// LockView creates the active style once and loads its five slots into a
// shared layout. Slot components are declared inside the style file, so
// they can read `view` (the LockView: lock state, clock, media presence)
// and the style's palette by id. A style only draws: authentication stays
// in LockScreen.qml, which reaches the password field through
// LockPasswordBase.
Item {
    id: skin

    // ── Inputs (set by LockView) ───────────────────────────────────────
    property LockView view: null
    // Resolved tone (LockStyleRegistry.resolveTone).
    property bool light: false

    // ── Slots ──────────────────────────────────────────────────────────
    // Drawn over the wallpaper, fills the screen (scrims, paper, CRT...).
    property Component backdrop: null
    property Component clock: null
    // Root must be a LockPasswordBase.
    property Component passwordField: null
    // Root must be a LockMediaBase.
    property Component mediaCard: null
    // Full-width strip on the edge opposite the password field.
    property Component status: null

    // ── Layout (LockView) ──────────────────────────────────────────────
    // "stack":  clock in one half, media + password at the configured edge
    // "center": clock and cluster as one centred column
    // "split":  clock on `clockSide`, cluster at the edge on the other side
    // "column": like "center", aligned to the left margin
    property string arrangement: "stack"
    property string clockSide: "left"
    property real clusterWidth: 420
    property real clusterSpacing: 18

    // ── Wallpaper treatment (LockView) ─────────────────────────────────
    property real wallpaperBlur: 0.7
    property real wallpaperOpacity: 1
    // -1 grey .. 0 as is
    property real wallpaperSaturation: 0
    property real wallpaperZoom: 1.08

    // ── Palette ────────────────────────────────────────────────────────
    // Fixed roles keep their tone in light and dark schemes, so a style
    // looks the same in both and only follows the wallpaper's hue.
    property color ink: light ? Colors.overSecondaryFixed : Colors.secondaryFixed
    property color inkSoft: light ? Colors.overSecondaryFixedVariant : Colors.secondaryFixedDim
    property color accent: light ? Colors.overPrimaryFixedVariant : Colors.primaryFixedDim
    property color overAccent: light ? Colors.primaryFixed : Colors.overPrimaryFixed
    property color error: Qt.hsla(Colors.error.hslHue, 0.75, light ? 0.42 : 0.74, 1)
    property string font: Config.theme.font

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, c.a * a);
    }

    visible: false
    width: 0
    height: 0
}
