pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import "ToastModel.js" as ToastModel

// One corner toast: the latest notification of a popup group (one app, or
// one notification when notifications.groupByApp is off) on a kit Surface.
// The rest of the group is a compact stack: up to two sheets peek out from
// under the card, away from the screen edge (`stackUp` for bottom corners),
// and the caption counts them. Hover pauses the group's timers and shows
// the dismiss button; click activates, middle click dismisses the group.
Item {
    id: root

    property var group: null
    property bool stackUp: false
    // Content and actions of the group (shared with the strips)
    readonly property ToastGroup toast: ToastGroup {
        group: root.group
    }
    readonly property var notifications: root.toast.notifications
    readonly property var latest: root.toast.latest
    readonly property int extra: root.toast.extra
    readonly property int depth: ToastModel.stackDepth(root.notifications.length)
    readonly property int peek: Space.m

    implicitHeight: card.height + root.depth * root.peek

    function dismiss(): void {
        root.toast.dismiss();
    }

    function hold(on: bool): void {
        root.toast.hold(on);
    }

    HoverHandler {
        id: hover
        onHoveredChanged: root.hold(hovered)
    }

    // The stack: sheets behind the card, each a little narrower and quieter.
    // Each sheet shows only its own `peek` strip past the one in front of it
    // (a clip), so translucent boxes never show through each other.
    Repeater {
        model: root.depth

        Item {
            id: strip
            objectName: "toastSheet"
            required property int index
            readonly property int step: index + 1
            z: -step
            x: Space.m * step
            y: root.stackUp ? card.y - root.peek * step : card.y + card.height + root.peek * (step - 1)
            width: root.width - 2 * Space.m * step
            height: root.peek
            clip: true

            Surface {
                y: root.stackUp ? 0 : root.peek - card.height
                width: strip.width
                height: card.height
                floating: true
                glassSurface: "popups"
                opacity: ToastModel.sheetOpacity(strip.step)
                padding: 0
            }
        }
    }

    // The card: one floating kit Surface sized to its content. Its own box
    // (StyledRect) draws the fill, edge and shadow; no extra layer on top.
    Surface {
        id: card
        objectName: "toastCard"
        y: root.stackUp ? root.depth * root.peek : 0
        width: root.width
        height: content.implicitHeight + 2 * card.padding
        floating: true
        glassSurface: "popups"
        enableShadow: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    root.dismiss();
                else
                    root.toast.activate();
            }
        }

        ToastCard {
            id: content
            objectName: "toastContent"
            width: card.width - 2 * card.padding
            notification: root.latest
            extra: root.extra
            hovered: hover.hovered
            onDismissRequested: root.dismiss()
            onActionInvoked: identifier => root.toast.invoke(identifier)
        }
    }
}
