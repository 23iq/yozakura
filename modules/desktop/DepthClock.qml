pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.services
import qs.modules.theme
import qs.config
import qs.modules.desktop.widgets
import "clockstyles/ClockStyleRegistry.js" as ClockStyles
import "clockstyles/ClockPlacement.js" as ClockPlacement
// Styles are loaded by URL from the registry; this directory import makes
// Quickshell's scanner include clockstyles/ (it only synthesizes qmldirs for
// directories reached through imports), so the styles' sibling types resolve.
import "clockstyles" as ClockStyleTypes
import qs.modules.bar.panels

// Depth clock host: a clock drawn over the wallpaper and under the
// wallpaper's own subject. The subject comes back on top as a pre-rendered
// RGBA cutout (DepthMaskService), drawn with exactly the same fill/scaling
// as the wallpaper image, so no per-frame work is needed: the scene only
// changes once a minute.
//
// The look comes from a style (clockstyles/, ClockStyleRegistry.js): the
// host renders wallpaper → style "behind" part → cutout → style "front"
// part, and places the style per screen from the mask's coverage grid.
//
// Lives inside the wallpaper surface (Background layer) so desktop icons
// (Bottom layer) and windows stay above it. Videos/GIFs get the clock in
// front (a frozen cutout over a moving video looks wrong), except when the
// wallpaper plays a per-frame "matte video" (scripts/depth_video.py): then
// the wallpaper draws the moving subject above this item itself
// (DepthMatteForeground) and only needs `depthActive` from here.
//
// Interface used by Wallpaper.qml (keep it when restyling the clock):
//   in:  wallpaperPath, isVideo, matteActive, tint, suppressed,
//        frontHost (optional item above the matte subject: the style's
//        front part is moved there so it stays in front of a moving subject)
//        areaKey (screen name: publishes the clock's bounds to
//        DesktopWidgets.clockAreas so widgets can keep clear of it)
//   out: canDepth (placement puts the subject in front of the time),
//        depthActive (the time is currently drawn behind the subject)
// The settings gallery also sets styleId (preview another style) and
// inkRole (preview another ink).
Item {
    id: root

    property string wallpaperPath: ""
    property bool isVideo: false
    // The wallpaper is playing this video's matte variant and will draw the
    // subject above the clock.
    property bool matteActive: false
    // See the interface note above; null keeps the front part in here.
    property Item frontHost: null
    property bool tint: false
    // Fades the clock out (e.g. while the wallpaper is blurred for niri's overview).
    property bool suppressed: false

    readonly property int screenW: Math.round(width)
    readonly property int screenH: Math.round(height)
    property string areaKey: ""
    property string styleId: Config.desktop.depthClockStyle ?? ClockStyles.DEFAULT_ID
    property string inkRole: Config.desktop.depthClockInk ?? "auto"

    readonly property var style: ClockStyles.get(styleId)
    readonly property string position: Config.desktop.depthClockPosition ?? "auto"
    readonly property bool use12h: Config.bar.use12hFormat ?? false

    readonly property var info: (wallpaperPath && screenW > 0 && screenH > 0) ? DepthMaskService.result(wallpaperPath, screenW, screenH) : null
    readonly property var layoutInfo: (info && info.ok && info.layouts) ? (info.layouts[screenW + "x" + screenH] ?? null) : null
    // Hold the clock back until the mask lookup answered (a cache hit is
    // ~20 ms), so it does not visibly jump spots right after a wallpaper change.
    readonly property bool settled: info !== null || !DepthMaskService.available || settleTimer.expired

    // Screen area not reserved by the bar / frame.
    readonly property string barPosition: Panels.primaryEdge
    readonly property int barSize: Config.showBackground ? 44 : 40
    readonly property int frameSize: (Config.bar.frameEnabled ?? false) ? (Config.bar.frameThickness ?? 0) : 0
    readonly property var safeArea: {
        const f = frameSize;
        const l = f + (barPosition === "left" ? barSize : 0);
        const r = f + (barPosition === "right" ? barSize : 0);
        const t = f + (barPosition === "top" ? barSize : 0);
        const b = f + (barPosition === "bottom" ? barSize : 0);
        return {
            x: l,
            y: t,
            w: Math.max(1, screenW - l - r),
            h: Math.max(1, screenH - t - b)
        };
    }
    // Desktop icons fill columns from the top-left: keep the clock clear.
    readonly property real iconsWidth: {
        const count = (Config.desktop.enabled ?? false) ? (DesktopService.items ? DesktopService.items.count : 0) : 0;
        if (count <= 0)
            return 0;
        const cell = (Config.desktop.iconSize ?? 40) + 40 + (Config.desktop.spacingVertical ?? 16);
        const rowsPerColumn = Math.max(1, DesktopService.maxRowsHint);
        return 16 + Math.ceil(count / rowsPerColumn) * cell;
    }
    readonly property var areas: ({
            left: {
                x: safeArea.x + iconsWidth,
                y: safeArea.y,
                w: Math.max(1, safeArea.w - iconsWidth),
                h: safeArea.h
            },
            right: safeArea
        })

    // Placement grid from the mask script; without one (no venv), a
    // luminance-only grid measured here so the ink still fits the backdrop.
    readonly property bool scriptGrid: !!(layoutInfo && layoutInfo.grid)
    readonly property var grid: scriptGrid ? layoutInfo.grid : ((probeLoader.item as ClockBackdropProbe)?.grid ?? null)

    readonly property var placement: ClockPlacement.choose(style, grid, {
        screenW: screenW,
        screenH: screenH,
        areas: areas,
        position: position,
        preferSide: iconsWidth > 0 ? "right" : "left",
        use12h: use12h
    })
    // Videos: only with a matte and when the subject actually reaches the
    // time at some point, otherwise playing the (2x taller) matte stream
    // buys nothing.
    readonly property bool canDepth: placement.depth && info !== null && (isVideo ? (!!info.matte && placement.reach > 0.01) : !!info.cutout)
    readonly property bool wantsDepth: canDepth && (!isVideo || matteActive)
    readonly property bool depthActive: wantsDepth && (isVideo || cutout.status === Image.Ready)
    // Sharpened matte edge (render time, so cached masks stay valid).
    readonly property real edgeLow: 0.35
    readonly property real edgeHigh: 0.65

    property date now: new Date()

    // Geometry of `entry` for the current placement side. Normally that is
    // placement.layout; while a style switch propagates, the still-loaded
    // style must not receive the other style's geometry.
    function layoutFor(entry) {
        if (placement.layout.styleId === entry.id)
            return placement.layout;
        const side = entry.sides.indexOf(placement.side) !== -1 ? placement.side : entry.sides[0];
        const l = entry.layout({
            screenW: screenW,
            screenH: screenH,
            area: areas[side] ?? safeArea,
            side: side,
            use12h: use12h
        });
        l.styleId = entry.id;
        return l;
    }

    readonly property var publishedArea: areaKey !== "" && settled && placement.layout ? placement.layout.bounds ?? null : null
    onPublishedAreaChanged: {
        if (areaKey !== "")
            DesktopWidgets.setClockArea(areaKey, publishedArea);
    }
    Component.onDestruction: {
        if (areaKey !== "")
            DesktopWidgets.setClockArea(areaKey, null);
    }

    function requestMask() {
        if (wallpaperPath && screenW > 0 && screenH > 0)
            DepthMaskService.request(wallpaperPath, screenW, screenH);
    }

    function scheduleTick() {
        const d = new Date();
        tick.interval = 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 25;
        tick.restart();
    }

    onWallpaperPathChanged: {
        settleTimer.expired = false;
        settleTimer.restart();
        Qt.callLater(requestMask);
    }
    onScreenWChanged: Qt.callLater(requestMask)
    onScreenHChanged: Qt.callLater(requestMask)
    Component.onCompleted: {
        settleTimer.restart();
        requestMask();
        scheduleTick();
    }

    opacity: settled && !suppressed ? 1 : 0
    visible: opacity > 0
    onVisibleChanged: {
        if (visible) {
            now = new Date();
            scheduleTick();
        }
    }

    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.enter.easing
        }
    }

    // Minute-aligned, and only while the clock can be seen.
    Timer {
        id: tick
        running: root.visible
        onTriggered: {
            root.now = new Date();
            root.scheduleTick();
        }
    }

    Timer {
        id: settleTimer
        property bool expired: false
        interval: 1500
        onTriggered: expired = true
    }

    // Both halves of the style get the same inputs, so they line up.
    component StylePart: Loader {
        id: stylePart
        required property string part
        // Registry entry of the loaded style.
        property var entry: null
        readonly property url styleUrl: Qt.resolvedUrl("clockstyles/" + root.style.file)

        // Initial values first (a style never sees a null layout), then
        // live bindings.
        function load() {
            const entry = root.style;
            stylePart.entry = entry;
            setSource(styleUrl, {
                part: stylePart.part,
                now: root.now,
                light: root.placement.light,
                side: root.placement.side,
                layout: root.layoutFor(entry),
                use12h: root.use12h,
                inkRole: root.inkRole,
                animDuration: Config.animDuration
            });
        }

        anchors.fill: parent
        onStyleUrlChanged: load()
        Component.onCompleted: load()
        onLoaded: {
            const style = stylePart.item;
            const entry = stylePart.entry;
            style.now = Qt.binding(() => root.now);
            style.light = Qt.binding(() => root.placement.light);
            style.side = Qt.binding(() => root.placement.side);
            style.layout = Qt.binding(() => root.layoutFor(entry));
            style.use12h = Qt.binding(() => root.use12h);
            style.inkRole = Qt.binding(() => root.inkRole);
            style.animDuration = Qt.binding(() => Config.animDuration);
        }
    }

    Loader {
        id: probeLoader
        active: !root.scriptGrid && !root.isVideo && root.info !== null && !!root.wallpaperPath
        sourceComponent: ClockBackdropProbe {
            source: root.wallpaperPath
            screenW: root.screenW
            screenH: root.screenH
        }
    }

    // 1) The style's "behind" part (the time), under the subject.
    StylePart {
        id: behindPart
        part: "behind"
    }

    // 2) The wallpaper's subject, cut out, on top of the time.
    Image {
        id: cutout
        anchors.fill: parent
        // Same fill + decode size as the static wallpaper image, so the
        // cutout lines up with it pixel for pixel.
        source: root.wantsDepth && !root.isVideo ? "file://" + root.info.cutout : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: opacity > 0
        opacity: root.depthActive && !root.isVideo ? 1 : 0
        Behavior on opacity {
            // Only fade in: a stale subject must vanish with its wallpaper.
            enabled: Config.animDuration > 0 && root.depthActive && !root.isVideo
            NumberAnimation {
                duration: Config.animDuration * 2
                easing.type: Motion.enter.easing
            }
        }

        layer.enabled: root.depthActive && !root.isVideo
        layer.effect: ShaderEffect {
            property var paletteTexture: paletteTextureSource
            property real paletteSize: root.tintPalette.length
            property real tintEnabled: root.tint ? 1 : 0
            property real edgeLow: root.edgeLow
            property real edgeHigh: root.edgeHigh

            vertexShader: Qt.resolvedUrl("shaders/depth_cutout.vert.qsb")
            fragmentShader: Qt.resolvedUrl("shaders/depth_cutout.frag.qsb")
        }
    }

    // 3) The style's "front" part (date, ornaments), over the subject.
    StylePart {
        id: frontPart
        part: "front"
        parent: root.frontHost ?? root
    }

    // Palette texture for tinting the cutout like the tinted wallpaper.
    // Mirrors the static wallpaper's palette subset; only built when tinting.
    readonly property var tintPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    Item {
        id: paletteSourceItem
        visible: root.tint
        width: root.tintPalette.length
        height: 1
        opacity: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: root.tint ? root.tintPalette : []
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
        sourceItem: root.tint ? paletteSourceItem : null
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }
}
