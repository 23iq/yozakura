import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.frame
import qs.modules.globals

// The screen frame (performance.splitFrame) in its own full-screen layer
// surface on the Top layer, below the unified panel (Overlay), so the bar,
// notch and dock animating no longer re-render it, and it no longer
// re-renders them. Its analytic shadow is drawn here, under it. No input
// (empty mask), no exclusive zone (ReservationWindows reserve the frame).
// `split` (FrameSplit) says when it is mapped; under a fullscreen window
// the unified panel draws the frame instead.
PanelWindow {
    id: window

    required property ShellScreen targetScreen
    property bool hasFullscreenWindow: false
    property FrameSplit split: null

    screen: targetScreen
    visible: !!window.split && window.split.windowShown

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: Brand.namespace("frame")
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        item: null
    }

    Item {
        id: content
        anchors.fill: parent

        FrameShapeShadow {
            frame: frameContent
        }

        ScreenFrameContent {
            id: frameContent
            anchors.fill: parent
            targetScreen: window.targetScreen
            hasFullscreenWindow: window.hasFullscreenWindow
        }
    }
}
