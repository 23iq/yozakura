import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.services
import qs.config
import qs.modules.bar.workspaces // For CompositorData
import qs.modules.globals

PanelWindow {
    id: screenCorners

    property var monitor: null
    property bool activeWindowFullscreen: false

    function updateFullscreen() {
        const mon = YozdService.monitorFor(screen);
        if (mon) {
            monitor = mon;
        }

        activeWindowFullscreen = CompositorData.monitorHasFullscreen(monitor);
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() { screenCorners.updateFullscreen(); }
    }

    Connections {
        target: YozdService.monitors
        function onValuesChanged() { screenCorners.updateFullscreen(); }
    }

    Component.onCompleted: updateFullscreen()

    visible: Config.theme.enableCorners && Config.roundness > 0 && !activeWindowFullscreen

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: Brand.namespace("screenCorners")
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: null
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    ScreenCornersContent {
        id: cornersContent
        anchors.fill: parent
        hasFullscreenWindow: screenCorners.activeWindowFullscreen
    }
}
