import QtQuick
import qs.modules.shell
import qs.modules.theme

// Centered in the focused screen's free work area (optionally over a dimmed
// backdrop, layout.backdrop);
// fades in and scales 0.96 -> 1 (Motion.enter).
SurfaceHost {
    id: root

    hostName: "spotlight"
    slot: frame.slot

    readonly property var area: EdgeService.spotlightRect(root.screen, {
        "w": (root.view ? root.view.implicitWidth : 0) + frame.padding * 2,
        "h": (root.view ? root.view.implicitHeight : 0) + frame.padding * 2
    })

    HostBackdrop {
        anchors.fill: parent
        strength: 0.5
        progress: root.progress
        onClicked: root.requestClose()
    }

    HostFrame {
        id: frame
        objectName: "spotlightFrame"
        x: root.area.x
        y: root.area.y
        width: root.area.w
        height: root.area.h
        opacity: Math.min(1, root.progress)
        scale: 0.96 + 0.04 * root.progress
        onEscapePressed: root.requestClose()
    }
}
