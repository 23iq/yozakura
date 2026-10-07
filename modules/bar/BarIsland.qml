import QtQuick
import qs.config
import qs.modules.theme

// One "islands" tab: a notch-shaped background hugging its content. The item
// itself is the tab body (content + padding); the silhouette extends beyond
// it for the fillets. Placed by the parent along the bar's edge.
Item {
    id: island

    required property var barRoot
    // Which end of the bar the tab belongs to: "start" (left/top) or "end"
    property string side: "start"
    property real padding: 4
    // Tabs sitting in a screen corner merge with the side frame
    property bool flush: true
    property real fillet: Config.roundness > 0 ? Config.roundness + 4 : 0
    property real cornerRadius: Config.roundness > 0 ? Config.roundness + 4 : 0
    // Disable the size animation while the content animates itself
    property bool animateSize: true

    default property alias content: contentHolder.data
    property Item layoutItem: null

    readonly property bool vertical: barRoot.orientation === "vertical"
    readonly property string edge: barRoot.barPosition

    readonly property real contentLength: layoutItem ? (vertical ? layoutItem.implicitHeight : layoutItem.implicitWidth) : 0
    readonly property real contentThickness: layoutItem ? (vertical ? layoutItem.implicitWidth : layoutItem.implicitHeight) : 0
    readonly property bool hasContent: contentLength > 0

    // The first layout (startup, a panel being built) snaps; only changes after
    // the content has settled morph.
    property bool settled: false
    onHasContentChanged: {
        if (hasContent && !settled)
            settleTimer.restart();
    }
    Component.onCompleted: {
        if (hasContent)
            settleTimer.restart();
    }
    Timer {
        id: settleTimer
        interval: 120
        onTriggered: island.settled = true
    }

    property real bodyLength: hasContent ? contentLength + padding * 2 : 0
    Behavior on bodyLength {
        enabled: island.settled && island.animateSize && Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    readonly property real bodyThickness: contentThickness + padding * 2

    visible: bodyLength > 0.5
    width: vertical ? bodyThickness : bodyLength
    height: vertical ? bodyLength : bodyThickness

    IslandShape {
        id: shape
        z: -1
        edge: island.edge
        bodyLength: island.bodyLength
        bodyThickness: island.bodyThickness
        fillet: island.fillet
        bodyRadius: island.cornerRadius
        startFlush: island.flush && island.side === "start"
        endFlush: island.flush && island.side === "end"

        // Place the (top-authored, then transformed) silhouette so that its
        // body lands exactly on this item
        x: {
            switch (island.edge) {
            case "left":
                return 0;
            case "right":
                return island.width - shape.localHeight;
            default:
                return -shape.bodyOffset;
            }
        }
        y: {
            switch (island.edge) {
            case "bottom":
                return island.height - shape.localHeight;
            case "left":
            case "right":
                return -shape.bodyOffset;
            default:
                return 0;
            }
        }
    }

    Item {
        id: contentHolder
        anchors.fill: parent
        anchors.margins: island.padding
        clip: true
    }
}
