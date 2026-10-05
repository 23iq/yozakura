pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components
import qs.modules.corners
import qs.config

// Notch-style tab silhouette: a body with rounded free corners plus concave
// fillets where it meets the screen edge/frame. Same technique as Notch.qml
// (bg StyledRect masked by RoundCorner fillets, Canvas outline for srBg's
// border). Geometry is authored for a tab hanging from the top edge; the
// caller maps it onto the real edge with `edge`.
//
// startFlush/endFlush: the tab sits in a screen corner and merges with the
// side frame, so that side gets a fillet along the side edge instead of a
// top fillet and keeps a square body corner.
Item {
    id: shape

    property real bodyLength: 0      // along the attached edge
    property real bodyThickness: 0   // away from the attached edge
    property real fillet: 0
    property real bodyRadius: 0
    property bool startFlush: false
    property bool endFlush: false
    property string edge: "top"      // top | bottom | left | right
    property bool showOutline: true

    readonly property real startExtra: startFlush ? 0 : fillet
    readonly property real endExtra: endFlush ? 0 : fillet
    readonly property real localWidth: startExtra + bodyLength + endExtra
    readonly property real localHeight: bodyThickness + ((startFlush || endFlush) ? fillet : 0)

    // Offset of the body's start corner inside this item (local, top coords)
    readonly property real bodyOffset: startExtra

    width: localWidth
    height: localHeight

    // Map the top-edge geometry onto the real edge
    transform: Matrix4x4 {
        matrix: {
            const h = shape.localHeight;
            switch (shape.edge) {
            case "bottom":
                return Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, h, 0, 0, 1, 0, 0, 0, 0, 1);
            case "left":
                return Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
            case "right":
                return Qt.matrix4x4(0, -1, 0, h, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
            default:
                return Qt.matrix4x4();
            }
        }
    }

    StyledRect {
        id: fill
        variant: "bg"
        glassSurface: "bar"
        anchors.fill: parent
        radius: 0
        enabled: false
        enableBorder: false
        animateRadius: false

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: silhouetteMask
            maskThresholdMin: 0.5
            maskThresholdMax: 1.0
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: silhouetteMask
        visible: false
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            x: shape.startExtra
            y: 0
            width: shape.bodyLength
            height: shape.bodyThickness
            color: "white"
            bottomLeftRadius: shape.startFlush ? 0 : shape.bodyRadius
            bottomRightRadius: shape.endFlush ? 0 : shape.bodyRadius
        }

        // Fillets against the attached edge
        RoundCorner {
            // opacity, not visible: toggling visibility inside the mask layer loops
            opacity: !shape.startFlush && shape.fillet > 0 ? 1 : 0
            x: 0
            y: 0
            size: Math.max(shape.fillet, 1)
            corner: RoundCorner.CornerEnum.TopRight
            color: "white"
        }
        RoundCorner {
            // opacity, not visible: toggling visibility inside the mask layer loops
            opacity: !shape.endFlush && shape.fillet > 0 ? 1 : 0
            x: shape.startExtra + shape.bodyLength
            y: 0
            size: Math.max(shape.fillet, 1)
            corner: RoundCorner.CornerEnum.TopLeft
            color: "white"
        }

        // Fillets against the side frame when sitting in a corner
        RoundCorner {
            // opacity, not visible: toggling visibility inside the mask layer loops
            opacity: shape.startFlush && shape.fillet > 0 ? 1 : 0
            x: 0
            y: shape.bodyThickness
            size: Math.max(shape.fillet, 1)
            corner: RoundCorner.CornerEnum.TopLeft
            color: "white"
        }
        RoundCorner {
            // opacity, not visible: toggling visibility inside the mask layer loops
            opacity: shape.endFlush && shape.fillet > 0 ? 1 : 0
            x: shape.localWidth - shape.fillet
            y: shape.bodyThickness
            size: Math.max(shape.fillet, 1)
            corner: RoundCorner.CornerEnum.TopRight
            color: "white"
        }
    }

    // Outline following srBg's border, like the notch's outlineCanvas
    Canvas {
        id: outline
        anchors.fill: parent
        antialiasing: true

        readonly property var borderData: Config.theme.srBg.border
        readonly property int borderWidth: borderData && borderData.length > 1 ? borderData[1] : 0
        readonly property color borderColor: Config.resolveColor(borderData && borderData.length > 0 ? borderData[0] : "surfaceBright")

        visible: shape.showOutline && borderWidth > 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (borderWidth <= 0)
                return;
            ctx.strokeStyle = borderColor;
            ctx.lineWidth = borderWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            const o = borderWidth / 2;
            const f = shape.fillet;
            const L = shape.startExtra;
            const R = shape.startExtra + shape.bodyLength;
            const B = shape.bodyThickness;
            const bl = shape.startFlush ? 0 : shape.bodyRadius;
            const br = shape.endFlush ? 0 : shape.bodyRadius;

            ctx.beginPath();
            if (shape.startFlush) {
                if (f > 0)
                    ctx.arc(L + f, B + f, f + o, Math.PI, 3 * Math.PI / 2);
                else
                    ctx.moveTo(L, B - o);
            } else {
                if (f > 0)
                    ctx.arc(L - f, f, f + o, 3 * Math.PI / 2, 2 * Math.PI);
                else
                    ctx.moveTo(L + o, 0);
                ctx.lineTo(L + o, B - Math.max(bl, o));
                if (bl > 0)
                    ctx.arcTo(L + o, B - o, L + bl, B - o, Math.max(bl - o, 0));
            }
            if (shape.endFlush) {
                ctx.lineTo(R - f, B - o);
                if (f > 0)
                    ctx.arc(R - f, B + f, f + o, 3 * Math.PI / 2, 2 * Math.PI);
            } else {
                ctx.lineTo(R - Math.max(br, o), B - o);
                if (br > 0)
                    ctx.arcTo(R - o, B - o, R - o, B - br, Math.max(br - o, 0));
                ctx.lineTo(R - o, f);
                if (f > 0)
                    ctx.arc(R + f, f, f + o, Math.PI, 3 * Math.PI / 2);
            }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onBorderColorChanged: requestPaint()
        onBorderWidthChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }
    }
}
