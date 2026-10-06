import QtQuick

// Tail of a popup (theme.popup.tail): a small triangle outside the popup's
// `edge`, centered at `along` px on that edge, pointing at the anchor. Drawn
// as the outer half of a rotated StyledRect square of the popup's variant, so
// it matches the surface (color, glass, border).
Item {
    id: root

    required property Item host
    property string edge: "top"
    property real along: 0
    property real size: 8
    property string variant: "popup"

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real _along: Math.max(size * 2, Math.min(along, (horizontal ? host.width : host.height) - size * 2))

    width: horizontal ? size * 2 : size
    height: horizontal ? size : size * 2
    x: horizontal ? _along - size : (edge === "left" ? -size : host.width)
    y: horizontal ? (edge === "top" ? -size : host.height) : _along - size
    clip: true

    StyledRect {
        variant: root.variant
        cornerStyled: false
        width: root.size * Math.SQRT2
        height: width
        radius: 2
        rotation: 45
        // centered on the popup edge: only the outer half shows
        x: (root.edge === "right" ? 0 : root.size) - width / 2
        y: (root.edge === "bottom" ? 0 : root.size) - height / 2
    }
}
