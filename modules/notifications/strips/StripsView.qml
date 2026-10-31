pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "StripLayout.js" as StripLayout

// Notifications as tanzaku (notifications.presentation "strips"): narrow
// strips hanging on threads from a screen edge (notifications.strips.edge;
// auto = the top edge, under a top bar), newest next to the corner, each
// new one beside the previous. At most strips.maxVisible hang; the rest
// wait behind a "+N" knot. Lives in the unified shell panel so it clears the
// bar, frame and dock on every edge. Strip.qml: one strip.
Item {
    id: root

    // The UnifiedShellPanel (panel zones, dock, frame)
    property var panel: null
    property string screenName: ""

    readonly property bool active: Notifications.presentation === "strips" && Notifications.showsOnScreen(root.screenName)
    readonly property var options: Config.notifications ? Config.notifications.strips : null
    readonly property string edge: StripLayout.resolveEdge(root.options ? root.options.edge : "auto")
    readonly property bool row: StripLayout.isRow(root.edge)

    readonly property int stripShort: Space.controlM + Space.xs
    readonly property int stripLong: 2 * Space.controlXL
    readonly property int cardWidth: Math.round(Math.min(root.width / 2, Metrics.toastW * Math.max(1, Styling.fontSize(0) / 14)))
    // Strips open at the moment (the panel takes keyboard focus for them)
    property int openCount: 0
    readonly property bool wantsKeyboard: root.active && root.openCount > 0

    // Input region (UnifiedShellPanel mask): just the hanging strips
    readonly property Item hitbox: hits

    // A new strip arrived at the head of the row: its neighbours sway
    signal arrived

    readonly property var orderedKeys: {
        if (!root.active)
            return [];
        const groups = Notifications.popupGroupsByAppName;
        return Notifications.popupAppNameList.slice().sort((a, b) => (groups[b]?.time ?? 0) - (groups[a]?.time ?? 0));
    }
    readonly property var placed: StripLayout.slots(root.orderedKeys, root.options ? root.options.maxVisible : 5)
    property string head: ""
    onPlacedChanged: {
        const first = root.placed.keys.length > 0 ? root.placed.keys[0] : "";
        if (first !== "" && first !== root.head && root.head !== "")
            root.arrived();
        root.head = first;
    }

    // Size across the row (the longest strip or open card on it) and along
    // it (strips, gaps and the knot), from what the strips report (the
    // ListView spans the whole edge; sizing it by its content would loop)
    readonly property var extent: {
        let cross = root.stripLong + 2 * Space.xl, along = 0, n = 0;
        const kids = list.contentItem.children;
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i].cross, s = kids[i].span;
            if (typeof c === "number")
                cross = Math.max(cross, c);
            if (typeof s === "number" && s > 0) {
                along += s;
                n++;
            }
        }
        return {
            "cross": cross,
            "along": along + Math.max(0, n - 1) * list.spacing
        };
    }
    readonly property real crossExtent: root.extent.cross

    // Focus the newest strip (keyboard: Enter opens it, Delete dismisses)
    function focusNewest(): void {
        const item = list.itemAtIndex(0);
        if (item)
            item.forceActiveFocus();
    }

    // Space the bar/frame/dock take on each edge
    readonly property real frameInset: (Config.bar && Config.bar.frameEnabled && !(root.panel && root.panel.hasFullscreenWindow)) ? (Config.bar.frameThickness ?? 6) : 0
    function inset(edge: string): real {
        const zones = root.panel ? root.panel.panelZones : null;
        const bar = zones && zones[edge] ? zones[edge] : 0;
        const p = root.panel;
        const dock = p && p.dockEnabled && p.dockPosition === edge && p.dockReveal ? p.dockHeight : 0;
        // Strips hang from their own edge (gap: the thread); elsewhere a margin
        return root.frameInset + Math.max(bar, dock) + (edge === root.edge ? 0 : Space.m);
    }

    Item {
        id: hits
        readonly property real along: Math.min(root.extent.along, list.room)
        x: root.row ? list.x + list.width - along : list.x
        y: list.y
        width: root.row ? along : list.width
        height: root.row ? list.height : along
    }

    ListView {
        id: list
        objectName: "stripsList"
        readonly property real room: root.row ? root.width - root.inset("left") - root.inset("right") : root.height - root.inset("top") - root.inset("bottom")
        width: root.row ? room : root.crossExtent
        height: root.row ? root.crossExtent : room
        x: root.edge === "left" ? root.inset("left") : root.width - root.inset("right") - width
        y: root.edge === "bottom" ? root.height - root.inset("bottom") - height : root.inset("top")
        visible: root.active && count > 0
        interactive: false
        orientation: root.row ? ListView.Horizontal : ListView.Vertical
        layoutDirection: Qt.RightToLeft
        spacing: Space.m
        model: KeyedListModel {
            keys: root.placed.keys
        }

        delegate: Strip {
            view: root
        }

        footer: StripKnot {
            edge: root.edge
            count: root.placed.overflow
            crossExtent: root.crossExtent
            thread: !root.options || root.options.thread !== false
        }

        displaced: Transition {
            enabled: Motion.glide.duration > 0
            NumberAnimation {
                properties: "x,y"
                duration: Motion.glide.duration
                easing.type: Motion.glide.easing
            }
        }
    }
}
