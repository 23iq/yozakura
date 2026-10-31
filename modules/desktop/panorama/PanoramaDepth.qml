import QtQuick
import qs.modules.services
import "PanoramaMath.js" as PanoramaMath

// Depth information for a still wallpaper, in order of preference:
//   "map"    a grey depth map next to the image (<name>.depth.png, white =
//            near), split into layers by depth;
//   "cutout" the subject cut-out of the depth clock pipeline
//            (DepthMaskService, needs the optional depth venv);
//   "none"   neither: the panorama simply pans as one layer.
// Both are decoded at the panorama's size and exposed as texture providers.
Item {
    id: root

    property string file: ""
    property bool wanted: false
    property int screenW: 0
    property int screenH: 0
    property var decodeSize: PanoramaMath.decodeSize(screenH)
    // Depth maps the wallpaper scan found (Wallpaper.depthMaps).
    property var knownMaps: []
    readonly property string mapPath: PanoramaMath.depthMapPath(file)
    readonly property bool hasMap: file !== "" && (knownMaps || []).indexOf(mapPath) !== -1

    readonly property string kind: !wanted ? "none" : mapImage.status === Image.Ready ? "map" : cutoutImage.status === Image.Ready ? "cutout" : "none"
    readonly property Image map: mapImage
    readonly property Image cutout: cutoutImage
    // No map (or it failed to load): ask the depth clock pipeline for a cutout.
    readonly property bool mapMissing: wanted && file !== "" && (!hasMap || mapImage.status === Image.Error)
    readonly property var maskInfo: mapMissing && DepthMaskService.available && screenW > 0 && screenH > 0 ? DepthMaskService.result(file, screenW, screenH) : null
    readonly property string cutoutFile: maskInfo && maskInfo.ok && maskInfo.cutout ? maskInfo.cutout : ""

    width: 0
    height: 0

    function requestMask() {
        if (mapMissing && DepthMaskService.available && screenW > 0 && screenH > 0)
            DepthMaskService.request(file, screenW, screenH);
    }
    onMapMissingChanged: Qt.callLater(requestMask)
    onFileChanged: Qt.callLater(requestMask)

    // Texture sources only: drawn by PanoramaLayer, never on their own.
    Image {
        id: mapImage
        visible: false
        source: root.wanted && root.hasMap ? "file://" + root.mapPath : ""
        sourceSize.width: root.decodeSize.width
        sourceSize.height: root.decodeSize.height
        asynchronous: true
        smooth: true
    }

    Image {
        id: cutoutImage
        visible: false
        source: root.cutoutFile ? "file://" + root.cutoutFile : ""
        sourceSize.width: root.decodeSize.width
        sourceSize.height: root.decodeSize.height
        asynchronous: true
        cache: false
        smooth: true
    }
}
