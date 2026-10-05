import QtQuick

// One wallpaper content slot of WallpaperImage: what to show, and for a
// video which variant (plain or depth matte) and where to start.
Loader {
    id: slot
    property string sourceFile: ""
    property var matte: null
    property real startPositionMs: -1
    readonly property VideoWallpaper video: item as VideoWallpaper
    // Static images and videos both report when they have real pixels.
    readonly property bool contentReady: status === Loader.Ready && item !== null && (video !== null ? video.contentReady : (item as StaticWallpaper)?.contentReady) === true
    signal matteFailed(string file)

    active: sourceFile !== ""

    Connections {
        target: slot.video
        function onMatteFailed() {
            slot.matteFailed(slot.matte ? slot.matte.file : "");
        }
    }
}
