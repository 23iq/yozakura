import QtQuick
import qs.modules.theme
import qs.modules.settings.previews
import "../Ui.js" as Ui

// Card picture of a corner style (theme.shape.corners): a panel hanging
// from the top edge, outlined with the style `value` (round | squircle |
// cut | tab: square where the panel meets its edge, round elsewhere).
ScreenBackdrop {
    id: root

    property var entry
    property var value: "round"
    readonly property color fill: Ui.alpha(Colors.surface, 0.92)
    readonly property color edge: Colors.primary

    onValueChanged: shape.requestPaint()
    onFillChanged: shape.requestPaint()
    onEdgeChanged: shape.requestPaint()

    Canvas {
        id: shape
        x: Math.round((root.width - width) / 2)
        // a tab hangs from the top edge it squares its corners on
        y: root.value === "tab" ? -2 : Math.round((root.height - height) / 2)
        width: Math.round(root.width * 0.62)
        height: Math.round(root.height * 0.66)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        // One corner from (ax, ay) to (bx, by) around the box corner (cx, cy).
        function corner(ctx, style, ax, ay, cx, cy, bx, by) {
            if (style === "square") {
                ctx.lineTo(cx, cy);
                ctx.lineTo(bx, by);
            } else if (style === "cut") {
                ctx.lineTo(bx, by);
            } else if (style === "squircle") {
                ctx.bezierCurveTo(ax + (cx - ax) * 0.9, ay + (cy - ay) * 0.9, bx + (cx - bx) * 0.9, by + (cy - by) * 0.9, bx, by);
            } else {
                ctx.quadraticCurveTo(cx, cy, bx, by);
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const s = 2;
            const w = width - s * 2, h = height - s * 2;
            const r = Math.min(w, h) * 0.32;
            const v = String(root.value);
            const top = v === "tab" ? "square" : v;
            const bottom = v === "tab" ? "round" : v;
            ctx.beginPath();
            ctx.moveTo(s + r, s);
            ctx.lineTo(s + w - r, s);
            corner(ctx, top, s + w - r, s, s + w, s, s + w, s + r);
            ctx.lineTo(s + w, s + h - r);
            corner(ctx, bottom, s + w, s + h - r, s + w, s + h, s + w - r, s + h);
            ctx.lineTo(s + r, s + h);
            corner(ctx, bottom, s + r, s + h, s, s + h, s, s + h - r);
            ctx.lineTo(s, s + r);
            corner(ctx, top, s, s + r, s, s, s + r, s);
            ctx.closePath();
            ctx.fillStyle = root.fill;
            ctx.fill();
            ctx.lineWidth = 2;
            ctx.strokeStyle = root.edge;
            ctx.stroke();
        }
    }
}
