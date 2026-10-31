import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Interactive run of inline text: its content (children, e.g. KitText) is
// read as part of a line and acts like a link. Hover draws a quiet
// underline in `ink` at `underlineY` (the text's baseline), the keyboard
// ring shows while focused by Tab, Enter / Space activate. `clicked(button)`
// reports the mouse button (Qt.LeftButton for the keyboard).
Item {
    id: root

    default property alias content: holder.data
    property color ink: Type.text
    property real underlineY: height
    property int buttons: Qt.LeftButton
    property bool focusable: true
    readonly property bool hovered: hover.hovered

    signal clicked(int button)

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    activeFocusOnTab: root.focusable && root.enabled
    Accessible.role: Accessible.Link
    Accessible.onPressAction: root.clicked(Qt.LeftButton)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked(Qt.LeftButton);
            event.accepted = true;
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    // The underline: a hairline under the run, fading in on hover
    Rectangle {
        objectName: "linkUnderline"
        x: 0
        y: Math.round(root.underlineY + Space.hairline)
        width: root.width
        height: Space.hairline
        color: root.ink
        opacity: root.hovered ? 0.55 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Motion.micro.duration > 0
            NumberAnimation {
                duration: Motion.micro.duration
                easing.type: Motion.micro.easing
            }
        }
    }

    FocusRing {
        anchors.margins: -Space.xs
        radius: Space.smallRadius
        shown: root.activeFocus
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: root.buttons
        onTapped: (point, button) => root.clicked(button)
    }
}
