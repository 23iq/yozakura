import QtQuick

// Small filled line chart of `values` (0..1, oldest first), repainted only
// when the values change.
Canvas {
    id: root

    property var values: []
    property color color: "white"
    property int capacity: 30
    property real lineWidth: 2

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values || [];
        if (v.length < 2 || width <= 0 || height <= 0)
            return;
        const step = width / Math.max(1, capacity - 1);
        const x0 = width - (v.length - 1) * step;
        const lw = lineWidth;
        const y = val => lw + (height - 2 * lw) * (1 - Math.max(0, Math.min(1, val)));
        ctx.beginPath();
        ctx.moveTo(x0, y(v[0]));
        for (let i = 1; i < v.length; i++)
            ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.lineWidth = lw;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.95);
        ctx.stroke();
        ctx.lineTo(x0 + (v.length - 1) * step, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        const g = ctx.createLinearGradient(0, 0, 0, height);
        g.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.32));
        g.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0));
        ctx.fillStyle = g;
        ctx.fill();
    }
}
