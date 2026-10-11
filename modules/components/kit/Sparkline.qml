import QtQuick
import qs.modules.components.kit

// A small area chart of recent values (0..1, oldest first): a line in
// `color` over a soft fill fading to the bottom. Draws nothing with fewer
// than two values. Repaints only when the values, size or color change.
Canvas {
    id: root

    property var values: []
    property color color: Type.progress
    property real lineWidth: Space.stroke - 1
    property real fillOpacity: 0.28
    readonly property int count: root.values && root.values.length > 0 ? root.values.length : 0

    implicitWidth: Space.controlL
    implicitHeight: Space.l
    antialiasing: true

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

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
