import QtQuick
import qs.modules.globals
import qs.config
import "PanoramaMath.js" as PanoramaMath

// Desktop depth layering (desktop.depthLayering): the wallpaper's near
// layer drawn again above the desktop widgets and icons, so they sit
// between the background and the subject. Lives in the desktop surface
// (Bottom layer): the bar, popups and windows stay above it.
//
// Matches the wallpaper pixel for pixel: the centred crop of a filled
// wallpaper, or the panorama with its pan and parallax (same PanoramaPan,
// driven by the same workspace change). Still images only; without a depth
// map or cut-out (PanoramaDepth) nothing is drawn.
Item {
    id: root

    property var screen: null
    // Edit desktop mode: widgets are being arranged, keep them on top.
    property bool suspended: false

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string screenName: screen ? screen.name : ""
    readonly property string file: manager ? ((manager.perScreenWallpapers || {})[screenName] || manager.currentWallpaper || "") : ""
    readonly property bool still: manager !== null && file !== "" && manager.getFileType(file) === "image"
    readonly property bool wanted: (Config.desktop.depthLayering ?? false) && still
    readonly property bool panorama: (Config.desktop.wallpaperMode ?? "fill") === "panorama"
    readonly property bool parallax: panorama && (Config.desktop.panoramaParallax ?? true)
    readonly property bool tint: manager ? manager.tintEnabled === true : false

    readonly property var geometry: PanoramaMath.layout(image.implicitWidth, image.implicitHeight, width, height)
    readonly property real targetX: panorama ? PanoramaMath.slotX(slot.index, slot.count, geometry.travel, width) : geometry.travel / 2
    readonly property string kind: depth.kind
    property bool settled: false

    visible: wanted && !suspended && kind !== "none"

    Image {
        id: image
        visible: false
        source: root.wanted ? "file://" + root.file : ""
        sourceSize.width: PanoramaMath.decodeSize(root.height).width
        sourceSize.height: PanoramaMath.decodeSize(root.height).height
        asynchronous: true
        smooth: true
        onStatusChanged: {
            if (status === Image.Ready)
                Qt.callLater(() => {
                    camera.jump();
                    root.settled = true;
                });
        }
    }

    PanoramaDepth {
        id: depth
        file: root.file
        wanted: root.wanted && image.status === Image.Ready
        knownMaps: root.manager ? (root.manager.depthMaps || []) : []
        screenW: Math.round(root.width)
        screenH: Math.round(root.height)
    }

    PanoramaSlot {
        id: slot
        screen: root.screen
    }

    PanoramaPan {
        id: camera
        target: root.targetX
        animate: root.settled && root.panorama
    }

    PaletteTexture {
        id: palette
        active: root.tint && root.visible
    }

    PanoramaLayer {
        source: image
        depthMap: root.kind === "map" ? depth.map : depth.cutout
        alphaDepth: root.kind === "cutout" ? 1 : 0
        mode: 2
        geometry: root.geometry
        // The wallpaper's near layer runs ahead during a parallax pan.
        x: -camera.layerX(root.parallax ? 2 : 0)
        paletteTexture: root.tint ? palette.texture : image
        paletteSize: palette.size
        tintEnabled: root.tint ? 1 : 0
    }
}
