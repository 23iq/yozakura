import QtQuick
import qs.modules.theme

// Places `target` at `rect` ({x, y, w, h}; a missing field is left alone)
// and glides it there on a discrete change (a setting, a state), but lands
// at once when `frame` (the container the rect is computed from) changed
// size since the last placement, and on the first placement: a resize or a
// first layout never rubber-bands (a Behavior cannot tell those apart).
// `hold`: the target is moved by hand (a drag); on release it glides back.
Item {
    id: glide

    required property Item target
    property var rect: null
    property Item frame: null
    property bool hold: false
    property int duration: Motion.glide.duration
    property int easing: Motion.glide.easing

    property real _fw: -1
    property real _fh: -1

    visible: false

    onRectChanged: glide.place(false)
    onHoldChanged: if (!glide.hold)
        glide.place(true)
    Component.onCompleted: glide.place(false)

    readonly property var _anims: [ax, ay, aw, ah]
    readonly property var _fields: [["x", "x"], ["y", "y"], ["w", "width"], ["h", "height"]]

    // `eased`: glide even if the frame changed (back from a drag)
    function place(eased) {
        const r = glide.rect;
        if (!r || !glide.target || glide.hold)
            return;
        const fw = glide.frame ? glide.frame.width : 0;
        const fh = glide.frame ? glide.frame.height : 0;
        const resized = glide._fw < 0 || fw !== glide._fw || fh !== glide._fh;
        glide._fw = fw;
        glide._fh = fh;
        const jump = glide.duration <= 0 || (resized && !eased);
        glide._fields.forEach((f, i) => {
            const a = glide._anims[i];
            a.stop();
            const v = r[f[0]];
            if (v === undefined || v === null)
                return;
            if (jump || Math.abs(glide.target[f[1]] - v) < 0.5) {
                glide.target[f[1]] = v;
            } else {
                a.to = v;
                a.start();
            }
        });
    }

    NumberAnimation {
        id: ax
        target: glide.target
        property: "x"
        duration: glide.duration
        easing.type: glide.easing
    }
    NumberAnimation {
        id: ay
        target: glide.target
        property: "y"
        duration: glide.duration
        easing.type: glide.easing
    }
    NumberAnimation {
        id: aw
        target: glide.target
        property: "width"
        duration: glide.duration
        easing.type: glide.easing
    }
    NumberAnimation {
        id: ah
        target: glide.target
        property: "height"
        duration: glide.duration
        easing.type: glide.easing
    }
}
