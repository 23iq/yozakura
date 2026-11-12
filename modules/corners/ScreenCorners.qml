import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config
import qs.modules.bar.workspaces // For CompositorData

// Rounded screen corners of one output: four corner-sized layer surfaces
// (ScreenCornerWindow), not one transparent full-screen window, so the
// compositor blends four small squares instead of a whole extra screen-size
// buffer (8 / 15 / 33 MB per buffer at 1080p / 1440p / 4K). Hidden (unmapped,
// so a fullscreen window can still be scanned out directly) under a fullscreen
// window and while corners are off. The four windows flip together, once the
// wanted state has held for `settleInterval` ms: a quick fullscreen toggle
// does not unmap and remap four surfaces (bursts of surface create/destroy
// are a QtWayland crash source).
Item {
    id: root

    property ShellScreen screen: null
    property var monitor: null
    property bool activeWindowFullscreen: false

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property int thickness: {
        const value = Config.bar?.frameThickness;
        if (typeof value !== "number")
            return 6;
        return Math.max(1, Math.min(Math.round(value), 40));
    }
    // The corner reaches past the frame when it is on.
    readonly property int cornerSize: Styling.radius(4) + (frameEnabled ? thickness : 0)
    readonly property bool wanted: Config.theme.enableCorners && Config.roundness > 0 && !activeWindowFullscreen
    property int settleInterval: 250
    readonly property bool shown: shownGate.output === true

    SettleGate {
        id: shownGate
        value: root.wanted
        interval: root.settleInterval
    }

    function updateFullscreen() {
        const mon = YozdService.monitorFor(root.screen);
        if (mon) {
            monitor = mon;
        }

        activeWindowFullscreen = CompositorData.monitorHasFullscreen(monitor);
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() {
            root.updateFullscreen();
        }
    }

    Connections {
        target: YozdService.monitors
        function onValuesChanged() {
            root.updateFullscreen();
        }
    }

    Component.onCompleted: updateFullscreen()

    ScreenCornerWindow {
        screen: root.screen
        visible: root.shown
        size: root.cornerSize
        corner: RoundCorner.CornerEnum.TopLeft
    }

    ScreenCornerWindow {
        screen: root.screen
        visible: root.shown
        size: root.cornerSize
        corner: RoundCorner.CornerEnum.TopRight
    }

    ScreenCornerWindow {
        screen: root.screen
        visible: root.shown
        size: root.cornerSize
        corner: RoundCorner.CornerEnum.BottomLeft
    }

    ScreenCornerWindow {
        screen: root.screen
        visible: root.shown
        size: root.cornerSize
        corner: RoundCorner.CornerEnum.BottomRight
    }
}
