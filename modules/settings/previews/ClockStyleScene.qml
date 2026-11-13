import QtQuick
import Quickshell
import qs.modules.desktop
import "../stages/DesktopPlace.js" as DesktopPlace

// A depth clock style itself: the real DepthClock (same placement and ink)
// laid out at the first screen's size, then cropped to the clock (its
// layout's bounds, centred, a little air around) and scaled into this item,
// on the card's plain ground (the styles are told apart by their type, not
// by the wallpaper behind them).
Item {
    id: root

    property string styleId: ""
    property string inkRole: "auto"
    // crop to the clock (a style picture); false: the whole screen (a stage)
    property bool crop: true
    // the first screen's size (a screen not measured yet: 2560x1440, the
    // styles' reference)
    readonly property var screen: (Quickshell.screens || [])[0] ?? null
    readonly property int screenW: root.screen && root.screen.width > 0 ? root.screen.width : 2560
    readonly property int screenH: root.screen && root.screen.height > 0 ? root.screen.height : 1440

    // the clock's box on the screen ({x, y, w, h}), null before it is laid out
    readonly property var bounds: clock.placement && clock.placement.layout ? clock.placement.layout.bounds ?? null : null
    readonly property bool cropped: root.crop && !!root.bounds && root.bounds.w > 0 && root.bounds.h > 0
    // the side its layout put it on ("left" | "right" | "")
    readonly property string side: DesktopPlace.sideOf(root.bounds, root.screenW)
    // the clock and a quarter of its size of air, whole in the picture
    readonly property real fit: root.cropped ? Math.min(root.width / (root.bounds.w * 1.25), root.height / (root.bounds.h * 1.25)) : Math.max(root.width / root.screenW, root.height / root.screenH)

    clip: true

    Item {
        id: stage
        width: root.screenW
        height: root.screenH
        x: root.cropped ? root.width / 2 - (root.bounds.x + root.bounds.w / 2) * root.fit : 0
        y: root.cropped ? root.height / 2 - (root.bounds.y + root.bounds.h / 2) * root.fit : 0
        scale: root.fit
        transformOrigin: Item.TopLeft

        DepthClock {
            id: clock
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
