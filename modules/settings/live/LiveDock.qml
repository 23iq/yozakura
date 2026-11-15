import QtQuick
import qs.modules.components.preview

// The real dock (modules/dock/DockContent.qml, by URL: your apps, pins,
// running indicators, size, spacing and style) framed in a picture or a
// strip: laid out on a screen `nativeWidth` x `nativeHeight`, framed on the
// dock's surface with `margin` around it. `overrides` shows config keys
// with another value (Preview.js), e.g. {"dock.theme": "floating"}.
// `snapshot` pictures it once and frees it (galleries).
Item {
    id: root

    property var overrides: ({})
    property real nativeWidth: 1280
    property real nativeHeight: 240
    property real margin: 10
    property real maxZoom: 1.6
    property bool snapshot: false
    // false: nothing is built
    property bool active: true
    property var refreshKey: null
    readonly property alias part: part
    readonly property Item dock: part.item
    // the dock's surface in this item
    readonly property rect surfaceRect: part.partRect

    PreviewContext {
        id: context
        overrides: root.overrides
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
        snapshot: root.snapshot
        active: root.active
        refreshKey: root.refreshKey
        cropOf: dock => {
            if (!dock.surfaceRect)
                return Qt.rect(0, 0, 0, 0);
            const r = dock.surfaceRect;
            return Qt.rect(r.x - root.margin, r.y - root.margin, r.width + root.margin * 2, r.height + root.margin * 2);
        }
    }
}
