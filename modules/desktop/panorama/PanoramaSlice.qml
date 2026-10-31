import QtQuick
import qs.modules.globals
import "PanoramaMath.js" as PanoramaMath

// One workspace's frame of the panorama, scaled into this item (overview
// "scroll" style, settings preview). Every slice of a panorama decodes the
// image at the same small size, so they share one cached copy; frames a
// screen apart line up into one continuous scroll.
Item {
    id: root

    property string sourceFile: ""
    property int slotIndex: 0
    property int slotCount: 1
    // Logical size of the screen the panorama is shown on.
    property real screenW: 1920
    property real screenH: 1080
    property bool tint: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled === true : false

    readonly property real kx: screenW > 0 ? width / screenW : 0
    readonly property real ky: screenH > 0 ? height / screenH : 0
    readonly property var geometry: PanoramaMath.layout(image.implicitWidth, image.implicitHeight, screenW, screenH)
    readonly property real frameX: PanoramaMath.slotX(slotIndex, slotCount, geometry.travel, screenW)

    clip: true

    Image {
        id: image
        visible: false
        source: root.sourceFile ? "file://" + root.sourceFile : ""
        // Rounded up to a 32 px step so slices of slightly different
        // heights still share one decode.
        sourceSize.width: PanoramaMath.MAX_TEXTURE
        sourceSize.height: Math.max(32, Math.ceil(root.height / 32) * 32)
        asynchronous: true
        smooth: true
        mipmap: true
    }

    PaletteTexture {
        id: palette
        active: root.tint
    }

    PanoramaLayer {
        source: image
        geometry: ({
                width: root.geometry.width * root.kx,
                height: root.geometry.height * root.ky,
                y: root.geometry.y * root.ky
            })
        x: -root.frameX * root.kx
        paletteTexture: root.tint ? palette.texture : image
        paletteSize: palette.size
        tintEnabled: root.tint ? 1 : 0
    }
}
