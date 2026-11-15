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

    // The screen whole-screen overviews (ScreenMini: the Screen canvas, the
    // home tile, the desktop / wallpaper / windows stages) lay the real parts
    // out on: your screen's shape at most OVERVIEW px wide. On a big monitor
    // the bars, island and dock keep their real pixel sizes on a smaller
    // screen, so in a ~550 px canvas they read (a 2560 px screen would draw
    // a 44 px rail 9 px wide; on 1280 it is 19 px). Only the empty space
    // between the parts shrinks; a picture of one part uses the real size.
    readonly property int overviewMax: 1280
    readonly property real overviewWidth: Math.min(root.width, root.overviewMax)
    readonly property real overviewHeight: Math.round(root.overviewWidth * root.height / root.width)
    // {name, width, height}: for parts that place themselves on a screen
    // (the island: NotchPreview)
    readonly property var overview: ({
            "name": root.name,
            "width": root.overviewWidth,
            "height": root.overviewHeight
        })
}
