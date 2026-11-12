import QtQuick
import qs.modules.theme
import qs.config

// The rounded screen corners of one output, drawn by the unified panel above
// everything else it draws (bar, notch, dock, frame, toasts). They are not in
// the panel's input mask, so clicks at the corners pass through exactly as
// they did through the former corners window and its empty mask. Hidden under
// a fullscreen window, like that window was.
Item {
    id: root

    property bool hasFullscreenWindow: false

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property int thickness: {
        const value = Config.bar?.frameThickness;
        if (typeof value !== "number")
            return 6;
        return Math.max(1, Math.min(Math.round(value), 40));
    }
    // The corner reaches past the frame when it is on.
    readonly property int cornerSize: Styling.radius(4) + (frameEnabled ? thickness : 0)

    visible: !hasFullscreenWindow

    RoundCorner {
        size: root.cornerSize
        anchors.left: root.left
        anchors.top: root.top
        corner: RoundCorner.CornerEnum.TopLeft
    }

    RoundCorner {
        size: root.cornerSize
        anchors.right: root.right
        anchors.top: root.top
        corner: RoundCorner.CornerEnum.TopRight
    }

    RoundCorner {
        size: root.cornerSize
        anchors.left: root.left
        anchors.bottom: root.bottom
        corner: RoundCorner.CornerEnum.BottomLeft
    }

    RoundCorner {
        size: root.cornerSize
        anchors.right: root.right
        anchors.bottom: root.bottom
        corner: RoundCorner.CornerEnum.BottomRight
    }
}
