import QtQuick
import qs.config
import qs.modules.components.kit
import qs.modules.shell
import qs.modules.theme

// On the side from EdgeLayout.sheetSide (layout.sheet.side; "auto" avoids a
// vertical bar), Space.m inside the work area. Slides in from that side,
// clipped to its rect so it never passes over the bar or the dock.
// Width: Metrics.sheetW, or the view's implicitWidth when larger. Height:
// the view's implicitHeight (the dashboard is laid out for its own height;
// stretched over the screen it spreads its tiles apart), the work area for a
// view without one.
SurfaceHost {
    id: root

    hostName: "sheet"
    slot: frame.slot

    readonly property int wantWidth: Math.max(Metrics.sheetW, (root.view ? root.view.implicitWidth : 0) + frame.padding * 2)
    readonly property int wantHeight: root.view && root.view.implicitHeight > 0 ? root.view.implicitHeight + frame.padding * 2 : 0
    readonly property var area: EdgeService.sheetRect(root.screen, Config.layout && Config.layout.sheet ? Config.layout.sheet.side : "auto", root.wantWidth, root.wantHeight, Space.m)
    readonly property string side: root.area.side

    HostBackdrop {
        anchors.fill: parent
        strength: 0.3
        progress: root.progress
        onClicked: root.requestClose()
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
