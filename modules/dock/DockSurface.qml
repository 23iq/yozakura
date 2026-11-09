pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components
import qs.modules.components.kit

// The dock's background, filling the dock container: the default theme's
// edge-flowing DockShape (body + two concave screen corners) or the
// floating theme's rounded rect. Also the shape of the dock's analytic
// shadow (PanelShadows): shadowRadii, cornerSize and fillAlpha.
Item {
    id: root

    property string position: "bottom"
    property bool isDefault: true
    property bool isFloating: false
    property bool unifiedEffectActive: false
    // Concave corner size along the edge (default theme), 0 without
    property int cornerSize: 0
    // Size of the dock's content (the body between the concave corners)
    property real contentWidth: 0
    property real contentHeight: 0

    // The default theme's shape, for the outline (DockOutline)
    readonly property DockShape shape: dockShape
    // Corner radii of the body (tl, tr, br, bl), for the shadow
    readonly property vector4d shadowRadii: root.isDefault ? Qt.vector4d(dockShape.topLeftRadius, dockShape.topRightRadius, dockShape.bottomRightRadius, dockShape.bottomLeftRadius) : Qt.vector4d(dockBackgroundFloating.radius, dockBackgroundFloating.radius, dockBackgroundFloating.radius, dockBackgroundFloating.radius)
    // Fill colour x variant opacity: the shadow is as strong as a capture
    readonly property real fillAlpha: dockBackgroundFloating.rectOpacity * (dockBackgroundFloating.hasSolidColor ? dockBackgroundFloating.solidColor.a : 1)

    // Full background with edge fillets (default theme)
    DockShape {
        id: dockShape
        visible: root.isDefault
        anchors.fill: parent
        position: root.position
        cornerSize: root.cornerSize
        contentWidth: root.contentWidth
        contentHeight: root.contentHeight
        fullRadius: Look.radius("surface")
    }

    // Background for floating theme
    StyledRect {
        id: dockBackgroundFloating
        visible: root.isFloating
        anchors.fill: parent
        variant: "bg"
        glassSurface: "dock"
        anchorEdge: root.position
        radius: Look.radius("surface", height)
        enableBorder: !root.unifiedEffectActive
    }
}
