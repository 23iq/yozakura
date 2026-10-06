import QtQuick
import qs.modules.theme
import qs.config

// Outline of the attached notch: one continuous stroke along the body and
// its two concave screen corners, drawn for a top or bottom `edge` (a side
// notch turns this item, see NotchSilhouette).
Canvas {
    id: root

    property string edge: "top"
    property int cornerSize: 0
    // Radius of the two corners facing the screen center
    property real radius: 0

    readonly property var borderData: Config.theme.srBg.border
    readonly property int borderWidth: borderData[1]
    readonly property color borderColor: Config.resolveColor(borderData[0])
    readonly property string paintKey: [width, height, edge, cornerSize, radius, borderWidth, borderColor, Colors.primary].join("|")
    onPaintKeyChanged: requestPaint()

    antialiasing: true

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (borderWidth <= 0)
            return;
        ctx.strokeStyle = borderColor;
        ctx.lineWidth = borderWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";

        const o = borderWidth / 2; // keep the stroke inside
        const c = cornerSize;
        const r = radius;
        const wCenter = width - c * 2;
        const yBottom = height - o;
        ctx.beginPath();
        if (edge === "top") {
            ctx.moveTo(o, o);
            if (c > 0)
                ctx.arc(o, c, c - o, 3 * Math.PI / 2, 2 * Math.PI);
            ctx.lineTo(c, yBottom - r);
            if (r > 0)
                ctx.arcTo(c, yBottom, c + r, yBottom, r - o);
            ctx.lineTo(c + wCenter - r, yBottom);
            if (r > 0)
                ctx.arcTo(c + wCenter, yBottom, c + wCenter, yBottom - r, r - o);
            ctx.lineTo(c + wCenter, c);
            if (c > 0)
                ctx.arc(width - o, c, c - o, Math.PI, 3 * Math.PI / 2);
        } else {
            ctx.moveTo(o, yBottom);
            if (c > 0)
                ctx.arc(o, height - c, c - o, Math.PI / 2, 0, true);
            ctx.lineTo(c, o + r);
            if (r > 0)
                ctx.arcTo(c, o, c + r, o, r - o);
            ctx.lineTo(c + wCenter - r, o);
            if (r > 0)
                ctx.arcTo(c + wCenter, o, c + wCenter, o + r, r - o);
            ctx.lineTo(c + wCenter, height - c);
            if (c > 0)
                ctx.arc(width - o, height - c, c - o, Math.PI, Math.PI / 2, true);
        }
        ctx.stroke();
    }
}
