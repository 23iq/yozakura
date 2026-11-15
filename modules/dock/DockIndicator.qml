import QtQuick
import qs.config
import "indicators"
import "indicators/IndicatorRegistry.js" as Registry
import "../components/preview/Preview.js" as Preview

// Running-app indicator of one dock button. The style is `dock.indicator`
// (indicators/IndicatorRegistry.js); the marks sit on the side facing the
// screen edge the dock is on, whichever edge that is.
Loader {
    id: root

    property string edge: "bottom"
    property int count: 0
    property bool focused: false
    // A settings preview (DockAppButton.preview): another style, null live
    property var preview: null

    readonly property var place: Registry.placement(edge)

    anchors.fill: parent
    source: Qt.resolvedUrl("indicators/" + Registry.get(Preview.pick(root.preview, "dock.indicator", Config.dock?.indicator ?? "dot")).url)
    onLoaded: {
        const it = item;
        it.side = Qt.binding(() => root.place.side);
        it.count = Qt.binding(() => root.count);
        it.active = Qt.binding(() => root.focused);
    }
}
