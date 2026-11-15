import QtQuick
import qs.modules.services
import qs.modules.components.preview
import qs.modules.services.activities
import qs.modules.settings.store
// LiveTarget (a singleton of this directory) through the module: tooling
// resolves the implicit directory import without its qmldir
import qs.modules.settings.live
import "LiveSamples.js" as LiveSamples
import "../Ui.js" as Ui

// The real island (modules/shell/NotchPreview.qml, by URL: the shell's
// Notch and resting view) in a stage or a picture, showing the sample `showing` with
// sample content (LiveSamples.island: "rest" | "media" | "notification" |
// "timer"); `overrides` shows config keys with another value (Preview.js),
// e.g. {"notch.style": "pill"}.
// Framing: a window of this item's size at `zoom` (native px -> item px)
// on the island's edge, centred on it along the edge (a stage, a picture
// card: the island hangs from the item's edge as from the screen's, in the
// middle of it wherever it sits along the screen's: that is the canvas'
// job); or
// `frame: "screen"`: the whole screen; `frame: "island"`: the island
// itself and the band from the screen's edge to it (what hangs from the
// edge, its gap and fillets), fitted, but readable (`readableGlyph`, `cut`
// as LivePart: a long island shows its two ends).
// `snapshot` pictures it once and frees it (galleries).
Item {
    id: root

    property string showing: "rest"
    property var overrides: ({})
    property real zoom: 1
    // "edge" | "screen" | "island"
    property string frame: "edge"
    // readable (frame "island"): its smallest text at least this size
    property real readableGlyph: 0
    property string cut: "center"
    property real margin: 12
    property bool snapshot: false
    property bool active: true
    property var refreshKey: null
    property int settleMs: 400
    readonly property alias part: part
    readonly property Item island: part.item
    readonly property bool ready: part.ready
    // the island's target (not animated) place and size, native px (kept
    // once a snapshot freed the part)
    readonly property rect liveTarget: Ui.prop(root.island, "targetRect") ?? Qt.rect(0, 0, 0, 0)
    property rect targetRect: Qt.rect(0, 0, 0, 0)
    onLiveTargetChanged: if (root.liveTarget.width > 0)
        root.targetRect = root.liveTarget
    // the island in this item (its silhouette, as it is drawn now)
    readonly property rect islandRect: root.island ? part.mapFromPart(root.island, Ui.prop(root.island, "notchRect")) : Qt.rect(0, 0, 0, 0)

    PreviewContext {
        id: context
        overrides: root.overrides
        samples: {
            const now = Date.now();
            const timer = root.showing === "timer" && typeof TimerActivity.timerActivity === "function" ? TimerActivity.timerActivity(LiveSamples.timer(now, k => I18n.t(k))) : null;
            return LiveSamples.island(root.showing, now, SettingsStore.wallpaper || "", timer, k => I18n.t(k));
        }
    }

    // the window on the island's edge, centred on its target place (never
    // held inside the screen: an island at a corner still stands in the
    // middle, not against the item's side)
    function window(it) {
        const W = it.width, H = it.height;
        const w = root.width / Math.max(0.01, root.zoom), h = root.height / Math.max(0.01, root.zoom);
        const t = it.targetRect;
        const cx = t.x + t.width / 2;
        const cy = t.y + t.height / 2;
        switch (it.position) {
        case "bottom":
            return Qt.rect(cx - w / 2, H - h, w, h);
        case "left":
            return Qt.rect(0, cy - h / 2, w, h);
        case "right":
            return Qt.rect(W - w, cy - h / 2, w, h);
        default:
            return Qt.rect(cx - w / 2, 0, w, h);
        }
    }

    // the island and the band to its edge, native px
    function around(it) {
        const t = it.targetRect, m = root.margin;
        if (t.width <= 0)
            return Qt.rect(0, 0, 0, 0);
        switch (it.position) {
        case "bottom":
            return Qt.rect(t.x - m, t.y - m, t.width + m * 2, it.height - t.y + m);
        case "left":
            return Qt.rect(0, t.y - m, t.x + t.width + m, t.height + m * 2);
        case "right":
            return Qt.rect(t.x - m, t.y - m, it.width - t.x + m, t.height + m * 2);
        default:
            return Qt.rect(t.x - m, 0, t.width + m * 2, t.y + t.height + m);
        }
    }

    LivePart {
        id: part
        anchors.fill: parent
        source: Qt.resolvedUrl("../../shell/NotchPreview.qml")
        properties: ({
                "screen": LiveTarget.screen,
                "preview": context
            })
        nativeWidth: LiveTarget.width
        nativeHeight: LiveTarget.height
        zoom: root.frame === "edge" ? root.zoom : 0
        maxZoom: root.frame === "island" ? 1.25 : 4
        readableGlyph: root.frame === "island" ? root.readableGlyph : 0
        cut: root.cut
        snapshot: root.snapshot
        active: root.active
        refreshKey: root.refreshKey
        settleMs: root.settleMs
        cropOf: root.frame === "edge" ? (it => root.window(it)) : (root.frame === "island" ? (it => root.around(it)) : null)
    }
}
