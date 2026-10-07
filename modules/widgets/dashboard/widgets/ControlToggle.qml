import QtQuick
import qs.modules.components
import qs.modules.components.kit

// A quick-controls toggle: a kit IconButton (`active` while the feature is
// on) that also answers right-click and press-and-hold (`more()`: open its
// panel) and shows a tooltip.
IconButton {
    id: root

    property string tooltipText: ""
    signal more

    highlighted: area.containsMouse

    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        pressAndHoldInterval: 1000
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.more();
            else
                root.clicked();
        }
        onPressAndHold: root.more()

        StyledToolTip {
            visible: area.containsMouse && root.tooltipText !== ""
            tooltipText: root.tooltipText
        }
    }
}
