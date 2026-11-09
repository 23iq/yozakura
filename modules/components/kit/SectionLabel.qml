import QtQuick
import qs.modules.components.kit

// The section label used everywhere: label-role text with an optional
// trailing quiet text action (`action: "Clear"` -> `triggered()`). The text
// is inset by `inset` (Look.rowInset) on both sides, so a label lines up with
// the text of the rows under it in every language.
Item {
    id: root

    property string text: ""
    property string action: ""
    property int inset: Look.rowInset
    // Keyboard focus / a pending confirmation on the action: drawn as hovered.
    property bool actionHighlighted: false
    readonly property bool actionHovered: actionMouse.containsMouse

    signal triggered

    implicitWidth: label.implicitWidth + root.inset * 2 + (root.action !== "" ? Space.m + actionText.implicitWidth : 0)
    implicitHeight: Math.max(label.implicitHeight, actionText.implicitHeight)

    KitText {
        id: label
        role: "label"
        text: root.text
        anchors.left: parent.left
        anchors.leftMargin: root.inset
        anchors.right: root.action !== "" ? actionText.left : parent.right
        anchors.rightMargin: root.action !== "" ? Space.m : root.inset
        anchors.verticalCenter: parent.verticalCenter
    }

    KitText {
        id: actionText
        role: "caption"
        text: root.action
        visible: root.action !== ""
        color: root.actionHovered || root.actionHighlighted ? Type.text : Type.muted
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.baseline: label.baseline

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            anchors.leftMargin: -Space.s
            anchors.rightMargin: -Space.s
            anchors.topMargin: -Math.max(Space.xs, (Space.controlS - actionText.height) / 2)
            anchors.bottomMargin: anchors.topMargin
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.triggered()
        }
    }
}
