import QtQuick
import "../shell/EdgeLayout.js" as EdgeLayout
import "NotchShape.js" as NotchShape

// Where the notch region (notch + its notification popup) of `width` x
// `height` sits on its edge: EdgeLayout.notchRect for the edge, notch.align
// and the bar/dock/frame insets of `env` (EdgeService.envFor), plus the
// hover strip that reveals it while hidden. Pure bindings, no layout of its
// own, so tests can place a real notch on any edge.
QtObject {
    id: root

    property var env: null
    property real width: 0
    property real height: 0
    // Depth of the hover strip from the screen edge while hidden
    property real hoverDepth: 8
    property bool revealed: true

    readonly property string position: env && env.notch && env.notch.pos ? env.notch.pos : "top"
    readonly property bool vertical: NotchShape.vertical(position)
    readonly property var rect: env ? EdgeLayout.notchRect(env, {
        along: vertical ? height : width,
        across: vertical ? width : height
    }) : ({
            x: 0,
            y: 0,
            w: width,
            h: height,
            vertical: false,
            dir: "down"
        })
    readonly property real x: rect.x
    readonly property real y: rect.y
    // Direction the notch opens in: toward the screen center
    readonly property string dir: rect.dir
    readonly property var hoverStrip: NotchShape.hoverStrip(position, rect, env ? env.screen : {
        w: 0,
        h: 0
    }, revealed ? (vertical ? rect.w : rect.h) : hoverDepth, 10)
}
