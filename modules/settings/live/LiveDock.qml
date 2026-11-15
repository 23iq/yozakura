import QtQuick
import qs.modules.theme
import qs.modules.components.preview
import qs.modules.settings.store

// The real dock (modules/dock/DockContent.qml, by URL: your apps, pins,
// running indicators, size, spacing and style) framed in a picture or a
// strip: laid out on a screen `nativeWidth` x `nativeHeight`, framed on the
// dock's surface with `margin` around it. `overrides` shows config keys
// with another value (Preview.js), e.g. {"dock.theme": "floating"}.
// `snapshot` pictures it once and frees it (galleries): again when a
// setting the dock reads changes (`revision`) or the colours do, once a
// burst of changes is over.
// `frame: "app"` frames one running app (its button, the dock's depth
// across): the running indicator cards; no app runs: the whole dock.
// `zoom` > 0 shows it at that scale (sizes compared side by side), the
// overflow cut by the picture.
Item {
    id: root

    property var overrides: ({})
    property real nativeWidth: 1280
    property real nativeHeight: 240
    property real margin: 10
    property real maxZoom: 1.6
    property real zoom: 0
    // readable (LivePart): at least this zoom / this text size, and what
    // shows when that is larger than the picture ("ends": both ends)
    property real minZoom: 0
    property real readableGlyph: 0
    property string cut: "center"
    // "surface" | "app"
    property string frame: "surface"
    property bool snapshot: false
    // false: nothing is built
    property bool active: true
    property var refreshKey: null
    // settings a dock reads, changed (a picture is taken again)
    property int revision: 0
    readonly property var lookKey: root.snapshot ? JSON.stringify([root.refreshKey, root.revision, String(Colors.primary), String(Colors.background), String(Colors.overBackground), String(Colors.surface)]) : root.refreshKey
    Connections {
        target: root.snapshot ? SettingsStore : null
        function onValueSet(key) {
            if (/^(dock|theme|apps|general)\./.test(String(key)))
                root.revision++;
        }
    }
    readonly property alias part: part
    readonly property Item dock: part.item
    // the dock's surface in this item
    readonly property rect surfaceRect: part.partRect

    PreviewContext {
        id: context
        overrides: root.overrides
    }

    // the first running app button under `item` (DockAppButton names itself
    // "dockApp:<id>"), else the first app button, else null
    function appButton(item) {
        let first = null;
        const walk = it => {
            const kids = it.children || [];
            for (let i = 0; i < kids.length; i++) {
                const k = kids[i];
                if (String(k.objectName).indexOf("dockApp:") === 0 && k.visible) {
                    if (k.appIsRunning)
                        return k;
                    if (!first)
                        first = k;
                }
                const found = walk(k);
                if (found)
                    return found;
            }
            return null;
        };
        return walk(item) || first;
    }

    LivePart {
        id: part
        anchors.fill: parent
        source: Qt.resolvedUrl("../../dock/DockContent.qml")
        properties: ({
                "screen": LiveTarget.screen,
                "preview": context
            })
        nativeWidth: root.nativeWidth
        nativeHeight: root.nativeHeight
        maxZoom: root.maxZoom
        zoom: root.zoom
        minZoom: root.minZoom
        readableGlyph: root.readableGlyph
        cut: root.cut
        snapshot: root.snapshot
        active: root.active
        refreshKey: root.lookKey
        cropOf: dock => {
            if (!dock.surfaceRect)
                return Qt.rect(0, 0, 0, 0);
            const r = dock.surfaceRect;
            const app = root.frame === "app" ? root.appButton(dock) : null;
            if (app) {
                const p = app.mapToItem(dock, 0, 0);
                return dock.isVertical ? Qt.rect(r.x, p.y - app.height * 0.75, r.width, app.height * 2.5) : Qt.rect(p.x - app.width * 0.75, r.y, app.width * 2.5, r.height);
            }
            return Qt.rect(r.x - root.margin, r.y - root.margin, r.width + root.margin * 2, r.height + root.margin * 2);
        }
    }
}
