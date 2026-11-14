pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit

// Card picture of where corner toasts stack (notifications.position): a
// small screen with two toasts at that place (top / bottom, left / centre
// / right), the newest one marked with the accent. Auto: the toasts drawn
// faintly at the top right with a wand (the bar's side decides).
ThumbGround {
    id: root

    property var entry
    property var value: "auto"
    readonly property bool auto: root.value === "auto"
    readonly property string place: root.auto ? "top-right" : String(root.value)
    readonly property bool atBottom: root.place.indexOf("bottom") === 0
    readonly property string side: root.place.indexOf("left") >= 0 ? "left" : (root.place.indexOf("right") >= 0 ? "right" : "center")
    readonly property real unit: Math.min(root.width, root.height) / 10
    readonly property real toastW: Math.round(root.width * 0.36)
    readonly property real toastH: Math.round(root.unit * 1.7)

    Column {
        id: stack
        opacity: root.auto ? 0.45 : 1
        spacing: Math.round(root.unit * 0.5)
        x: root.side === "left" ? root.unit : root.side === "right" ? root.width - width - root.unit : Math.round((root.width - width) / 2)
        y: root.atBottom ? root.height - height - root.unit : root.unit

        Repeater {
            // the newest toast nearest the edge
            model: root.atBottom ? [false, true] : [true, false]
            delegate: Mark {
                id: toast
                required property bool modelData
                width: root.toastW
                height: root.toastH
                radius: Look.radius("small", height)
                color: Colors.surfaceContainerHighest
                border.width: Space.hairline
                border.color: Qt.alpha(Colors.overBackground, 0.2)
                Mark {
                    x: Math.round(root.unit * 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(toast.height * 0.45)
                    height: width
                    color: toast.modelData ? Colors.primary : Qt.alpha(Colors.overSurface, 0.35)
                }
                Mark {
                    x: Math.round(root.unit * 0.45 + toast.height * 0.45 + root.unit * 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(toast.width * 0.5)
                    height: Math.max(Space.hairline * 2, Math.round(root.unit * 0.35))
                    color: Qt.alpha(Colors.overSurface, toast.modelData ? 0.7 : 0.4)
                }
            }
        }
    }

    Icon {
        visible: root.auto
        anchors.centerIn: parent
        icon: Icons.magicWand
        role: "body"
        tone: "secondary"
    }
}
