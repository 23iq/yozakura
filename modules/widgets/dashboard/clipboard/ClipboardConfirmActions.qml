pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Cancel / confirm pair (kit IconButtons) at the right edge of a row in
// delete and alias modes. `buttonIndex` (0 cancel, 1 confirm) is the
// keyboard cursor; hovering moves it.
Row {
    id: actions

    property bool shown: false
    property int buttonIndex: 0

    signal hovered(int index)
    signal cancelled
    signal confirmed

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.rightMargin: Space.s
    spacing: Space.xs
    visible: actions.shown

    Repeater {
        model: [Icons.cancel, Icons.accept]

        IconButton {
            id: button
            required property string modelData
            required property int index

            size: "s"
            icon: button.modelData
            highlighted: actions.buttonIndex === button.index
            onHoveredChanged: {
                if (button.hovered && !button.highlighted)
                    actions.hovered(button.index);
            }
            onClicked: button.index === 0 ? actions.cancelled() : actions.confirmed()
        }
    }
}
