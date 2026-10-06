pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.shell
import qs.config
import "NotificationPolicy.js" as Policy

// Classic toasts in a screen corner (notifications.presentation "corner",
// or "auto" with a taskbar-like bar style). Lives in the unified shell
// panel so it knows where the bar, frame, dock and notch are and stays
// clear of them on any edge. Newest toast sits next to the screen edge;
// toasts slide in from the nearest side and the rest glide aside.
Item {
    id: root

    // The UnifiedShellPanel (panel zones, dock, frame) and its notch content
    property var panel: null
    property var notch: null
    property string screenName: ""

    readonly property bool active: Notifications.presentation === "corner" && Notifications.showsOnScreen(screenName)
    // notifications.position "auto": the corner the bar, dock and notch
    // leave free (EdgeLayout.freeCorner); otherwise the configured corner
    readonly property bool autoCorner: !Config.notifications || Config.notifications.position === "auto"
    readonly property string cornerPosition: autoCorner && panel && panel.targetScreen ? EdgeService.freeCorner(panel.targetScreen, "auto") : Notifications.cornerPosition
    readonly property var anchorsInfo: Policy.anchorsOf(cornerPosition)
    readonly property bool atBottom: anchorsInfo.vertical === "bottom"
    readonly property string side: anchorsInfo.horizontal
    readonly property int gap: 12
    readonly property int toastWidth: Math.round(Math.min(width - 2 * gap, Metrics.toastW * Math.max(1, Styling.fontSize(0) / 14)))

    // Input region (UnifiedShellPanel mask)
    readonly property Item hitbox: list

    // Space the bar/frame/dock/notch take on each edge
    readonly property real frameInset: (Config.bar && Config.bar.frameEnabled && !(panel && panel.hasFullscreenWindow)) ? (Config.bar.frameThickness ?? 6) : 0
    // Space the bar panels reserve on an edge (UnifiedShellPanel.panelZones)
    function barInset(edge) {
        const zones = panel ? panel.panelZones : null;
        return zones && zones[edge] ? zones[edge] : 0;
    }
    function dockInset(edge) {
        if (!panel || !panel.dockEnabled || panel.dockPosition !== edge || !panel.dockReveal)
            return 0;
        return panel.dockHeight;
    }
    function notchInset(edge) {
        // Centered toasts clear the notch on its edge
        if (root.side !== "center" || !notch || (Config.notchPosition ?? "top") !== edge || !notch.reveal)
            return 0;
        const n = notch.notchContainerRef;
        return n ? n.height + 4 : 0;
    }
    readonly property real insetTop: frameInset + Math.max(barInset("top"), notchInset("top")) + gap
    readonly property real insetBottom: frameInset + Math.max(barInset("bottom"), dockInset("bottom"), notchInset("bottom")) + gap
    readonly property real insetLeft: frameInset + Math.max(barInset("left"), dockInset("left")) + gap
    readonly property real insetRight: frameInset + Math.max(barInset("right"), dockInset("right")) + gap

    // ListModel mirrors Notifications.popupAppNameList by key so the
    // ListView can animate adds and removals.
    ListModel {
        id: toastModel
    }

    function sync() {
        const keys = root.active ? Notifications.popupAppNameList.slice() : [];
        for (let i = toastModel.count - 1; i >= 0; i--) {
            if (keys.indexOf(toastModel.get(i).key) === -1)
                toastModel.remove(i);
        }
        // Newest first (index 0 sits at the screen edge)
        const ordered = keys.slice().sort((a, b) => (Notifications.popupGroupsByAppName[b]?.time ?? 0) - (Notifications.popupGroupsByAppName[a]?.time ?? 0));
        for (let i = 0; i < ordered.length; i++) {
            let at = -1;
            for (let j = 0; j < toastModel.count; j++) {
                if (toastModel.get(j).key === ordered[i]) {
                    at = j;
                    break;
                }
            }
            if (at === -1)
                toastModel.insert(i, {
                    "key": ordered[i]
                });
            else if (at !== i)
                toastModel.move(at, i, 1);
        }
    }

    Connections {
        target: Notifications
        function onPopupAppNameListChanged() {
            root.sync();
        }
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()

    // Horizontal entry offset: from the nearest side (center: from the edge)
    readonly property real enterX: side === "left" ? -(toastWidth * 0.6) : (side === "right" ? toastWidth * 0.6 : 0)
    readonly property real enterY: side === "center" ? (atBottom ? 40 : -40) : 0

    ListView {
        id: list
        width: root.toastWidth
        height: Math.min(contentHeight, root.height - root.insetTop - root.insetBottom)
        x: root.side === "left" ? root.insetLeft : (root.side === "right" ? root.width - width - root.insetRight : (root.width - width) / 2)
        y: root.atBottom ? root.height - height - root.insetBottom : root.insetTop
        visible: root.active && count > 0
        interactive: false
        spacing: 8
        verticalLayoutDirection: root.atBottom ? ListView.BottomToTop : ListView.TopToBottom
        model: toastModel

        delegate: CornerToast {
            required property string key
            width: list.width
            group: Notifications.popupGroupsByAppName[key] ?? null
        }

        add: Transition {
            enabled: Motion.enter.duration > 0
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
                NumberAnimation {
                    property: "x"
                    from: root.enterX
                    to: 0
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                    easing.overshoot: Motion.enter.overshoot
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.92
                    to: 1
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                    easing.overshoot: Motion.enter.overshoot
                }
            }
        }
        remove: Transition {
            enabled: Motion.exit.duration > 0
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Motion.exit.duration
                    easing.type: Motion.exit.easing
                }
                NumberAnimation {
                    property: "x"
                    to: root.enterX
                    duration: Motion.exit.duration
                    easing.type: Motion.exit.easing
                }
                NumberAnimation {
                    property: "scale"
                    to: 0.95
                    duration: Motion.exit.duration
                    easing.type: Motion.exit.easing
                }
            }
        }
        displaced: Transition {
            enabled: Motion.morph.duration > 0
            NumberAnimation {
                properties: "x,y"
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }
}
