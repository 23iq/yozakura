import QtQuick
import qs.config
import qs.modules.theme
import "PopupMotionKinds.js" as Kinds

// Shared popup motion (BarPopup, OptionsMenu, ...): wraps the popup surface
// and plays the theme.popup.entry kind (PopupMotionKinds.js) toward/away from
// the anchor on `shown` changes, with Motion.enter / Motion.exit. Duration 0
// (animDuration 0, game mode) jumps straight to the end state. An optional
// tail (theme.popup.tail) points at the anchor.
Item {
    id: root

    property bool shown: false
    // Opening direction from EdgeLayout.popupPlacement: down | up | left | right
    property string dir: "down"
    property string kind: Config.theme && Config.theme.popup ? Config.theme.popup.entry : "fade-scale"
    // Anchor center along the anchor edge in px (-1 = middle): motion origin
    // and tail position
    property real anchorAlong: -1
    // Travel of slide-from-anchor
    property real slide: Metrics.spacing * 2

    property bool tail: Config.theme && Config.theme.popup ? Config.theme.popup.tail : false
    property real tailSize: 8
    property string tailVariant: "popup"

    // Popup edge facing the anchor (StyledRect.anchorEdge for `tab` corners)
    readonly property string anchorEdge: Kinds.anchorEdge(root.dir)
    property real progress: 0
    readonly property bool running: anim.running
    readonly property var frame: Kinds.frame(root.kind, root.dir, root.progress, root.slide)
    readonly property var originPoint: Kinds.origin(root.dir, root.width, root.height, root.anchorAlong)

    // Exit finished (or instant): the window can hide
    signal hidden

    opacity: root.frame.opacity
    transform: [
        Scale {
            origin.x: root.originPoint.x
            origin.y: root.originPoint.y
            xScale: root.frame.scaleX
            yScale: root.frame.scaleY
        },
        Translate {
            x: root.frame.dx
            y: root.frame.dy
        }
    ]

    function play() {
        anim.stop();
        const target = root.shown ? 1 : 0;
        const token = root.shown ? Motion.enter : Motion.exit;
        if (token.duration <= 0 || root.progress === target) {
            root.progress = target;
            if (!root.shown)
                root.hidden();
            return;
        }
        anim.to = target;
        anim.duration = token.duration;
        anim.easing.type = token.easing;
        anim.easing.overshoot = token.overshoot;
        anim.start();
    }

    onShownChanged: play()

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        onFinished: {
            if (!root.shown)
                root.hidden();
        }
    }

    Loader {
        active: root.tail
        z: -1
        sourceComponent: PopupTail {
            host: root
            edge: root.anchorEdge
            along: root.dir === "left" || root.dir === "right" ? root.originPoint.y : root.originPoint.x
            size: root.tailSize
            variant: root.tailVariant
        }
    }
}
