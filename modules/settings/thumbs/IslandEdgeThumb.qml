pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of the island's screen edge (notch.position): a small
// screen with a window and the island hanging from the edge `value`; on the
// top or bottom edge it lies along it, on a side edge it stands upright
// (as the shell draws it there: NotchPlacement), so the picture says what
// "edge" means.
ThumbGround {
    id: root

    property var entry
    property var value: "top"
    readonly property bool side: root.value === "left" || root.value === "right"
    readonly property real thick: Math.max(Space.s, Math.round(Math.min(root.width, root.height) * 0.22))
    readonly property real length: Math.round((root.side ? root.height : root.width) * 0.5)

    // a window in the middle
    Mark {
        x: Math.round(root.width * 0.26)
        y: Math.round(root.height * 0.3)
        width: Math.round(root.width * 0.48)
        height: Math.round(root.height * 0.4)
        radius: Look.radius("small", height)
        color: Qt.alpha(Colors.surface, 0.85)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.6)
    }

    // the island, hanging from its edge (its inner corners round)
    Mark {
        id: island
        readonly property real r: Math.round(root.thick * 0.5)
        width: root.side ? root.thick + island.r : root.length
        height: root.side ? root.length : root.thick + island.r
        x: root.value === "left" ? -island.r : root.value === "right" ? root.width - root.thick : Math.round((root.width - width) / 2)
        y: root.value === "top" ? -island.r : root.value === "bottom" ? root.height - root.thick : Math.round((root.height - height) / 2)
        radius: island.r
        color: Colors.surfaceContainerHighest
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.overBackground, 0.28)

        // what it shows at rest: a word and a dot, along the island
        Grid {
            x: root.value === "left" ? island.r + Math.round((root.thick - width) / 2) : root.value === "right" ? Math.round((root.thick - width) / 2) : Math.round((island.width - width) / 2)
            y: root.value === "top" ? island.r + Math.round((root.thick - height) / 2) : root.value === "bottom" ? Math.round((root.thick - height) / 2) : Math.round((island.height - height) / 2)
            columns: root.side ? 1 : 2
            spacing: Math.round(root.thick * 0.25)
            Mark {
                width: root.side ? Math.round(root.thick * 0.3) : Math.round(root.length * 0.38)
                height: root.side ? Math.round(root.length * 0.38) : Math.round(root.thick * 0.3)
                color: Qt.alpha(Colors.overBackground, 0.7)
            }
            Mark {
                width: Math.round(root.thick * 0.3)
                height: width
                color: Colors.primary
            }
        }
    }
}
