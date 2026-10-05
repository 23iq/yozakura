import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.desktop

// A depth clock style as it renders on the current wallpaper: the real
// DepthClock (same placement, ink, subject cutout) laid out at the first
// screen's size and scaled into this item. Videos show their thumbnail
// with the clock in front (as on the desktop until a matte exists).
Item {
    id: root

    property string styleId: ""
    property string inkRole: "auto"

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property var screen: (Quickshell.screens || [])[0] ?? null
    readonly property int screenW: screen ? screen.width : 2560
    readonly property int screenH: screen ? screen.height : 1440
    readonly property string wallpaper: {
        const m = manager;
        if (!m)
            return "";
        const per = m.perScreenWallpapers ?? {};
        return (screen && per[screen.name]) || m.currentWallpaper || "";
    }
    readonly property bool isVideo: wallpaper !== "" && manager.getFileType(wallpaper) !== "image"

    clip: true

    Item {
        id: stage
        width: root.screenW
        height: root.screenH
        scale: Math.max(root.width / root.screenW, root.height / root.screenH)
        transformOrigin: Item.TopLeft

        Image {
            anchors.fill: parent
            source: root.wallpaper !== "" ? "file://" + root.manager.getDisplaySource(root.wallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Math.min(1280, root.screenW)
        }

        DepthClock {
            anchors.fill: parent
            wallpaperPath: root.wallpaper
            isVideo: root.isVideo
            styleId: root.styleId
            inkRole: root.inkRole
        }
    }
}
