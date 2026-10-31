pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.notifications
import "StripLayout.js" as StripLayout
import "StripPhysics.js" as Physics

// One hanging strip (a delegate of StripsView's ListView): a popup group
// on a thread from the edge. It drops in and sways (StripMotion), follows a
// drag around its pivot, opens into the card when pulled away from the
// edge or clicked, and flies back up its thread when flicked or swiped
// (dismiss) or lifts away gently when its timer ends. Hover pauses the
// group's timers. Keys: Enter opens / folds, Delete dismisses.
Item {
    id: root

    required property string key
    required property int index
    // Set by StripsView
    property var view: null

    readonly property string edge: root.view ? root.view.edge : "top"
    readonly property bool row: StripLayout.isRow(root.edge)
    readonly property var options: root.view ? root.view.options : null

    readonly property ToastGroup toast: ToastGroup {
        group: Notifications.popupGroupsByAppName[root.key] ?? null
    }

    property bool expanded: false
    onExpandedChanged: if (root.view)
        root.view.openCount += root.expanded ? 1 : -1
    Component.onDestruction: if (root.expanded && root.view)
        root.view.openCount -= 1
    property real open: root.expanded ? 1 : 0
    Behavior on open {
        enabled: Motion.glide.duration > 0
        NumberAnimation {
            duration: Motion.glide.duration
            easing.type: Motion.glide.easing
        }
    }

    readonly property bool threadOn: !root.options || root.options.thread !== false
    readonly property real thread: root.threadOn ? StripLayout.threadLength(root.key, Space.m, Space.xxl) : Space.xs
    readonly property var frame: StripLayout.frame(root.edge, {
        "thread": root.thread,
        "long": root.view ? root.view.stripLong : 0,
        "short": root.view ? root.view.stripShort : 0,
        "cardW": root.view ? root.view.cardWidth : 0,
        "cardH": body.cardHeight,
        "open": root.open
    })
    // Size across the row the view reserves for this strip
    readonly property real cross: root.row ? root.frame.h : root.frame.w
    readonly property real span: root.row ? root.frame.w : root.frame.h

    width: root.row ? root.frame.w : (root.view ? root.view.crossExtent : root.frame.w)
    height: root.row ? (root.view ? root.view.crossExtent : root.frame.h) : root.frame.h

    StripMotion {
        id: motion
        edge: root.edge
        sway: !root.options || root.options.sway !== false
        reach: root.thread + (root.view ? root.view.stripLong : 0)
        onGonePast: root.ListView.delayRemove = false
    }
    Component.onCompleted: motion.arrive()
    ListView.onPooled: root.expanded = false
    ListView.onRemove: {
        if (motion.canLeave) {
            root.ListView.delayRemove = true;
            motion.leave();
        }
    }
    Connections {
        target: root.view
        function onArrived() {
            if (root.index > 0)
                motion.nudge(Physics.amplitude(root.index));
        }
    }

    function dismiss(kind: string): void {
        motion.kind = kind;
        root.toast.dismiss();
    }
    function toggle(): void {
        root.expanded = !root.expanded;
        if (root.expanded)
            root.forceActiveFocus();
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: root.toggle()
    Keys.onEnterPressed: root.toggle()
    Keys.onDeletePressed: root.dismiss("flick")
    Keys.onEscapePressed: root.expanded = false

    // Hovered or open: the group's timers wait
    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered && !root.activeFocus)
            root.expanded = false
    }
    readonly property bool holding: hover.hovered || root.expanded || drag.active
    onHoldingChanged: root.toast.hold(root.holding)

    Item {
        id: hung
        objectName: "stripFrame"
        x: root.edge === "right" ? root.width - width : 0
        y: root.edge === "bottom" ? root.height - height : 0
        width: root.frame.w
        height: root.frame.h
        opacity: motion.fade
        transform: [
            Rotation {
                origin.x: root.frame.pivot.x
                origin.y: root.frame.pivot.y
                angle: drag.active ? Physics.dragTilt(root.edge, drag.across, root.thread + (root.view ? root.view.stripLong : 0) / 2) : motion.angle
            },
            Translate {
                x: motion.offset.x + (root.row ? 0 : drag.stretch * (root.edge === "right" ? -1 : 1))
                y: motion.offset.y + (root.row ? drag.stretch * (root.edge === "bottom" ? -1 : 1) : 0)
            }
        ]

        // The thread, from the edge into the hole
        Rectangle {
            objectName: "stripThread"
            visible: root.threadOn
            readonly property real into: Space.l * 0.55
            x: root.row ? root.frame.thread.x - width / 2 : (root.edge === "right" ? root.frame.thread.x - into : 0)
            y: root.row ? (root.edge === "bottom" ? root.frame.thread.y - into : 0) : root.frame.thread.y - height / 2
            width: root.row ? Space.hairline : root.frame.thread.w + into
            height: root.row ? root.frame.thread.h + into : Space.hairline
            color: root.toast.critical ? Colors.error : Type.muted
        }

        StripBody {
            id: body
            x: root.frame.body.x
            y: root.frame.body.y
            width: root.frame.body.w
            height: root.frame.body.h
            edge: root.edge
            open: root.open
            material: root.options ? root.options.material : "plain"
            seed: StripLayout.hash(root.key)
            hole: root.threadOn
            notification: root.toast.latest
            extra: root.toast.extra
            critical: root.toast.critical
            hovered: hover.hovered
            foldedWidth: root.row ? (root.view ? root.view.stripShort : 0) : (root.view ? root.view.stripLong : 0)
            foldedHeight: root.row ? (root.view ? root.view.stripLong : 0) : (root.view ? root.view.stripShort : 0)
            cardWidth: root.view ? root.view.cardWidth : 0
            onDismissRequested: root.dismiss("flick")
            onActionInvoked: identifier => root.toast.invoke(identifier)

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onTapped: (point, button) => {
                    if (button === Qt.MiddleButton)
                        root.dismiss("flick");
                    else if (root.expanded)
                        root.toast.activate();
                    else
                        root.toggle();
                }
            }
            FocusRing {
                shown: root.activeFocus
                radius: body.radius
            }
            StripDrag {
                id: drag
                edge: root.edge
                onReleased: action => {
                    if (action === "dismiss")
                        root.dismiss("flick");
                    else if (action === "expand" && !root.expanded)
                        root.toggle();
                }
            }
        }
    }
}
