import QtQuick
import qs.modules.components
import "IndicatorStyles.js" as Styles

// "underline": a thin accent bar under the label (beside it on vertical
// bars); the label itself turns accent colored.
Item {
    id: root

    property var indicator: null
    width: indicator ? indicator.width : 0
    height: indicator ? indicator.height : 0
    readonly property var bar: indicator ? Styles.underline(width, height, indicator.slotSize, indicator.vertical) : null

    StyledRect {
        variant: "primary"
        effectHighlight: false
        enableBorder: false
        animateRadius: false
        visible: root.bar !== null
        x: root.bar ? root.bar.x : 0
        y: root.bar ? root.bar.y : 0
        width: root.bar ? root.bar.width : 0
        height: root.bar ? root.bar.height : 0
        radius: root.bar ? root.bar.radius : 0
    }
}
