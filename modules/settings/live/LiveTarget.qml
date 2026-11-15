pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services

// The screen live previews show (live/LiveBars, LiveScreen): the focused
// monitor (where the settings window usually is), else the first one. Its
// logical size is the native size the real parts are laid out at, so a
// preview is the real panel of that screen, only scaled.
Singleton {
    id: root

    readonly property var screens: Quickshell.screens
    readonly property var screen: {
        const list = root.screens || [];
        const focused = YozdService.focusedMonitor ? YozdService.focusedMonitor.name : "";
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].name === focused)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }
    // a believable size while no screen is known (a size is still drawn)
    readonly property real width: root.screen && root.screen.width > 0 ? root.screen.width : 1920
    readonly property real height: root.screen && root.screen.height > 0 ? root.screen.height : 1080
    readonly property string name: root.screen ? root.screen.name : ""
}
