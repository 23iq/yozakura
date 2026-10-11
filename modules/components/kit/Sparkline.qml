import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// A small area chart of recent values (0..1, oldest first): a line in
// `color` over a soft fill fading to the bottom. Draws nothing with fewer
// than two values. Repaints only when the values, size or color change.
// A sample appended to a full window (same length, oldest dropped) slides
// the drawn curve in from the right (a GPU translation of the painted
// canvas, no per-frame repaint) instead of jumping.
Item {
    id: root

    property var values: []
    property color color: Type.progress
    property real lineWidth: Space.stroke - 1
    property real fillOpacity: 0.28
    readonly property int count: root.values && root.values.length > 0 ? root.values.length : 0
    // One step between samples (the canvas holds one extra off the left edge).
    readonly property real step: root.count > 2 ? root.width / (root.count - 2) : root.width
    property real shift: 0
    property var _last: []

    implicitWidth: Space.controlL
    implicitHeight: Space.l
    clip: true

    function _appended(prev: var, next: var): bool {
        if (!prev || !next || prev.length !== next.length || next.length < 3)
            return false;
        for (let i = 0; i + 1 < next.length; i++) {
            if (Number(prev[i + 1]) !== Number(next[i]))
                return false;
        }
        return true;
    }

    onValuesChanged: {
        const slide = Motion.glide.duration > 0 && root._appended(root._last, root.values);
        root._last = root.values ? root.values.slice() : [];
        canvas.requestPaint();
        if (slide) {
            root.shift = root.step;
            glide.restart();
        }
    }

    NumberAnimation {
        id: glide
        target: root
        property: "shift"
        to: 0
        duration: Motion.glide.duration
        easing.type: Motion.glide.easing
    }

    Canvas {
        id: canvas
        // The last sample sits on the right edge; the first one, one step
        // left of the visible area (until there are only two).
        x: (root.count > 2 ? -root.step : 0) + root.shift
        width: root.count > 2 ? root.step * (root.count - 1) : root.width
        height: root.height
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onColorChanged() {
                canvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.count < 2 || width <= 0 || height <= 0)
                return;
            const top = root.lineWidth;
            const h = height - top;
            const dx = width / (root.count - 1);
            const y = i => top + h * (1 - Math.max(0, Math.min(1, Number(root.values[i]) || 0)));
            ctx.beginPath();
            ctx.moveTo(0, y(0));
            for (let i = 1; i < root.count; i++)
                ctx.lineTo(i * dx, y(i));
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, Qt.alpha(root.color, root.fillOpacity));
            grad.addColorStop(1, Qt.alpha(root.color, 0));
            ctx.fillStyle = grad;
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(0, y(0));
            for (let j = 1; j < root.count; j++)
                ctx.lineTo(j * dx, y(j));
            ctx.strokeStyle = root.color;
            ctx.lineWidth = root.lineWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }
}
