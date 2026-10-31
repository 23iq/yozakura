import QtQuick
import "StripTexture.js" as Texture

// The procedural material of a strip (StripTexture.js) stroked with two
// palette roles: `ink` for the grain, `accent` for the odd coloured fibre
// and the washi clouds. Clipped to the strip's rounded shape. Painted once
// per size / material / palette change, never per frame.
Canvas {
    id: root

    property string material: "plain"
    property int seed: 0
    property real radius: 0
    property color ink: "transparent"
    property color accent: "transparent"

    visible: root.material !== "plain"
    renderStrategy: Canvas.Cooperative

    onMaterialChanged: requestPaint()
    onSeedChanged: requestPaint()
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function tint(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (!root.visible || width <= 0 || height <= 0)
            return;
        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, root.radius, root.radius);
        ctx.clip();
        const list = Texture.strokes(root.material, root.seed, width, height);
        ctx.lineCap = "round";
        for (const s of list) {
            const c = s.tint === "accent" ? root.accent : root.ink;
            if (s.kind === "cloud") {
                const g = ctx.createRadialGradient(s.x1, s.y1, 0, s.x1, s.y1, s.r);
                g.addColorStop(0, root.tint(c, s.alpha));
                g.addColorStop(1, root.tint(c, 0));
                ctx.fillStyle = g;
                ctx.fillRect(s.x1 - s.r, s.y1 - s.r, s.r * 2, s.r * 2);
                continue;
            }
            ctx.strokeStyle = root.tint(c, s.alpha);
            ctx.lineWidth = s.width;
            ctx.beginPath();
            ctx.moveTo(s.x1, s.y1);
            ctx.quadraticCurveTo(s.cx, s.cy, s.x2, s.y2);
            ctx.stroke();
        }
    }
}
