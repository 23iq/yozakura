import QtQuick
import qs.modules.components.kit

// The section label used everywhere: label-role text with an optional
// trailing quiet text action (`action: "Clear"` -> `triggered()`).
Item {
    id: root

    property string text: ""
    property string action: ""
    readonly property bool actionHovered: actionMouse.containsMouse

    signal triggered

    implicitWidth: label.implicitWidth + (root.action !== "" ? Space.m + actionText.implicitWidth : 0)
    implicitHeight: Math.max(label.implicitHeight, actionText.implicitHeight)

    KitText {
        id: label
        role: "label"
        text: root.text
        anchors.left: parent.left
        anchors.right: root.action !== "" ? actionText.left : parent.right
        anchors.rightMargin: root.action !== "" ? Space.m : 0
        anchors.verticalCenter: parent.verticalCenter
    }

    KitText {
        id: actionText
        role: "caption"
        text: root.action
        visible: root.action !== ""
        color: root.actionHovered ? Type.text : Type.muted
        anchors.right: parent.right
        anchors.baseline: label.baseline

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            anchors.margins: -Space.xs
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.triggered()
        }
    }
}
