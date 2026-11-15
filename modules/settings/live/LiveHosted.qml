import QtQuick
import qs.config
import qs.modules.services
import qs.modules.components.kit
import qs.modules.components.preview
import "../../shell/hosts/HostResolve.js" as HostResolve

// A hosted surface (the launcher, the dashboard) as it opens: the shell's
// own view, by URL, with a PreviewContext (`overrides`, `samples`), inside
// its host's own frame (HostedFrame), placed in this item where the host
// puts it on the screen: the notch hangs from its edge (top / bottom),
// the spotlight is centred, the sheet sits on its side, a "sidebar" (a
// view that is its own surface: the Assistant) stands on its `side` with
// its end in view (the item's top edge cuts it). Scaled to fit (at
// most `maxZoom`); below `minZoom` it stays at that size and the item's
// far edge cuts it (a short stage shows the top of the launcher, readable,
// rather than all of it unreadably small). `snapshot`: pictured once (a
// gallery card), `refreshKey` pictures it again. Inert, built after the
// page shows (LivePart, LiveGate).
//
//     LiveHosted {
//         surface: "launcher"
//         source: Qt.resolvedUrl("../../widgets/launcher/LauncherView.qml")
//         samples: ({ "launcher.query": "fi" })
//     }
Item {
    id: root

    property url source
    // initial properties of the view beyond `preview`
    property var properties: ({})
    property var overrides: ({})
    property var samples: ({})
    // the surface (SurfaceRegistry) whose host frames it
    property string surface: "launcher"
    // the host (default: where the surface opens now)
    property string host: HostResolve.resolve(Config.layout, root.surface, {
        "notchEnabled": ShellLayout.notchEnabled
    })
    property real maxZoom: 1
    property real minZoom: 0
    // the item's side edge may cut it too (a picture card: its top-left
    // corner, readable, rather than all of it unreadably small)
    property bool cutSides: false
    // air around a centred (spotlight) or side (sheet) frame, in this item
    property real margin: Space.m
    property bool snapshot: false
    // false: nothing is built; a hidden stage (a kept-alive Settings
    // window, another page) builds nothing either
    property bool active: true
    // time the view gets to settle (its open motion) before it is measured
    // and pictured
    property int settleMs: 150
    property var refreshKey: null

    readonly property string edge: Config.notchPosition === "bottom" ? "bottom" : "top"
    // the sheet's / sidebar's side (left | right)
    property string side: Config.layout && Config.layout.sheet && Config.layout.sheet.side === "left" ? "left" : "right"
    readonly property alias part: part
    // the hosted view (null in a snapshot, and until it is built)
    readonly property Item view: part.item ? part.item.view : null
    readonly property bool ready: part.ready
    // the frame's native size and its scale here
    readonly property real nativeWidth: part.partWidth
    readonly property real nativeHeight: part.partHeight
    readonly property real fitZoom: {
        if (root.nativeWidth <= 0 || root.nativeHeight <= 0)
            return 1;
        const h = root.host === "notch" || root.host === "sidebar" ? root.height - root.margin : root.height - root.margin * 2;
        return Math.min(root.maxZoom, (root.width - root.margin * 2) / root.nativeWidth, Math.max(1, h) / root.nativeHeight);
    }
    readonly property real zoom: root.fitZoom < root.minZoom ? Math.min(root.minZoom, root.maxZoom, root.cutSides ? root.minZoom : (root.width - root.margin * 2) / Math.max(1, root.nativeWidth)) : root.fitZoom
    // the frame in this item
    readonly property rect frameRect: Qt.rect(part.x, part.y, part.width, part.height)

    // a rect of an item of the view (its coordinates) in this item
    function mapFromView(it, r) {
        const m = part.mapFromPart(it, r);
        return Qt.rect(part.x + m.x, part.y + m.y, m.width, m.height);
    }
    // the view's child named `name` (objectName), depth-first
    function find(name, from) {
        const at = from || root.view;
        if (!at)
            return null;
        if (at.objectName === name)
            return at;
        const kids = at.children || [];
        for (let i = 0; i < kids.length; i++) {
            const hit = root.find(name, kids[i]);
            if (hit)
                return hit;
        }
        return null;
    }

    clip: true

    PreviewContext {
        id: context
        overrides: root.overrides
        samples: root.samples
    }

    LivePart {
        id: part
        objectName: "liveHosted"
        source: Qt.resolvedUrl("HostedFrame.qml")
        properties: ({
                "source": root.source,
                "properties": Object.assign({
                    "preview": context
                }, root.properties || {}),
                "host": root.host,
                "edge": root.edge
            })
        zoom: root.zoom
        width: Math.round(root.nativeWidth * root.zoom)
        height: Math.round(root.nativeHeight * root.zoom)
        x: root.cutSides && width > root.width ? root.margin : (root.host === "sheet" || root.host === "sidebar" ? (root.side === "left" ? root.margin : root.width - width - root.margin) : Math.round((root.width - width) / 2))
        y: {
            if (root.host === "notch")
                return root.edge === "bottom" ? root.height - height : 0;
            if (root.host === "sheet")
                return root.margin;
            if (root.host === "sidebar")
                return root.height - height - root.margin;
            // centred; a frame taller than the item shows its top
            return Math.max(root.margin, Math.round((root.height - height) / 2));
        }
        snapshot: root.snapshot
        active: root.active
        // (its own visibility waits for it to be ready: the host's says)
        shown: root.visible
        settleMs: root.settleMs
        visible: root.snapshot || part.ready
        // enabled (a disabled kit row reads greyed out: ListRow); the cover
        // below takes every click, wheel and hover instead
        interactive: true
        // another host or edge is another frame: built again
        refreshKey: [root.host, root.edge, root.side, JSON.stringify(root.refreshKey)].join("|")
    }
    MouseArea {
        anchors.fill: part
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        // the wheel scrolls the page around the stage, never the view's
        // own lists (an unaccepted wheel would reach them under the cover)
        onWheel: wheel => {
            let f = root.parent;
            while (f && f.contentY === undefined)
                f = f.parent;
            if (f && f.contentHeight > f.height)
                f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY - wheel.angleDelta.y));
        }
    }
}
