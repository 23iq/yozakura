import QtQuick
import qs.modules.components.preview
import "LiveSamples.js" as LiveSamples

// The real strips (modules/notifications/strips/StripsView.qml, by URL:
// tanzaku on their threads from notifications.strips.edge, the shell's
// paper, texture and motion) hanging the sample groups (LiveSamples.groups:
// a message and a reminder), laid out in a native area `nativeWidth` x
// `nativeHeight` and framed on the strips (their hit box) with `margin`.
Item {
    id: root

    property bool grouped: false
    property bool active: true
    property real nativeWidth: 720
    property real nativeHeight: 420
    property real margin: 12
    property real maxZoom: 1
    readonly property alias part: part
    // the strips in this item
    readonly property rect stripsRect: part.partRect

    PreviewContext {
        id: context
        samples: {
            const all = LiveSamples.groups(Date.now(), root.grouped);
            return {
                "popupGroups": all,
                "popupAppNames": Object.keys(all)
            };
        }
    }

    LivePart {
        id: part
        anchors.fill: parent
        source: Qt.resolvedUrl("../../notifications/strips/StripsView.qml")
        properties: ({
                "preview": context
            })
        nativeWidth: root.nativeWidth
        nativeHeight: root.nativeHeight
        maxZoom: root.maxZoom
        active: root.active
        // the drop and sway settle first
        settleMs: 900
        cropOf: view => {
            const h = view.hitbox;
            if (!h || h.width <= 0 || h.height <= 0)
                return Qt.rect(0, 0, 0, 0);
            const m = root.margin;
            return Qt.rect(h.x - m, Math.max(0, h.y - m), h.width + m * 2, h.height + m * 2);
        }
    }
}
