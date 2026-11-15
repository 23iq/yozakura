import QtQuick
import Quickshell
import qs.modules.desktop
import "../stages/DesktopPlace.js" as DesktopPlace

// A depth clock style itself: the real DepthClock (same placement and ink)
// laid out at the first screen's size, then cropped to the clock (its
// time (its layout's `behind` box, centred, air around) and scaled into this item,
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

    readonly property var layout: clock.placement && clock.placement.layout ? clock.placement.layout : null
    // the clock's box on the screen ({x, y, w, h}), null before it is laid out
    readonly property var bounds: root.layout ? root.layout.bounds ?? null : null
    // a picture shows the time itself (the layout's `behind` box: the
    // digits), big: the small furniture around it (a date column, a seal,
    // a date strip) would only be specks at card size
    readonly property var cropBox: root.layout ? root.layout.behind ?? root.bounds : null
    readonly property bool cropped: root.crop && !!root.cropBox && root.cropBox.w > 0 && root.cropBox.h > 0
    // the side its layout put it on ("left" | "right" | "")
    readonly property string side: DesktopPlace.sideOf(root.bounds, root.screenW)
    // the time and a third of its size of air, whole in the picture (never
    // touching its edges)
    readonly property real fit: root.cropped ? Math.min(root.width / (root.cropBox.w * 1.35), root.height / (root.cropBox.h * 1.35)) : Math.max(root.width / root.screenW, root.height / root.screenH)

    clip: true

    // a picture: only the time and its air (what lies around it is cut)
    Item {
        id: window
        readonly property real airW: root.cropped ? Math.min(root.width, root.cropBox.w * root.fit * 1.3) : root.width
        readonly property real airH: root.cropped ? Math.min(root.height, root.cropBox.h * root.fit * 1.3) : root.height
        x: Math.round((root.width - window.airW) / 2)
        y: Math.round((root.height - window.airH) / 2)
        width: window.airW
        height: window.airH
        clip: root.cropped

        Item {
            id: stage
            width: root.screenW
            height: root.screenH
            x: (root.cropped ? root.width / 2 - (root.cropBox.x + root.cropBox.w / 2) * root.fit : 0) - window.x
            y: (root.cropped ? root.height / 2 - (root.cropBox.y + root.cropBox.h / 2) * root.fit : 0) - window.y
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
}
