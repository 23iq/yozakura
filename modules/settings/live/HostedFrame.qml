import QtQuick
import qs.config
import qs.modules.theme

// A hosted view at its native size inside its host's own frame, for
// LiveHosted (which pictures this through a LivePart): the notch's
// silhouette (modules/notch/NotchSilhouette.qml, open, its concave corners
// in the attached style) or the spotlight / sheet HostFrame
// (modules/shell/hosts/HostFrame.qml), both by URL, around the view (by URL,
// `properties` with its PreviewContext) at the host's padding. The view
// fills the frame's slot as SurfaceHost lays it (the sheet is at least
// Metrics.sheetW wide). "sidebar": a view that is its own surface (the
// Assistant's panel): no frame, no padding. `ready` once both are built.
Item {
    id: root

    required property url source
    property var properties: ({})
    // "notch" | "spotlight" | "sheet" | "sidebar"
    property string host: "spotlight"
    // the notch's edge (top | bottom): its silhouette hangs from it
    property string edge: "top"

    readonly property bool notch: root.host === "notch"
    // the attached notch flows out of the edge with two concave corners
    // (Notch.qml: cornerSize, contentPadding of an open notch)
    readonly property int corner: root.notch && Config.notchTheme === "default" && Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property bool framed: root.host !== "sidebar"
    readonly property int pad: root.notch ? 16 : (root.framed ? Metrics.padding : 0)
    readonly property Item view: viewLoader.item
    readonly property real viewWidth: root.view ? root.view.implicitWidth : 0
    readonly property real viewHeight: root.view ? root.view.implicitHeight : 0
    readonly property bool ready: viewLoader.status === Loader.Ready && (!root.framed || frameLoader.status === Loader.Ready)

    implicitWidth: root.host === "sheet" ? Math.max(Metrics.sheetW, root.viewWidth + root.pad * 2) : root.viewWidth + root.pad * 2 + root.corner * 2
    implicitHeight: root.viewHeight + root.pad * 2

    Loader {
        id: frameLoader
        anchors.fill: parent
        asynchronous: true
        Component.onCompleted: {
            if (!root.framed)
                return;
            if (root.notch)
                setSource(Qt.resolvedUrl("../../notch/NotchSilhouette.qml"), {
                    "position": root.edge,
                    "open": true,
                    "cornerSize": root.corner
                });
            else
                setSource(Qt.resolvedUrl("../../shell/hosts/HostFrame.qml"), {});
        }
    }

    Loader {
        id: viewLoader
        objectName: "hostedView"
        x: root.corner + root.pad
        y: root.pad
        width: root.width - x * 2
        height: root.height - root.pad * 2
        z: 1
        asynchronous: true
        Component.onCompleted: setSource(root.source, root.properties || {})
    }
}
