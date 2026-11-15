pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.modules.components.preview
import qs.modules.theme
import "../../bar/panels/PanelLayout.js" as PanelLayout

// The real bar panels of the config (modules/bar/BarContent.qml, by URL),
// laid out on a screen of this item's size (the native size: give it the
// real screen's, LiveTarget, and scale the parent). Every panel is the
// shell's own: its style, modules (the registry the bar uses: a new module
// shows up here by itself), icons, workspace indicator, clock face, colours.
// Each gets `preview` (always revealed, nothing session-wide); the parent
// keeps it inert (LivePart, or `enabled: false`).
//
// `bar` is the bar config ({position, layout, panels, ...}: what bar.json
// holds; the live one by default, a picture card gives its own); `panels` the normalized specs (disabled and hidden ones too: a
// panel's index is the bars editor's, SettingsStore.selectedPanel).
// Geometry for the page (native coordinates of this item): `bars` (the
// created BarContents, by panel index, null for a panel not drawn),
// `depth(edge)`, `panelRect(i)`, `modules()` ([{id, panel, item}]: every
// module slot, found by its objectName "barSlot:<id>"). The panels are
// built after the page shows (LiveGate); until then `depth` is the
// configured estimate, so nothing around them moves when they arrive.
Item {
    id: root

    property var bar: Config.bar
    // the island's config (the panel it pairs with is the primary one)
    property var notch: Config.notch
    // the screen the panels belong to (a ShellScreen, LiveTarget.screen)
    property var screen: null
    property var preview: PreviewContext {}
    // only these panel indexes (-1: all)
    property int only: -1

    readonly property var panels: PanelLayout.normalize(root.bar).panels
    // rebuilt only when a spec really changes (like PanelHost)
    readonly property string specsJson: JSON.stringify(root.panels.map((p, i) => ({
                "index": i,
                "spec": p
            })).filter(e => e.spec && e.spec.enabled !== false && (root.only < 0 || root.only === e.index)))
    readonly property var entries: JSON.parse(root.specsJson)
    readonly property int primaryIndex: {
        const specs = root.entries.map(e => e.spec);
        const i = PanelLayout.primaryIndex(specs, PanelLayout.pairEdge(root.bar, root.notch));
        return i >= 0 ? root.entries[i].index : -1;
    }

    // panel index -> BarContent (Repeater items are not reactive)
    property var bars: ({})
    readonly property bool complete: root.entries.length === 0 || Object.keys(root.bars).length === root.entries.length
    function _collect() {
        const out = {};
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && it.item)
                out[it.panelIndex] = it.item;
        }
        root.bars = out;
    }

    // Room the panels take on an edge (the frame excluded), native px.
    function depth(edge) {
        let d = 0;
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            const b = root.bars[e.index];
            if (b && b.barPosition === edge)
                d = Math.max(d, b.edgeDepth);
            else if (!b && e.spec.edge === edge)
                d = Math.max(d, PanelLayout.estimateDepth(e.spec, BarMetrics.moduleSize));
        }
        return d;
    }
    // The visible body of a panel (its style), native px in this item.
    function panelRect(index) {
        const b = root.bars[index];
        const s = b ? b.styleItem : null;
        if (!s || s.width <= 0 || s.height <= 0)
            return Qt.rect(0, 0, 0, 0);
        const p = s.mapToItem(root, 0, 0);
        return Qt.rect(p.x, p.y, s.width, s.height);
    }
    // Every module slot shown: [{id, panel, item}]
    function modules() {
        const out = [];
        const walk = (it, panel) => {
            if (!it)
                return;
            const n = String(it.objectName || "");
            if (n.indexOf("barSlot:") === 0 && it.visible && it.width > 0 && it.height > 0) {
                out.push({
                    "id": n.slice(8),
                    "panel": panel,
                    "item": it
                });
                return;
            }
            const kids = it.children || [];
            for (let i = 0; i < kids.length; i++)
                walk(kids[i], panel);
        };
        for (const k in root.bars)
            walk(root.bars[k], Number(k));
        return out;
    }

    Repeater {
        id: repeater
        model: root.screen ? root.entries : []
        onItemAdded: Qt.callLater(root._collect)
        onItemRemoved: Qt.callLater(root._collect)

        delegate: Loader {
            id: slot
            required property var modelData
            readonly property int panelIndex: slot.modelData.index
            anchors.fill: parent
            // built over a few frames: a page never waits for its panels
            asynchronous: true
            function build() {
                slot.setSource(Qt.resolvedUrl("../../bar/BarContent.qml"), {
                    "screen": root.screen,
                    "panel": slot.modelData.spec,
                    "isPrimary": slot.panelIndex === root.primaryIndex,
                    "preview": root.preview
                });
            }
            Component.onCompleted: LiveGate.ask(slot, slot.build)
            Component.onDestruction: LiveGate.forget(slot)
            onLoaded: Qt.callLater(root._collect)
        }
    }
}
