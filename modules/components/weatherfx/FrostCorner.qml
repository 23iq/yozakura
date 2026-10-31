import QtQuick
import qs.modules.theme

// Frost in one corner of a surface (FrostCorners): a frosted patch with
// crystalline grain and ice ferns (feathers at 60°) growing in from the edges, a
// few sparkles. Painted once per size / palette, never per frame; it creeps
// in (scale + fade from the corner) when it appears with motion on.
Canvas {
    id: root

    // 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left
    property int corner: 0
    property real level: 0.5
    property real strength: 1
    property bool animate: false
    property int salt: 0
    property real radius: 0
    readonly property color ice: WeatherFx.ice

    readonly property bool flipX: root.corner === 1 || root.corner === 2
    readonly property bool flipY: root.corner === 2 || root.corner === 3
    transformOrigin: root.corner === 0 ? Item.TopLeft : (root.corner === 1 ? Item.TopRight : (root.corner === 2 ? Item.BottomRight : Item.BottomLeft))

    function rgba(c: color, a: real): string {
        const k = Math.max(0, Math.min(1, a));
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + k.toFixed(3) + ")";
    }

    // Rounded corner of the surface: frost never paints outside it
    function clipCorner(ctx: var, R: real): void {
        const c = Math.min(root.radius, R);
        ctx.beginPath();
        ctx.moveTo(c, 0);
        ctx.lineTo(R, 0);
        ctx.lineTo(R, R);
        ctx.lineTo(0, R);
        ctx.lineTo(0, c);
        ctx.arcTo(0, 0, c, 0, c);
        ctx.closePath();
        ctx.clip();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const R = root.width;
        if (R <= 0)
            return;
        const k = root.strength;
        const r = WeatherFx.rng(root.salt * 31 + root.corner * 17 + 5);
        ctx.translate(root.flipX ? R : 0, root.flipY ? R : 0);
        ctx.scale(root.flipX ? -1 : 1, root.flipY ? -1 : 1);
        root.clipCorner(ctx, R);

        // Frosted patch: a cold haze with crystalline grain, thinning out
        const g = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
        g.addColorStop(0, root.rgba(root.ice, 0.16 * k));
        g.addColorStop(0.5, root.rgba(root.ice, 0.05 * k));
        g.addColorStop(1, root.rgba(root.ice, 0));
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, R, R);
        const grains = Math.round(R * R / 30 * (0.6 + root.level * 0.6));
        for (let i = 0; i < grains; i++) {
            const d = R * Math.pow(r(), 1.7);
            const a = r() * Math.PI / 2;
            const fade = Math.pow(1 - d / R, 1.5);
            ctx.fillStyle = root.rgba(root.ice, (0.08 + r() * 0.22) * fade * k);
            ctx.fillRect(Math.cos(a) * d, Math.sin(a) * d, 1, 1);
        }

        // Ice ferns: a gently curving spine with feathers at 60° on both
        // sides, shorter toward the tip
        ctx.lineCap = "round";
        const line = function (x0, y0, x1, y1, alpha, w) {
            ctx.strokeStyle = root.rgba(root.ice, alpha * k);
            ctx.lineWidth = w;
            ctx.beginPath();
            ctx.moveTo(x0, y0);
            ctx.lineTo(x1, y1);
            ctx.stroke();
        };
        const fern = function (x, y, ang, len, alpha, depth) {
            const steps = depth === 0 ? 14 : 5;
            const bend = (r() - 0.5) * 0.06;
            let px = x, py = y, a = ang;
            for (let s = 0; s < steps; s++) {
                const t = s / steps;
                a += bend + (r() - 0.5) * 0.05;
                const nx = px + Math.cos(a) * len / steps;
                const ny = py + Math.sin(a) * len / steps;
                const fade = alpha * (1 - t * 0.75);
                line(px, py, nx, ny, fade, depth === 0 ? 1.1 : 0.7);
                const feather = len * (depth === 0 ? 0.26 : 0.32) * (1 - t * 0.8);
                if (feather > 1.5 && s > 0) {
                    for (let side = -1; side <= 1; side += 2) {
                        const fa = a + side * Math.PI / 3;
                        if (depth === 0 && feather > 6)
                            fern(px, py, fa, feather, fade * 0.8, 1);
                        else
                            line(px, py, px + Math.cos(fa) * feather, py + Math.sin(fa) * feather, fade * 0.75, 0.6);
                    }
                }
                px = nx;
                py = ny;
            }
        };
        const n = 2 + Math.round(root.level * 2);
        for (let i = 0; i < n; i++) {
            // Spines start along the two edges near the corner and grow in
            const onTop = i % 2 === 0;
            const off = R * (0.08 + r() * 0.3);
            const ang = (onTop ? 0.25 + r() * 0.35 : 0.9 + r() * 0.35) * Math.PI / 2;
            fern(onTop ? off : 0, onTop ? 0 : off, ang, R * (0.45 + r() * 0.4), 0.42, 0);
        }

        // Sparkles
        const sparks = 3 + Math.round(root.level * 5);
        for (let i = 0; i < sparks; i++) {
            const d = R * 0.6 * Math.pow(r(), 1.4);
            const a = r() * Math.PI / 2;
            ctx.fillStyle = root.rgba(root.ice, 0.85 * k * (1 - d / R));
            ctx.beginPath();
            ctx.arc(Math.cos(a) * d, Math.sin(a) * d, 0.7 + r() * 0.6, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    onWidthChanged: requestPaint()
    onIceChanged: requestPaint()
    onLevelChanged: requestPaint()
    onStrengthChanged: requestPaint()

    // Creeping in from the corner
    scale: 1
    Component.onCompleted: {
        if (root.animate)
            creep.start();
    }
    ParallelAnimation {
        id: creep
        NumberAnimation {
            target: root
            property: "scale"
            from: 0.45
            to: 1
            duration: WeatherFx.ms(2600)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: WeatherFx.ms(1800)
        }
    }
}
