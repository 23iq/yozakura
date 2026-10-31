import QtQuick
import qs.modules.theme
import "PanoramaMath.js" as PanoramaMath

// The camera of a panorama: glides the viewport to `target` (Motion.pan) and
// gives each parallax layer its x for the current moment (layerX). Jumps
// instead while `animate` is false (first placement) or motion is off.
Item {
    id: root

    property real target: 0
    property bool animate: false

    property real fromX: 0
    property real toX: 0
    property real progress: 1
    readonly property real currentX: fromX + (toX - fromX) * progress
    readonly property bool moving: anim.running

    width: 0
    height: 0

    function layerX(layer) {
        return PanoramaMath.layerX(fromX, toX, progress, layer);
    }

    function jump() {
        anim.stop();
        fromX = target;
        toX = target;
        progress = 1;
    }

    function move() {
        if (!animate || Motion.pan.duration <= 0) {
            jump();
            return;
        }
        if (target === toX && anim.running)
            return;
        fromX = currentX;
        toX = target;
        progress = 0;
        anim.restart();
    }

    onTargetChanged: move()
    Component.onCompleted: jump()

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Math.max(1, Motion.pan.duration)
        easing.type: Motion.pan.easing
    }
}
