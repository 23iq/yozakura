import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.preview
import "LiveSamples.js" as LiveSamples
import "../../notifications/ToastModel.js" as ToastModel

// The real corner toast (modules/notifications/CornerToast.qml, by URL:
// its Surface, art, text, actions and, `grouped`, the sheets of the rest of
// the app's notifications behind it) with the sample message
// (LiveSamples.group), at the width the shell gives it; `stackUp`: the
// sheets above it (a bottom corner). Scaled to fit, never above its size.
// `snapshot` pictures it once and frees it.
Item {
    id: root

    property bool grouped: false
    property bool stackUp: false
    property bool active: true
    property real maxZoom: 1
    // pictured once, again when `refreshKey` changes (galleries)
    property bool snapshot: false
    property var refreshKey: null
    readonly property alias part: part
    // the toast (sheets included) in this item
    readonly property rect toastRect: part.partRect
    readonly property real nativeWidth: ToastModel.toastWidth(Metrics.toastW, Styling.fontSize(0))

    LivePart {
        id: part
        anchors.fill: parent
        source: Qt.resolvedUrl("../../notifications/CornerToast.qml")
        properties: ({
                "group": LiveSamples.group(Date.now(), root.grouped, k => I18n.t(k)),
                "stackUp": root.stackUp
            })
        nativeWidth: root.nativeWidth
        maxZoom: root.maxZoom
        active: root.active
        snapshot: root.snapshot
        // built again for another group or stacking
        refreshKey: JSON.stringify([root.grouped, root.stackUp, root.refreshKey])
    }
}
