import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.config

// One power action as a rounded tile: icon, optional label below, and a
// HoldToConfirm ring for destructive actions (`confirm`). Click/Enter fires
// plain actions at once; confirm actions fire only after a full hold.
FocusScope {
    id: root

    required property var action
    property int size: Metrics.rowHeight
    property bool showLabel: false
    property bool selected: activeFocus

    readonly property bool confirm: !!(action && action.confirm)

    signal activated
    signal hovered

    implicitWidth: size
    implicitHeight: size + (showLabel ? label.implicitHeight + Metrics.spacing : 0)

    function pressAction() {
        if (root.confirm)
            hold.press();
        else
            root.activated();
    }

    function releaseAction() {
        if (root.confirm)
            hold.release();
    }

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.pressAction();
    }
    Keys.onReleased: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.releaseAction();
    }

    StyledRect {
        id: face
        variant: root.selected || mouse.containsMouse ? "primary" : "common"
        width: root.size
        height: root.size
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Styling.radius(4)
        scale: mouse.pressed ? 0.94 : 1

        Behavior on scale {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.action ? root.action.icon : ""
            color: face.variant === "primary" ? Styling.srItem("primary") : (root.confirm ? Colors.error : Colors.overBackground)
            font.family: Icons.font
            font.pixelSize: Math.round(root.size * 0.42)
        }

        HoldToConfirm {
            id: hold
            anchors.fill: parent
            anchors.margins: -3
            color: Colors.error
            onConfirmed: root.activated()
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered()
            onPressed: root.pressAction()
            onReleased: root.releaseAction()
            onCanceled: root.releaseAction()
        }
    }

    Text {
        id: label
        visible: root.showLabel
        anchors.top: face.bottom
        anchors.topMargin: Metrics.spacing
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.action ? root.action.label : ""
        color: Colors.overBackground
        font.family: Config.defaultFont
        font.pixelSize: Styling.fontSize(0)
    }
}
