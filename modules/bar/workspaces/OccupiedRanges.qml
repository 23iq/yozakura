pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.look
import qs.modules.theme

// The quiet boxes behind runs of workspaces that have windows (`ranges`:
// [{start, end}] slot indices), along the strip in either orientation. Kit
// languages draw the language's hover fill; classic the theme's "focus".
Item {
    id: root

    property bool vertical: false
    property var ranges: []
    property real slot: 0
    property real radius: 0

    Repeater {
        model: root.ranges

        Item {
            id: range
            required property var modelData

            readonly property real length: (range.modelData.end - range.modelData.start + 1) * root.slot
            x: root.vertical ? 0 : range.modelData.start * root.slot
            y: root.vertical ? range.modelData.start * root.slot : 0
            width: root.vertical ? root.slot : range.length
            height: root.vertical ? range.length : root.slot

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 100)
                    easing.type: Motion.morph.easing
                }
            }
            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 100)
                    easing.type: Motion.morph.easing
                }
            }
            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 100)
                    easing.type: Motion.morph.easing
                }
            }
            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Math.max(0, Config.animDuration - 100)
                    easing.type: Motion.morph.easing
                }
            }

            StyledRect {
                anchors.fill: parent
                visible: BarLook.classic
                variant: "focus"
                radius: root.radius
                opacity: Config.theme.srFocus.opacity
            }

            Rectangle {
                anchors.fill: parent
                visible: !BarLook.classic
                radius: BarLook.groupRadius(root.radius)
                color: Look.controlFill(true)
            }
        }
    }
}
