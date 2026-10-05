import QtQuick
import qs.modules.theme

// Glass surface for the glass style's chrome (black in the dark tone,
// frosted white in the light one).
// Deliberately not a StyledRect variant: the lock screen always sits on top of
// a bright or dark wallpaper, so it uses a fixed scrim from the palette
// instead of the user's bar/panel theme, which may be a light or halftone
// variant that loses contrast here.
Rectangle {
    id: root

    // Glass fill (the style's surface role) and the text drawn on it.
    property color fill: Colors.shadow
    property color ink: Colors.secondaryFixed
    // Fill strength of the glass (0..1).
    property real strength: 0.58
    // Optional accent ring (e.g. focus); hairline otherwise.
    property color ringColor: Qt.rgba(ink.r, ink.g, ink.b, 0.10)
    property real ringWidth: 1

    // Scaled by the glass "lockscreen" surface (never below the legibility floor).
    readonly property real effectiveStrength: Glass.lockOpacity(strength)

    color: Qt.rgba(fill.r, fill.g, fill.b, effectiveStrength)
    border.color: ringColor
    border.width: ringWidth
    antialiasing: true
}
