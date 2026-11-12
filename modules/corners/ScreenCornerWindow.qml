import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.globals

// One rounded screen corner as its own corner-sized layer surface, anchored
// to the two edges of `corner` (a RoundCorner.CornerEnum value). Input passes
// through (empty mask) and it reserves nothing.
PanelWindow {
    id: window

    property int corner: RoundCorner.CornerEnum.TopLeft
    property int size: 1

    readonly property bool atTop: corner === RoundCorner.CornerEnum.TopLeft || corner === RoundCorner.CornerEnum.TopRight
    readonly property bool atLeft: corner === RoundCorner.CornerEnum.TopLeft || corner === RoundCorner.CornerEnum.BottomLeft

    // A layer surface must not be 0 px along an edge it is not stretched on.
    implicitWidth: Math.max(1, size)
    implicitHeight: Math.max(1, size)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: Brand.namespace("screenCorners")
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: null
    }

    anchors {
        top: window.atTop
        bottom: !window.atTop
        left: window.atLeft
        right: !window.atLeft
    }

    RoundCorner {
        size: window.size
        corner: window.corner
    }
}
