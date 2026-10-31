pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.components.kit

// Seven-segment LCD digits ("21:05") in the clock's ink, unlit segments
// faintly visible (kit SegmentDigits). 12h adds a small AM / PM after the
// digits; a vertical bar stacks hours, minutes and the suffix. Digit height
// follows the font size.
Item {
    id: root

    required property var clock

    objectName: "faceSegment"
    readonly property real digit: Math.max(10, Math.round(root.clock.fontSize * 1.3))
    readonly property var lines: root.clock.vertical ? [root.clock.parts.hours, root.clock.parts.minutes] : [root.clock.parts.hours + ":" + root.clock.parts.minutes]

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Grid {
        id: column
        columns: root.clock.vertical ? 1 : 2
        spacing: Math.round(root.digit / 3)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: root.lines

            SegmentDigits {
                required property string modelData
                text: modelData
                digitHeight: root.digit
                color: root.clock.textColor
                offOpacity: 0.06
            }
        }

        Text {
            visible: root.clock.parts.suffix !== ""
            text: root.clock.parts.suffix
            color: root.clock.textColor
            font.family: root.clock.fontFamily
            font.pixelSize: Math.round(root.clock.fontSize * 0.6)
            font.weight: root.clock.fontWeight
        }
    }
}
