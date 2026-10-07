import QtQuick
import qs.modules.components.kit

// An action of a menu (power, tools): an IconButton with an optional label
// under it. A `confirm` action (shutdown, reboot, log out) fires only after
// a full hold: a HoldToConfirm ring fills around the button while the mouse
// or Enter / Space is held; plain actions fire on click / Enter at once.
// Keyboard focus shows the hover look (`highlighted`).
FocusScope {
    id: root

    property string icon: ""
    property string text: ""
    property string size: "m"
    property bool showLabel: false
    property string labelRole: "caption"
    property bool active: false
    property bool confirm: false
    property bool highlighted: root.activeFocus
    readonly property bool hovered: mouse.containsMouse
    readonly property alias hold: hold
    readonly property alias button: button

    signal activated
    signal entered

    function press() {
        if (root.confirm)
            hold.press();
        else
            root.activated();
    }

    function release() {
        if (root.confirm)
            hold.release();
    }

    onActiveFocusChanged: {
        if (!activeFocus)
            root.release();
    }
    onHighlightedChanged: {
        if (!highlighted)
            root.release();
    }
    onVisibleChanged: {
        if (!visible)
            root.release();
    }
    onEnabledChanged: {
        if (!enabled)
            root.release();
    }

    implicitWidth: Math.max(button.width, root.showLabel ? label.implicitWidth : 0)
    implicitHeight: button.height + (root.showLabel ? Space.l + label.implicitHeight : 0)

    Accessible.role: Accessible.Button
    Accessible.name: root.text

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.press();
    }
    Keys.onReleased: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
            return;
        event.accepted = true;
        if (!event.isAutoRepeat)
            root.release();
    }

    IconButton {
        id: button
        anchors.horizontalCenter: parent.horizontalCenter
        icon: root.icon
        size: root.size
        active: root.active
        highlighted: root.highlighted || mouse.containsMouse
        scale: mouse.pressed ? 0.94 : 1
    }

    HoldToConfirm {
        id: hold
        objectName: "holdRing"
        width: button.width + Space.s * 2
        height: width
        anchors.centerIn: button
        onConfirmed: root.activated()
    }

    KitText {
        id: label
        visible: root.showLabel
        anchors.top: button.bottom
        // Clear of the hold ring (Space.s around the button).
        anchors.topMargin: Space.l
        anchors.horizontalCenter: parent.horizontalCenter
        role: root.labelRole
        color: root.highlighted || mouse.containsMouse ? Type.text : Type.color(root.labelRole)
        text: root.text
    }

    MouseArea {
        id: mouse
        anchors.fill: button
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: root.entered()
        onPressed: root.press()
        onReleased: root.release()
        onCanceled: root.release()
    }
}
