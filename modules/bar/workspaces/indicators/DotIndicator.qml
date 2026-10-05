import QtQuick
import qs.modules.components
import "IndicatorStyles.js" as Styles

// "dot": a small accent dot under the label (beside it on vertical bars),
// stretching into a capsule while it travels.
Item {
    id: root

    property var indicator: null
    width: indicator ? indicator.width : 0
    height: indicator ? indicator.height : 0
    readonly property var dot: indicator ? Styles.dot(width, height, indicator.slotSize, indicator.vertical) : null

    StyledRect {
        variant: "primary"
        effectHighlight: false
        enableBorder: false
        animateRadius: false
        visible: root.dot !== null
        x: root.dot ? root.dot.x : 0
        y: root.dot ? root.dot.y : 0
        width: root.dot ? root.dot.width : 0
        height: root.dot ? root.dot.height : 0
        radius: root.dot ? root.dot.radius : 0
    }
}
