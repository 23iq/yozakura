import QtQuick
import Quickshell
import qs.modules.desktop

// A depth clock style itself: the real DepthClock (same placement and ink)
// laid out at the first screen's size and scaled into this item, on the
// card's plain ground (the styles are told apart by their type, not by the
// wallpaper behind them).
Item {
    id: root

    property string styleId: ""
    property string inkRole: "auto"
    // the first screen's size (a screen not measured yet: 2560x1440, the
    // styles' reference)
    readonly property var screen: (Quickshell.screens || [])[0] ?? null
    readonly property int screenW: root.screen && root.screen.width > 0 ? root.screen.width : 2560
    readonly property int screenH: root.screen && root.screen.height > 0 ? root.screen.height : 1440

    clip: true

    Item {
        id: stage
        width: root.screenW
        height: root.screenH
        scale: Math.max(root.width / root.screenW, root.height / root.screenH)
        transformOrigin: Item.TopLeft

        DepthClock {
            anchors.fill: parent
            // the style itself on a plain ground: no wallpaper, no matte
            wallpaperPath: ""
            waitForMask: false
            isVideo: false
            styleId: root.styleId
            inkRole: root.inkRole
        }
    }
}
