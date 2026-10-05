import QtQuick
import qs.modules.theme

// Base interface of every desktop clock style (see ClockStyleRegistry.js).
//
// DepthClock instantiates a style twice: once with part "behind" (drawn
// under the wallpaper subject) and once with part "front" (over it). Both
// instances get the same inputs, lay out identically and each shows only
// its own part, so the two halves always line up.
Item {
    id: style

    // "behind" | "front"
    property string part: "behind"
    property date now: new Date()
    // Backdrop behind the clock is bright: switch to dark ink.
    property bool light: false
    // Placement side and geometry from the registry entry's layout().
    property string side: "right"
    property var layout: null
    property bool use12h: false
    // Colour transition length (Config.animDuration; 0 = none).
    property int animDuration: 0

    readonly property bool isBehind: part === "behind"
    readonly property bool isFront: part === "front"

    // "auto" or a palette role (desktop.depthClockInk) the time is drawn in.
    property string inkRole: "auto"

    // Ink roles. Auto uses only "fixed" roles: they keep their tone in light
    // and dark schemes, so contrast follows the wallpaper, not the shell
    // theme (primaryFixedDim is what `primary` is in a dark scheme). A
    // chosen role is used as is; the halo then contrasts with that ink.
    readonly property color customInk: inkRole !== "auto" && Colors[inkRole] !== undefined ? Colors[inkRole] : "transparent"
    readonly property bool custom: customInk.a > 0
    readonly property bool inkIsLight: custom && (0.2126 * customInk.r + 0.7152 * customInk.g + 0.0722 * customInk.b) > 0.5
    readonly property color ink: custom ? customInk : (light ? Colors.overPrimaryFixedVariant : Colors.primaryFixed)
    readonly property color inkSoft: custom ? Qt.rgba(customInk.r, customInk.g, customInk.b, 0.86) : (light ? Colors.overPrimaryFixedVariant : Colors.primaryFixedDim)
    readonly property color accent: custom ? customInk : (light ? Colors.overPrimaryFixedVariant : Colors.primaryFixedDim)
    readonly property color halo: custom ? (inkIsLight ? Colors.shadow : Qt.rgba(1, 1, 1, 1)) : (light ? Colors.primaryFixed : Colors.shadow)
    // Readable colour on an `ink` fill (seals, badges).
    readonly property color overInk: custom ? (inkIsLight ? Qt.rgba(0.08, 0.08, 0.08, 1) : Qt.rgba(1, 1, 1, 1)) : (light ? Colors.primaryFixed : Colors.overPrimaryFixed)
    // Halo strength: softer on bright backdrops, where it only lifts the ink.
    readonly property real haloOpacity: custom ? (inkIsLight ? 0.55 : 0.35) : (light ? 0.3 : 0.6)

    anchors.fill: parent
}
