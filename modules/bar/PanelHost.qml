pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.bar.panels
import "panels/PanelLayout.js" as PanelLayout

// Every bar panel of one screen (Panels.forScreen), one BarContent each.
// `primary` is the panel the notch, live activities and single-bar
// consumers pair with; `zones` / `containSides` feed the reservations and
// the frame for every edge.
Item {
    id: host

    required property ShellScreen screen
    property bool active: true

    // Only rebuild the panels when this screen's specs really change
    readonly property string specsJson: active ? JSON.stringify(Panels.forScreen(screen.name)) : "[]"
    readonly property var specs: JSON.parse(specsJson)
    readonly property int primaryIndex: PanelLayout.primaryIndex(specs, Panels.notchEdge)

    // Created panels, in spec order (Repeater items are not reactive)
    property var bars: []
    readonly property BarContent primary: primaryIndex >= 0 && primaryIndex < bars.length ? bars[primaryIndex] : null

    function _collect() {
        const out = [];
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it)
                out.push(it);
        }
        bars = out;
    }

    readonly property int frameThickness: Config.bar && Config.bar.frameEnabled ? (Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6) : 0

    // Window reservation per edge (frame excluded): the deepest reserving
    // panel on each edge
    readonly property var zones: {
        const entries = [];
        for (let i = 0; i < bars.length; i++) {
            const b = bars[i];
            if (!b || !b.spec)
                continue;
            entries.push({
                "edge": b.barPosition,
                "size": b.edgeDepth + (b.contained ? frameThickness : 0),
                "reserving": PanelLayout.reserves(b.spec, b.pinned)
            });
        }
        return PanelLayout.edgeZones(entries);
    }

    // How much the frame grows on each edge to swallow contained panels
    // (bar.containBar), following each panel's reveal
    readonly property var containSides: {
        const z = {
            "top": 0,
            "bottom": 0,
            "left": 0,
            "right": 0
        };
        for (let i = 0; i < bars.length; i++) {
            const b = bars[i];
            if (!b || !b.contained || !b.reveal)
                continue;
            z[b.barPosition] = Math.max(z[b.barPosition], b.panelThickness + frameThickness);
        }
        return z;
    }

    // Input regions of every panel (the shell window's mask)
    readonly property var hitRegions: bars.filter(b => b && b.hitRegion).map(b => b.hitRegion)

    // Popups and the pin: whether any panel shows its content right now
    readonly property bool anyReveal: bars.some(b => b && b.reveal)

    Repeater {
        id: repeater
        model: host.specs
        onItemAdded: Qt.callLater(host._collect)
        onItemRemoved: Qt.callLater(host._collect)

        delegate: BarContent {
            required property var modelData
            required property int index
            anchors.fill: parent
            screen: host.screen
            panel: modelData
            isPrimary: index === host.primaryIndex
        }
    }
}
