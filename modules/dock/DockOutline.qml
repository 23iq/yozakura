import QtQuick
import qs.config
import qs.modules.theme

// The outline of the default dock shape (DockShape): the theme's "bg"
// border traced around the rounded body and its edge fillets, open on the
// screen edge side.
Canvas {
    id: root

    property bool shown: true
    property string position: "bottom"
    property int cornerSize: 0
    property DockShape shape: null
    readonly property bool isBottom: root.position === "bottom"
    readonly property bool isLeft: root.position === "left"
    readonly property bool isRight: root.position === "right"
    antialiasing: true

    onShownChanged: root.requestPaint()
    onPositionChanged: root.requestPaint()
    onCornerSizeChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    readonly property var borderData: Config.theme.srBg.border
    readonly property int borderWidth: borderData[1]
    readonly property color borderColor: Config.resolveColor(borderData[0])

    visible: root.shown && borderWidth > 0

    onPaint: {
        if (!root.shown || !root.shape)
            return;
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        if (borderWidth <= 0)
            return;

        ctx.strokeStyle = borderColor;
        ctx.lineWidth = borderWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "butt";

        var offset = borderWidth / 2;
        var cs = root.cornerSize;
        var hasFillets = cs > offset;
        var filletRadius = hasFillets ? cs - offset : 0;

        var tl = root.shape.topLeftRadius;
        var tr = root.shape.topRightRadius;
        var bl = root.shape.bottomLeftRadius;
        var br = root.shape.bottomRightRadius;

        ctx.beginPath();

        if (root.isBottom) {
            if (hasFillets) {
                ctx.moveTo(offset, height - offset);
                ctx.arc(offset, height - cs, filletRadius, Math.PI / 2, 0, true);
                ctx.lineTo(cs, tl > 0 ? tl + offset : offset);
                if (tl > 0)
                    ctx.arcTo(cs, offset, cs + tl, offset, tl - offset);
                else
                    ctx.lineTo(cs, offset);
                ctx.lineTo(width - cs - tr, offset);
                if (tr > 0)
                    ctx.arcTo(width - cs, offset, width - cs, offset + tr, tr - offset);
                else
                    ctx.lineTo(width - cs, offset);
                ctx.lineTo(width - cs, height - cs);
                ctx.arc(width - offset, height - cs, filletRadius, Math.PI, Math.PI / 2, true);
            } else {
                ctx.moveTo(offset, height - offset);
                ctx.lineTo(offset, tl > 0 ? tl + offset : offset);
                if (tl > 0)
                    ctx.arcTo(offset, offset, offset + tl, offset, tl - offset);
                else
                    ctx.lineTo(offset, offset);
                ctx.lineTo(width - tr - offset, offset);
                if (tr > 0)
                    ctx.arcTo(width - offset, offset, width - offset, offset + tr, tr - offset);
                else
                    ctx.lineTo(width - offset, offset);
                ctx.lineTo(width - offset, height - offset);
            }
        } else if (root.isLeft) {
            if (hasFillets) {
                ctx.moveTo(offset, offset);
                ctx.arc(cs, offset, filletRadius, Math.PI, Math.PI / 2, true);
                ctx.lineTo(width - tr - offset, cs);
                if (tr > 0)
                    ctx.arcTo(width - offset, cs, width - offset, cs + tr, tr - offset);
                else
                    ctx.lineTo(width - offset, cs);
                ctx.lineTo(width - offset, height - cs - br);
                if (br > 0)
                    ctx.arcTo(width - offset, height - cs, width - offset - br, height - cs, br - offset);
                else
                    ctx.lineTo(width - offset, height - cs);
                ctx.lineTo(cs, height - cs);
                ctx.arc(cs, height - offset, filletRadius, 3 * Math.PI / 2, Math.PI, true);
            } else {
                ctx.moveTo(offset, offset);
                ctx.lineTo(width - tr - offset, offset);
                if (tr > 0)
                    ctx.arcTo(width - offset, offset, width - offset, offset + tr, tr - offset);
                else
                    ctx.lineTo(width - offset, offset);
                ctx.lineTo(width - offset, height - br - offset);
                if (br > 0)
                    ctx.arcTo(width - offset, height - offset, width - offset - br, height - offset, br - offset);
                else
                    ctx.lineTo(width - offset, height - offset);
                ctx.lineTo(offset, height - offset);
            }
        } else if (root.isRight) {
            if (hasFillets) {
                ctx.moveTo(width - offset, offset);
                ctx.arc(width - cs, offset, filletRadius, 0, Math.PI / 2, false);
                ctx.lineTo(tl + offset, cs);
                if (tl > 0)
                    ctx.arcTo(offset, cs, offset, cs + tl, tl - offset);
                else
                    ctx.lineTo(offset, cs);
                ctx.lineTo(offset, height - cs - bl);
                if (bl > 0)
                    ctx.arcTo(offset, height - cs, offset + bl, height - cs, bl - offset);
                else
                    ctx.lineTo(offset, height - cs);
                ctx.lineTo(width - cs, height - cs);
                ctx.arc(width - cs, height - offset, filletRadius, 3 * Math.PI / 2, 2 * Math.PI, false);
            } else {
                ctx.moveTo(width - offset, offset);
                ctx.lineTo(tl + offset, offset);
                if (tl > 0)
                    ctx.arcTo(offset, offset, offset, offset + tl, tl - offset);
                else
                    ctx.lineTo(offset, offset);
                ctx.lineTo(offset, height - bl - offset);
                if (bl > 0)
                    ctx.arcTo(offset, height - offset, offset + bl, height - offset, bl - offset);
                else
                    ctx.lineTo(offset, height - offset);
                ctx.lineTo(width - offset, height - offset);
            }
        }

        ctx.stroke();
    }

    Connections {
        target: Colors
        function onPrimaryChanged() {
            root.requestPaint();
        }
    }
    // The body's corners follow the theme radius (Look.radius "surface")
    Connections {
        target: root.shape
        function onTopLeftRadiusChanged() {
            root.requestPaint();
        }
        function onTopRightRadiusChanged() {
            root.requestPaint();
        }
        function onBottomLeftRadiusChanged() {
            root.requestPaint();
        }
        function onBottomRightRadiusChanged() {
            root.requestPaint();
        }
    }
    Connections {
        target: Config.theme.srBg
        function onBorderChanged() {
            root.requestPaint();
        }
    }
}
