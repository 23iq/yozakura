import QtQuick
import "PanoramaMath.js" as PanoramaMath

// The panorama image drawn at its geometry: as is (mode 0), with parallax
// depth layers (mode 1) or only its near layer (mode 2, desktop depth
// layering). The owner sets x from PanoramaPan and, for parallax, `lead`:
// how far (px) the near layer runs ahead of the image right now.
ShaderEffect {
    id: root

    // Texture providers (Image items): the image and its depth (grey map,
    // or a subject cut-out with alphaDepth).
    property var source: null
    property var depthMap: source
    property real alphaDepth: 0
    property var paletteTexture: source
    property real paletteSize: 0
    property real tintEnabled: 0

    property real mode: 0
    property real lead: 0
    readonly property real shift: width > 0 ? lead / width : 0
    readonly property real texel: width > 0 ? 1 / width : 0
    readonly property real texelY: height > 0 ? 1 / height : 0
    readonly property real midDepth: PanoramaMath.LAYER_DEPTHS[1]
    // A cut-out is a hard matte: its edge sits in the middle of the alpha.
    readonly property real nearDepth: alphaDepth > 0 ? 0.35 : PanoramaMath.LAYER_DEPTHS[2]
    readonly property real edge: alphaDepth > 0 ? 0.3 : PanoramaMath.LAYER_EDGE
    // Without a mid layer (cut-out) everything that is not near is far.
    readonly property real midLead: alphaDepth > 0 ? 0 : PanoramaMath.LAYER_LEAD[1] / PanoramaMath.LAYER_LEAD[2]

    // PanoramaMath.layout() of the image on this screen.
    property var geometry: ({
            width: 0,
            height: 0,
            y: 0
        })

    width: geometry.width
    height: geometry.height
    y: geometry.y
    visible: source !== null && width > 0

    fragmentShader: Qt.resolvedUrl("shaders/panorama_layer.frag.qsb")
}
