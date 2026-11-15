import QtQuick
import qs.config
import qs.modules.components.preview
import "../../bar/panels/PanelLayout.js" as PanelLayout
import "../../bar/panels/PanelStyles.js" as PanelStyles

// One real bar panel framed in a picture (a picture card, a strip): your
// primary bar's spec with `patch` laid over it (another style, only some
// modules, centred...), drawn by the shell's own BarContent (LiveBars) on
// the top edge of a screen `nativeWidth` wide, and framed on the panel's
// body. `overrides` shows config keys with another value (Preview.js), e.g.
// a workspace indicator style the user has not chosen:
//
//     LivePanel {
//         patch: ({ "groups": { "center": ["workspaces"] }, "align": "center" })
//         overrides: ({ "workspaces.indicatorStyle": "branch" })
//     }
//
// `snapshot` pictures it once and frees the live panel (galleries).
Item {
    id: root

    property var patch: ({})
    property var overrides: ({})
    // sample data its modules show (PreviewContext.samples), e.g. the
    // inline OSD: {"osd": {"kind": "volume", "value": 0.62}}
    property var samples: ({})
    property real nativeWidth: 960
    property real nativeHeight: 160
    // what is framed: "panel" (its whole body), "modules" (the piece of the
    // body around its modules) or "edge" (the screen's band along the
    // panel's edge, from the edge to past the panel: its gap to the edge
    // and to the corners, its ends; with `cut: "ends"` both corners show)
    property string frame: "panel"
    // readable (LivePart): at least this zoom / this text size, and what
    // shows when that is larger than the picture
    property real minZoom: 0
    // (a picture card reads: its text 10 px at least)
    property real readableGlyph: 10
    property string cut: "ends"
    // room around it in the picture (native px)
    property real margin: 6
    property real maxZoom: 1.6
    property string fit: "contain"
    property bool snapshot: false
    // false: nothing is built
    property bool active: true
    property var refreshKey: null
    readonly property alias part: part
    readonly property bool ready: part.ready

    // the primary panel of the live config (the one on the island's edge)
    readonly property var base: {
        const all = PanelLayout.normalize(Config.bar).panels.filter(p => p && p.enabled !== false);
        const i = PanelLayout.primaryIndex(all, PanelLayout.pairEdge(Config.bar, Config.notch));
        return i >= 0 ? all[i] : PanelLayout.normalize(undefined).panels[0];
    }
    // (on the top edge: a style that cannot sit there, a rail, shows classic)
    readonly property var spec: Object.assign({}, root.base, {
        "id": "preview",
        "edge": "top",
        "style": PanelStyles.supportsEdge(root.base.style, "top") ? root.base.style : "classic",
        "enabled": true,
        "screens": []
    }, root.patch || {})

    PreviewContext {
        id: context
        overrides: root.overrides
        samples: root.samples
    }

    LivePart {
        id: part
        anchors.fill: parent
        source: Qt.resolvedUrl("LiveBars.qml")
        properties: ({
                "bar": {
                    "panels": [root.spec]
                },
                "screen": LiveTarget.screen,
                "preview": context
            })
        nativeWidth: root.nativeWidth
        nativeHeight: root.nativeHeight
        maxZoom: root.maxZoom
        minZoom: root.minZoom
        readableGlyph: root.readableGlyph
        cut: root.cut
        fit: root.fit
        snapshot: root.snapshot
        active: root.active
        refreshKey: root.refreshKey
        cropOf: bars => {
            // (a part being torn down has lost its functions)
            if (typeof bars.panelRect !== "function")
                return Qt.rect(0, 0, 0, 0);
            const r = bars.panelRect(0);
            if (r.width <= 0)
                return r;
            if (root.frame === "edge") {
                const b = bars.bars[0];
                const edge = b ? b.barPosition : "top";
                const m = root.margin;
                // along the edge: to the screen's corners, or around the
                // panel when it stands apart from them (a dock, a pill)
                // (a style may fill the edge with an invisible body: the
                // modules say where the panel really is)
                const W = root.nativeWidth, H = root.nativeHeight;
                let u = r;
                const mods = bars.modules();
                if (mods.length > 0) {
                    let a = 1e9, b2 = 1e9, c = -1e9, d = -1e9;
                    for (let i = 0; i < mods.length; i++) {
                        const p = mods[i].item.mapToItem(bars, 0, 0);
                        a = Math.min(a, p.x);
                        b2 = Math.min(b2, p.y);
                        c = Math.max(c, p.x + mods[i].item.width);
                        d = Math.max(d, p.y + mods[i].item.height);
                    }
                    u = Qt.rect(a, b2, c - a, d - b2);
                }
                const pad = m * 4;
                const x0 = u.x > pad * 4 ? u.x - pad : 0, x1 = W - (u.x + u.width) > pad * 4 ? u.x + u.width + pad : W;
                const y0 = u.y > pad * 4 ? u.y - pad : 0, y1 = H - (u.y + u.height) > pad * 4 ? u.y + u.height + pad : H;
                if (edge === "top")
                    return Qt.rect(x0, 0, x1 - x0, r.y + r.height + m);
                if (edge === "bottom")
                    return Qt.rect(x0, r.y - m, x1 - x0, H - r.y + m);
                if (edge === "left")
                    return Qt.rect(0, y0, r.x + r.width + m, y1 - y0);
                return Qt.rect(r.x - m, y0, W - r.x + m, y1 - y0);
            }
            let x0 = r.x, x1 = r.x + r.width;
            if (root.frame === "modules") {
                const mods = bars.modules();
                if (mods.length > 0) {
                    x0 = 1e9;
                    x1 = -1e9;
                    for (let i = 0; i < mods.length; i++) {
                        const p = mods[i].item.mapToItem(bars, 0, 0);
                        x0 = Math.min(x0, p.x);
                        x1 = Math.max(x1, p.x + mods[i].item.width);
                    }
                }
            }
            return Qt.rect(x0 - root.margin, Math.max(0, r.y - root.margin), x1 - x0 + root.margin * 2, r.height + root.margin * 2);
        }
    }
    // a new spec is a new panel (a re-evaluation that changed nothing is not)
    readonly property string specJson: JSON.stringify(root.spec)
    onSpecJsonChanged: if (part.built)
        part.retake()
}
