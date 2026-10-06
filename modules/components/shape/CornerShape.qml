import QtQuick
import qs.config
import "CornerStyle.js" as CornerStyle

// Corner style state of one StyledRect (see CornerStyle.js). Round keeps the
// ClippingRectangle path untouched. A masked style (squircle, cut, tab with
// an anchor edge) renders the rect through CornerMask instead; the content is
// then lifted out of the ClippingRectangle's round clip (the mask clips it to
// the real shape) and put back when the style returns to round.
QtObject {
    id: root

    // The StyledRect (a Quickshell ClippingRectangle)
    required property var target
    property var variantConfig: ({})
    property bool popup: false
    property string anchorEdge: ""
    // false keeps the round path whatever the theme says
    property bool enabled: true
    // [topLeft, topRight, bottomRight, bottomLeft] radii of the target
    property var radiusValues: [0, 0, 0, 0]

    readonly property var resolved: CornerStyle.resolve(root.variantConfig, Config.theme ? Config.theme.shape : null, root.popup, root.anchorEdge)
    readonly property bool masked: root.enabled && CornerStyle.needsMask(root.resolved)
    readonly property real shaderStyle: CornerStyle.shaderStyle(root.resolved.style)
    readonly property real cutSize: root.resolved.cut
    readonly property vector4d radii: {
        const r = CornerStyle.radii(root.resolved, root.radiusValues);
        return Qt.vector4d(r[0], r[1], r[2], r[3]);
    }

    property Item _clipHost: null

    // A MultiEffect layer effect (the round path's shadow) pads the layer's
    // sourceRect; the mask samples the bare item, so drop the padding.
    function resetLayerRect() {
        if (root.masked && root.target)
            root.target.layer.sourceRect = Qt.rect(0, 0, 0, 0);
    }

    function sync() {
        root.resetLayerRect();
        Qt.callLater(root.resetLayerRect);
        const content = root.target ? root.target.contentItem : null;
        if (!content)
            return;
        if (root.masked && content.parent !== root.target) {
            root._clipHost = content.parent;
            content.parent = root.target;
        } else if (!root.masked && root._clipHost && content.parent === root.target) {
            content.parent = root._clipHost;
        }
    }

    onMaskedChanged: sync()
    Component.onCompleted: sync()
}
