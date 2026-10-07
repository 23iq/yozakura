pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.globals
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.desktop

// What a Wallpaper window shows: two ping-ponged content slots blended by the
// transition shader, the overview blur pass and the desktop depth clock.
Item {
    id: wallImageRoot
    // The owning Wallpaper window: transition style/duration, tint, video
    // pause state, overview blur, file type helper and the active video.
    required property var host
    property string source

    // Two content slots, ping-ponged. The front slot is what is on
    // screen; the other one loads the next wallpaper underneath it
    // (occluded) until it has real pixels, so a transition never shows
    // an empty/black frame. Then the transition shader blends
    // front -> back, the roles swap and the old slot is unloaded.
    property int frontIndex: 0
    readonly property WallpaperSlot frontSlot: frontIndex === 0 ? slotA : slotB
    readonly property WallpaperSlot backSlot: frontIndex === 0 ? slotB : slotA
    readonly property bool hasContent: frontSlot.status === Loader.Ready

    property bool pending: false
    property bool transitioning: false
    property real progress: 0

    // Per-transition parameters, fixed when a transition starts.
    readonly property var modes: ["fade", "grow", "wipe", "dissolve"]
    property int modeIndex: 0
    property point origin: Qt.point(0.5, 0.5)
    property real wipeAngle: 0.35
    property real seed: 0
    property int easingType: Easing.InOutCubic
    property Item fromItem: null
    property Item toItem: null

    // Depth clock on video wallpapers. A video with a finished matte
    // (DepthMaskService / scripts/depth_video.py) is played as its
    // stacked colour+mask variant, and DepthMatteForeground draws its
    // moving subject above the clock. Without a matte (still being built,
    // too long, disabled) the plain video plays and the clock stays in
    // front. Switching variants of the shown video reuses the slot
    // machinery: the other variant loads in the back slot at the same
    // position, then fades in.
    readonly property bool depthVideoEnabled: (Config.desktop.depthClock ?? false) && (Config.desktop.depthClockVideo ?? true)
    readonly property DepthClock clock: depthClockLoader.item as DepthClock
    readonly property VideoWallpaper frontVideo: frontSlot.item as VideoWallpaper
    readonly property VideoWallpaper matteVideo: frontVideo !== null && frontVideo.matteMode ? frontVideo : null
    // The subject can be drawn over the clock right now.
    readonly property bool matteShowing: matteVideo !== null && matteVideo.contentReady && !transitioning && frontSlot.sourceFile === source
    // Owner key for DepthMaskService.setMatteWanted (one per screen).
    property string screenName: ""
    readonly property string matteOwner: "wallpaper:" + (screenName || "default")
    readonly property string matteWantedPath: isMatteCandidate(source) ? source : ""
    readonly property var frontWantedMatte: frontSlot.sourceFile !== "" && frontSlot.sourceFile === source ? matteFor(frontSlot.sourceFile) : null
    property bool variantSwap: false
    // Matte files that failed to play: never offered again this session.
    property var brokenMattes: ({})
    // A video whose matte lookup is still running: held back (briefly)
    // so it does not load the plain variant only to swap right away.
    property string deferredSource: ""

    onMatteWantedPathChanged: DepthMaskService.setMatteWanted(matteOwner, matteWantedPath)
    onFrontWantedMatteChanged: Qt.callLater(syncFrontVariant)
    onSourceChanged: handleSourceChange()
    Component.onCompleted: {
        DepthMaskService.setMatteWanted(matteOwner, matteWantedPath);
        handleSourceChange();
    }
    Component.onDestruction: DepthMaskService.setMatteWanted(matteOwner, "")

    // Same list as getFileType()'s 'video' (GIFs stay plain: their
    // frame timing is often variable).
    function isVideoFile(file) {
        return /\.(mp4|webm|mov|avi|mkv)$/i.test(file || "");
    }

    function isMatteCandidate(file) {
        return depthVideoEnabled && isVideoFile(file);
    }

    // Matte info ({file, width, height, paddedHeight}) to play `file`
    // with, or null for the plain video.
    function matteFor(file) {
        if (!isMatteCandidate(file) || width <= 0 || height <= 0)
            return null;
        var r = DepthMaskService.result(file, Math.round(width), Math.round(height));
        if (!r || !r.ok || !r.matte || !r.matteInfo || brokenMattes[r.matte] === true)
            return null;
        // Decoding twice the pixels only pays off when the clock really
        // goes behind the subject at its chosen spot.
        if (!clock || clock.wallpaperPath !== file || clock.canDepth !== true)
            return null;
        return r.matteInfo;
    }

    function markMatteBroken(file) {
        if (!file || brokenMattes[file] === true)
            return;
        var broken = Object.assign({}, brokenMattes);
        broken[file] = true;
        brokenMattes = broken;
        // Still loading in the back slot: drop it (variant swap) or load
        // the plain video instead (new wallpaper).
        if (pending && matteKey(backSlot.matte) === file) {
            if (variantSwap)
                cancelPending();
            else
                loadSlot(backSlot, backSlot.sourceFile, null, -1);
        }
        // On screen already: frontWantedMatte changes, swap to plain.
        Qt.callLater(syncFrontVariant);
    }

    function matteKey(m) {
        return m ? m.file : "";
    }

    function needsDepthInfo(file) {
        return isMatteCandidate(file) && DepthMaskService.available && width > 0 && height > 0 && DepthMaskService.result(file, Math.round(width), Math.round(height)) === null;
    }

    function loadSlot(slot, file, matte, startPositionMs) {
        // Unload first: the variant is fixed for an item's lifetime.
        slot.sourceFile = "";
        slot.matte = file ? matte : null;
        slot.startPositionMs = startPositionMs;
        slot.sourceFile = file;
    }

    function resumeDeferred() {
        var src = deferredSource;
        if (!src)
            return;
        deferredSource = "";
        depthInfoWait.stop();
        if (src === source)
            proceedSourceChange(src);
    }

    function syncFrontVariant() {
        if (transitioning || pending || deferredSource !== "")
            return;
        var file = frontSlot.sourceFile;
        if (!file || file !== source || !isVideoFile(file))
            return;
        var want = matteFor(file);
        if (matteKey(want) === matteKey(frontSlot.matte))
            return;
        variantSwap = true;
        loadSlot(backSlot, file, want, frontVideo !== null ? frontVideo.positionMs : 0);
        pending = true;
        pendingTimeout.restart();
        Qt.callLater(checkPending);
    }

    function componentFor(file) {
        if (!file)
            return null;
        var fileType = wallImageRoot.host.getFileType(file);
        if (fileType === 'video' || fileType === 'gif')
            return videoWallpaperComponent;
        return staticImageComponent;
    }

    function handleSourceChange() {
        var src = source;
        // A new request while blending: land the running transition
        // first, then start the next one from its final frame.
        if (transitioning)
            finishTransition();
        deferredSource = "";
        depthInfoWait.stop();

        if (src === frontSlot.sourceFile) {
            // Back to what's already shown: drop any pending load.
            cancelPending();
            Qt.callLater(syncFrontVariant);
            return;
        }

        if (needsDepthInfo(src)) {
            cancelPending();
            deferredSource = src;
            depthInfoWait.restart();
            return;
        }
        proceedSourceChange(src);
    }

    function proceedSourceChange(src) {
        if (!src || !frontSlot.sourceFile) {
            // First wallpaper (nothing on screen yet) or cleared.
            cancelPending();
            loadSlot(frontSlot, src, matteFor(src), -1);
            return;
        }

        origin = resolveOrigin();
        variantSwap = false;
        loadSlot(backSlot, src, matteFor(src), -1);
        pending = true;
        pendingTimeout.restart();
        // contentReady may already be true (cached image).
        Qt.callLater(checkPending);
    }

    function cancelPending() {
        pending = false;
        variantSwap = false;
        pendingTimeout.stop();
        loadSlot(backSlot, "", null, -1);
    }

    function checkPending() {
        if (!pending || !backSlot.contentReady)
            return;
        commitPending();
    }

    function commitPending() {
        pending = false;
        pendingTimeout.stop();
        // Same video, other variant: continue exactly where it is now.
        var backVideo = backSlot.item as VideoWallpaper;
        if (variantSwap && backVideo !== null && frontVideo !== null)
            backVideo.alignTo(frontVideo.positionMs);
        if (shouldAnimate())
            startTransition();
        else
            swapSlots();
    }

    function shouldAnimate() {
        var style = wallImageRoot.host.transitionStyle;
        // Nobody can see the wallpaper under a fullscreen window or the
        // lock surface: swap instantly instead of spending GPU on it.
        return style !== "none" && wallImageRoot.host.transitionDuration > 0 && Config.animDuration > 0 && !GlobalStates.lockscreenVisible && !wallImageRoot.host.fullscreenActive && width > 0 && height > 0;
    }

    // Click position published by the wallpaper picker, in this
    // screen's coordinates; centre otherwise.
    function resolveOrigin() {
        var o = GlobalStates.wallpaperTransitionOrigin;
        if (o && (Date.now() - o.time) < 2000 && (!o.screen || o.screen === wallImageRoot.host.currentScreenName) && width > 0 && height > 0) {
            return Qt.point(Math.max(0, Math.min(1, o.x / width)), Math.max(0, Math.min(1, o.y / height)));
        }
        return Qt.point(0.5, 0.5);
    }

    function startTransition() {
        var style = wallImageRoot.host.transitionStyle;
        if (variantSwap)
            style = "fade";
        var randomStyle = style === "random";
        if (randomStyle)
            style = modes[1 + Math.floor(Math.random() * (modes.length - 1))];
        var idx = modes.indexOf(style);
        modeIndex = idx >= 0 ? idx : 0;
        wipeAngle = randomStyle ? Math.random() * Math.PI * 2 : 0.35;
        seed = Math.random() * 100;
        easingType = modeIndex === 0 ? Easing.InOutSine : Easing.InOutCubic;
        fromItem = frontSlot;
        toItem = backSlot;
        progress = 0;
        transitioning = true;
        transitionAnim.restart();
    }

    function finishTransition() {
        if (!transitioning)
            return;
        transitionAnim.stop();
        progress = 1;
        // All in one tick: the new slot becomes the plain front layer,
        // the old one unloads and the shader layer goes away, so the
        // next rendered frame is identical to the shader's last one.
        // Un-hide both slots synchronously. Loader teardown only
        // deleteLater()s the shader layer, and until then its
        // hideSource references would keep the new wallpaper hidden
        // (a black frame).
        const layer = transitionLayer.item as WallpaperTransitionLayer;
        if (layer)
            layer.release();
        swapSlots();
        transitioning = false;
        fromItem = null;
        toItem = null;
    }

    function swapSlots() {
        var old = frontSlot;
        frontIndex = 1 - frontIndex;
        loadSlot(old, "", null, -1);
        variantSwap = false;
        // The wanted variant may have changed meanwhile.
        Qt.callLater(syncFrontVariant);
    }

    Timer {
        id: depthInfoWait
        // Do not hold a wallpaper back for long if the lookup is slow.
        interval: 1500
        onTriggered: wallImageRoot.resumeDeferred()
    }

    Connections {
        target: DepthMaskService
        enabled: wallImageRoot.deferredSource !== ""
        function onRevisionChanged() {
            if (!wallImageRoot.needsDepthInfo(wallImageRoot.deferredSource))
                wallImageRoot.resumeDeferred();
        }
    }

    Timer {
        id: pendingTimeout
        // Safety net: a source that never reports ready still swaps.
        interval: 4000
        onTriggered: {
            if (wallImageRoot.pending)
                wallImageRoot.commitPending();
        }
    }

    NumberAnimation {
        id: transitionAnim
        target: wallImageRoot
        property: "progress"
        from: 0
        to: 1
        duration: Math.max(1, wallImageRoot.host.transitionDuration)
        easing.type: wallImageRoot.easingType
        onFinished: wallImageRoot.finishTransition()
    }

    Item {
        id: stage
        anchors.fill: parent

        WallpaperSlot {
            id: slotA
            anchors.fill: parent
            // Deferred: the slot may unload the failed item.
            onMatteFailed: file => Qt.callLater(() => wallImageRoot.markMatteBroken(file))
            z: wallImageRoot.frontIndex === 0 ? 1 : 0
            sourceComponent: wallImageRoot.componentFor(sourceFile)
            onContentReadyChanged: wallImageRoot.checkPending()
        }

        WallpaperSlot {
            id: slotB
            anchors.fill: parent
            // Deferred: the slot may unload the failed item.
            onMatteFailed: file => Qt.callLater(() => wallImageRoot.markMatteBroken(file))
            z: wallImageRoot.frontIndex === 1 ? 1 : 0
            sourceComponent: wallImageRoot.componentFor(sourceFile)
            onContentReadyChanged: wallImageRoot.checkPending()
        }

        // Only exists while a transition runs: no shader, offscreen
        // textures or per-frame cost the rest of the time.
        Loader {
            id: transitionLayer
            anchors.fill: parent
            z: 2
            active: wallImageRoot.transitioning

            sourceComponent: Component {
                WallpaperTransitionLayer {
                    fromItem: wallImageRoot.fromItem
                    toItem: wallImageRoot.toItem
                    progress: wallImageRoot.progress
                    mode: wallImageRoot.modeIndex
                    origin: wallImageRoot.origin
                    angle: wallImageRoot.wipeAngle
                    seed: wallImageRoot.seed
                }
            }
        }
    }

    // The effect pass is only mounted where it can actually trigger;
    // elsewhere the stage renders directly with zero overhead.
    Loader {
        anchors.fill: parent
        active: wallImageRoot.host.overviewBlurPossible
        sourceComponent: Component {
            MultiEffect {
                anchors.fill: parent
                source: stage
                autoPaddingEnabled: false
                // Keep the effect alive while the fade-out animation runs.
                blurEnabled: wallImageRoot.host.overviewBlurActive || blur > 0
                blurMax: 64
                blur: wallImageRoot.host.overviewBlurActive ? 1.0 : 0.0
                visible: wallImageRoot.hasContent

                Behavior on blur {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Motion.morph.easing
                    }
                }
            }
        }
    }

    // Desktop depth clock: drawn over the wallpaper, under its subject.
    Loader {
        id: depthClockLoader
        anchors.fill: parent
        active: Config.desktop.depthClock ?? false
        property string sourceFile: parent.source
        sourceComponent: DepthClock {
            wallpaperPath: depthClockLoader.sourceFile
            isVideo: wallImageRoot.host.getFileType(depthClockLoader.sourceFile) !== 'image'
            tint: wallImageRoot.host.tintEnabled
            suppressed: wallImageRoot.host.overviewBlurActive
        }
    }

    // Publishes the clock's area for desktop widgets (DesktopWidgets).
    Binding {
        target: wallImageRoot.clock
        property: "areaKey"
        value: wallImageRoot.screenName
        when: wallImageRoot.clock !== null
    }

    Binding {
        target: wallImageRoot.clock
        property: "matteActive"
        value: wallImageRoot.matteShowing
        when: wallImageRoot.clock !== null
    }

    // The video's moving subject, above the clock (matte variant only).
    DepthMatteForeground {
        id: depthForeground
        anchors.fill: parent
        readonly property bool shown: wallImageRoot.matteShowing && wallImageRoot.clock !== null && wallImageRoot.clock.depthActive
        video: wallImageRoot.matteVideo
        // Follows the clock's own fades (settling, overview blur).
        opacity: shown ? wallImageRoot.clock.opacity : 0
        visible: video !== null && video.matteTexture !== null && opacity > 0
    }

    // DepthClock's front part (date, ornaments) above the moving subject.
    Item {
        id: depthClockFront
        anchors.fill: parent
        opacity: wallImageRoot.clock?.opacity ?? 0
    }
    Binding {
        target: wallImageRoot.clock
        property: "frontHost"
        value: depthClockFront
        when: wallImageRoot.clock !== null
    }

    Component {
        id: staticImageComponent
        StaticWallpaper {
            sourceFile: (parent as WallpaperSlot)?.sourceFile ?? ""
            tint: wallImageRoot.host.tintEnabled
            sourceWidth: wallImageRoot.host.width
            sourceHeight: wallImageRoot.host.height
        }
    }

    Component {
        id: videoWallpaperComponent
        VideoWallpaper {
            id: videoWallpaperChild
            sourceFile: (parent as WallpaperSlot)?.sourceFile ?? ""
            matte: (parent as WallpaperSlot)?.matte ?? null
            startPositionMs: (parent as WallpaperSlot)?.startPositionMs ?? -1
            tint: wallImageRoot.host.tintEnabled
            paused: wallImageRoot.host.videoPaused
            onRequestVideoSync: wallImageRoot.host.requestVideoSync()

            Component.onCompleted: wallImageRoot.host.activeVideo = videoWallpaperChild
            Component.onDestruction: {
                if (wallImageRoot.host.activeVideo === videoWallpaperChild)
                    wallImageRoot.host.activeVideo = null;
            }
        }
    }
}
