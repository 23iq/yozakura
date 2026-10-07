import QtQuick
import qs.config
import qs.modules.components.signatures
import "indicators/IndicatorStyles.js" as Styles
import qs.modules.theme

// Active workspace indicator of the bar's workspace strip. Owns the box
// (the active slot, stretched between two animated indices for the
// stretchy transition) and loads the configured style
// (workspaces.indicatorStyle, registry indicators/IndicatorStyles.js) into it.
Item {
    id: root

    required property bool vertical
    required property int index
    required property real slotSize
    required property real padding
    required property bool occupied
    required property real baseRadius
    required property int workspaceId
    // Style id; the config value by default (settings previews pass their own).
    property string styleId: Config.workspaces.indicatorStyle

    readonly property var style: Styles.get(styleId)

    // Two animated indices: idx1 leads, idx2 trails.
    property real idx1: index
    property real idx2: index

    readonly property var geometry: Styles.box(idx1, idx2, slotSize, padding, vertical)
    x: geometry.x
    y: geometry.y
    width: geometry.width
    height: geometry.height

    Behavior on idx1 {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 3
            easing.type: Motion.morph.easing
        }
    }
    Behavior on idx2 {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    BrushHighlight {
        shown: root.styleId !== "brush"
        spread: 2
    }

    // Unsized: the style binds its own geometry to `indicator`.
    Loader {
        objectName: "indicatorStyle"
        source: Qt.resolvedUrl("indicators/" + root.style.component)
        onLoaded: item.indicator = root
    }
}
