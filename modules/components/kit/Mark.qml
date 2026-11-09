import QtQuick
import qs.modules.components.kit

// A small solid shape drawn as graphics, not as a box: indicator dots and
// capsules, level grooves and fills, gauge ticks, colour swatches. Fully
// round by default (`radius` follows the short side); set `radius` for a
// squarer mark. Ink: `color` (a Type / Colors role).
Rectangle {
    radius: Math.min(width, height) / 2
    color: Type.text
}
