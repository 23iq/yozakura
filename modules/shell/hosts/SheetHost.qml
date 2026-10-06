import QtQuick
import qs.config
import qs.modules.shell
import qs.modules.theme

// Full work-area height on the side from EdgeLayout.sheetSide
// (layout.sheet.side; "auto" avoids a vertical bar). Slides in from that side,
// clipped to the work area so it never passes over the bar or the dock.
// Width: Metrics.sheetW, or the view's implicitWidth when larger.
SurfaceHost {
    id: root

    hostName: "sheet"
    slot: frame.slot

    readonly property int wantWidth: Math.max(Metrics.sheetW, (root.view ? root.view.implicitWidth : 0) + frame.padding * 2)
    readonly property var area: EdgeService.sheetRect(root.screen, Config.layout && Config.layout.sheet ? Config.layout.sheet.side : "auto", root.wantWidth)
    readonly property string side: root.area.side

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.3 * Math.min(1, root.progress)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.requestClose()
        }
    }

    Item {
        id: track
        x: root.area.x
        y: root.area.y
        width: root.area.w
        height: root.area.h
        clip: root.progress < 1

        HostFrame {
            id: frame
            objectName: "sheetFrame"
            width: parent.width
            height: parent.height
            x: (root.side === "right" ? 1 : -1) * (1 - root.progress) * parent.width
            onEscapePressed: root.requestClose()
        }
    }
}
