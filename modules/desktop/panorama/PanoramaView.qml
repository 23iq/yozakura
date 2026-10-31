import QtQuick
import "PanoramaMath.js" as PanoramaMath

// Panorama ("emaki") wallpaper: one wide still image scaled to the screen
// height; the viewport glides to the active workspace's slot, so the
// workspaces are frames of one continuous scroll. With depth (PanoramaDepth)
// the image is split into depth layers whose near parts run ahead during a
// pan (parallax, one shader pass) and line up again at rest.
//
// Same contract as StaticWallpaper for WallpaperImage/WallpaperSlot:
// sourceFile, tint, sourceWidth/sourceHeight (screen), contentReady.
Item {
    id: root

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    clip: true

    property string sourceFile: ""
    property bool tint: false
    property real sourceWidth: 0
    property real sourceHeight: 0

    property int slotIndex: 0
    property int slotCount: 1
    // Split near parts into parallax layers when depth is available.
    property bool parallax: true
    // Depth maps next to wallpapers (Wallpaper.depthMaps).
    property var depthMaps: []

    readonly property bool contentReady: image.status === Image.Ready || image.status === Image.Error
    readonly property real screenH: sourceHeight > 0 ? sourceHeight : height
    readonly property var geometry: PanoramaMath.layout(image.implicitWidth, image.implicitHeight, width, height)
    readonly property real targetX: PanoramaMath.slotX(slotIndex, slotCount, geometry.travel, width)
    readonly property string depthKind: depth.kind
    // Depth layers drawn: far/mid/near with a map, background/subject with a cut-out.
    readonly property int layerCount: depthKind === "map" ? 3 : depthKind === "cutout" ? 2 : 1
    readonly property alias pan: camera

    // The first placement (and a new image size) jumps; later moves glide.
    property bool settled: false

    Image {
        id: image
        visible: false
        source: root.sourceFile ? "file://" + root.sourceFile : ""
        sourceSize.width: PanoramaMath.decodeSize(root.screenH).width
        sourceSize.height: PanoramaMath.decodeSize(root.screenH).height
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
        file: root.sourceFile
        wanted: root.parallax && image.status === Image.Ready
        knownMaps: root.depthMaps
        screenW: Math.round(root.width)
        screenH: Math.round(root.screenH)
    }

    PaletteTexture {
        id: palette
        active: root.tint
    }

    PanoramaPan {
        id: camera
        target: root.targetX
        animate: root.settled
    }

    PanoramaLayer {
        readonly property string kind: root.depthKind
        source: image
        depthMap: kind === "map" ? depth.map : kind === "cutout" ? depth.cutout : image
        alphaDepth: kind === "cutout" ? 1 : 0
        mode: kind === "none" ? 0 : 1
        geometry: root.geometry
        x: -camera.layerX(0)
        // Near layer ahead of the image (screen px) right now.
        lead: kind === "none" ? 0 : camera.layerX(0) - camera.layerX(2)
        paletteTexture: root.tint ? palette.texture : image
        paletteSize: palette.size
        tintEnabled: root.tint ? 1 : 0
    }
}
