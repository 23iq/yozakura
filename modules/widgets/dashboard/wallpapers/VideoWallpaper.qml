pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import qs.modules.globals
import qs.modules.theme

Item {
    id: videoWallpaper

    property string sourceFile
    property bool tint: false
    // Depth clock "matte video" (scripts/depth_video.py): {file, width,
    // height, paddedHeight}. When set, the stacked colour+mask video is
    // played instead of sourceFile and drawn through depth_matte.frag; the
    // subject cutout for above the clock is DepthMatteForeground, fed from
    // matteTexture. Fixed for the item's lifetime (the wallpaper swaps
    // items to switch).
    property var matte: null
    readonly property bool matteMode: matte !== null && !!matte.file
    // >= 0: start at this position (ms) instead of the beginning, without
    // asking the other screens to resync. Used when swapping between the
    // plain and the matte variant of the same video.
    property real startPositionMs: -1
    // Holds playback on the current frame (e.g. while a fullscreen window
    // covers this monitor). pause() keeps the last frame on the
    // VideoOutput, so resuming never flashes black.
    property bool paused: false
    signal requestVideoSync
    // Matte mode only: the matte stream could not be played (missing,
    // pruned or corrupt). contentReady stays false so a transition never
    // reveals it; the wallpaper falls back to the plain video.
    signal matteFailed

    readonly property real positionMs: player.position
    readonly property real durationMs: player.duration

    // Shared with DepthMatteForeground.
    readonly property Item matteTexture: matteMode ? matteSource : null
    readonly property Item paletteTexture: paletteTextureSource
    readonly property int paletteSize: optimizedPalette.length
    readonly property real matteAspect: matteMode && matte.height > 0 ? matte.width / matte.height : 1
    readonly property real itemAspect: height > 0 ? width / height : 1
    // PreserveAspectCrop, same framing as the plain VideoOutput.
    readonly property vector2d cropScale: matteAspect > itemAspect ? Qt.vector2d(itemAspect / matteAspect, 1) : Qt.vector2d(1, matteAspect / itemAspect)
    readonly property vector2d cropOffset: Qt.vector2d((1 - cropScale.x) / 2, (1 - cropScale.y) / 2)
    readonly property real contentFrac: matteMode && matte.paddedHeight > 0 ? matte.height / matte.paddedHeight : 1

    // True once the sink has received a frame for the current source, so a
    // wallpaper transition can wait for real pixels instead of showing the
    // empty (black) VideoOutput. Also set on error so a broken file never
    // blocks the swap forever.
    property bool contentReady: false

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    // Start once every initial binding (source, matte, start position) is
    // in, instead of once per property.
    property bool _completed: false
    onSourceFileChanged: {
        if (_completed)
            restartPlayback();
    }
    onMatteChanged: {
        if (_completed)
            restartPlayback();
    }
    Component.onCompleted: {
        _completed = true;
        restartPlayback();
    }

    onPausedChanged: {
        if (!sourceFile)
            return;
        if (paused)
            player.pause();
        else
            player.play();
    }

    function restartPlayback() {
        contentReady = false;
        if (!sourceFile)
            return;
        player.stop();
        player.source = "file://" + (matteMode ? matte.file : sourceFile);
        if (startPositionMs >= 0)
            player.setPosition(startPositionMs);
        // Paused state still loads and shows the first frame.
        if (paused)
            player.pause();
        else
            player.play();
        if (startPositionMs < 0)
            syncDebounce.restart();
    }

    // Re-align with another player of the same loop (variant swap).
    function alignTo(ms) {
        if (ms < 0 || player.duration <= 0)
            return;
        if (Math.abs(player.position - ms) > 80)
            player.setPosition(ms % player.duration);
    }

    Timer {
        id: syncDebounce
        interval: 300
        onTriggered: videoWallpaper.requestVideoSync()
    }

    MediaPlayer {
        id: player
        audioOutput: mutedAudio
        videoOutput: videoOut
        loops: MediaPlayer.Infinite

        onErrorOccurred: (error, errorString) => {
            console.warn("VideoWallpaper playback error:", error, errorString, "source:", videoWallpaper.sourceFile, videoWallpaper.matteMode ? "(matte " + videoWallpaper.matte.file + ")" : "");
            if (videoWallpaper.matteMode)
                videoWallpaper.matteFailed();
            else
                videoWallpaper.contentReady = true;
        }
    }

    // First-frame detection. Disabled once ready so the per-frame signal
    // costs nothing during normal playback.
    Connections {
        target: videoOut.videoSink
        enabled: !videoWallpaper.contentReady
        function onVideoFrameChanged() {
            videoWallpaper.contentReady = true;
        }
    }

    AudioOutput {
        id: mutedAudio
        muted: true
        volume: 0
    }

    Item {
        id: paletteSourceItem
        visible: true
        width: videoWallpaper.optimizedPalette.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: videoWallpaper.optimizedPalette
                Rectangle {
                    required property string modelData
                    width: 1
                    height: 1
                    color: Colors[modelData]
                }
            }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteSourceItem
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }

    VideoOutput {
        id: videoOut
        // Matte mode: the whole stacked frame, 1:1 into an offscreen
        // texture; depth_matte.frag does the framing.
        width: parent.width
        height: videoWallpaper.matteMode ? parent.height * 2 : parent.height
        fillMode: videoWallpaper.matteMode ? VideoOutput.Stretch : VideoOutput.PreserveAspectCrop
        layer.enabled: videoWallpaper.tint && !videoWallpaper.matteMode
        layer.effect: ShaderEffect {
            property var paletteTexture: paletteTextureSource
            property real paletteSize: videoWallpaper.optimizedPalette.length
            property real texWidth: videoOut.width
            property real texHeight: videoOut.height

            vertexShader: "palette.vert.qsb"
            fragmentShader: "palette.frag.qsb"
        }
    }

    // Matte mode only (inert otherwise): the whole stacked frame as a texture
    // for depth_matte.frag, here and in DepthMatteForeground.
    ShaderEffectSource {
        id: matteSource
        sourceItem: videoWallpaper.matteMode ? videoOut : null
        hideSource: videoWallpaper.matteMode
        live: videoWallpaper.matteMode
        visible: false
        smooth: true
    }

    // The wallpaper itself: top half of the stream.
    ShaderEffect {
        anchors.fill: parent
        visible: videoWallpaper.matteMode
        property var source: matteSource
        property var paletteTexture: paletteTextureSource
        property vector2d cropOffset: videoWallpaper.cropOffset
        property vector2d cropScale: videoWallpaper.cropScale
        property real contentFrac: videoWallpaper.contentFrac
        property real texelY: videoOut.height > 0 ? 1 / videoOut.height : 0
        property real foreground: 0
        property real tint: videoWallpaper.tint ? 1 : 0
        property real paletteSize: videoWallpaper.paletteSize
        fragmentShader: "depth_matte.frag.qsb"
    }

    Connections {
        target: GlobalStates
        function onVideoSyncTickChanged() {
            player.setPosition(0);
            if (!videoWallpaper.paused && player.playbackState !== MediaPlayer.PlayingState)
                player.play();
        }
    }
}
