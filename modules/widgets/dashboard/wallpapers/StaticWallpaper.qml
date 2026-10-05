pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme

// A still (image) wallpaper, optionally tinted to the palette by a shader.
// Loaded into a WallpaperSlot by WallpaperImage.
Item {
    id: staticImageRoot
    width: parent.width
    height: parent.height
    property string sourceFile: ""
    property bool tint: false
    // Decode size (the screen), not the item size.
    property real sourceWidth: 0
    property real sourceHeight: 0
    // Decoded (or failed): safe to reveal via a transition.
    readonly property bool contentReady: rawImage.status === Image.Ready || rawImage.status === Image.Error

    // Subset of colors for optimization (approx 25 colors vs 98)
    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    // Palette generation for the shader
    Item {
        id: paletteSourceItem
        // Must be visible for ShaderEffectSource to capture it,
        // but we hide it visually by placing it behind or expecting ShaderEffectSource hideSource behavior.
        visible: true
        width: staticImageRoot.optimizedPalette.length
        height: 1
        opacity: 0 // Make invisible to eye but maintain presence for capture if needed (though hideSource usually handles this)

        Row {
            anchors.fill: parent
            Repeater {
                model: staticImageRoot.optimizedPalette
                Rectangle {
                    width: 1
                    height: 1
                    required property string modelData
                    color: Colors[modelData]
                }
            }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteSourceItem
        hideSource: true
        visible: false // The source object itself doesn't need to be visible in the scene graph
        smooth: false
        recursive: false
    }

    Image {
        id: rawImage
        mipmap: true
        anchors.fill: parent
        source: staticImageRoot.sourceFile ? "file://" + staticImageRoot.sourceFile : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize.width: staticImageRoot.sourceWidth
        sourceSize.height: staticImageRoot.sourceHeight
        layer.enabled: staticImageRoot.tint
        layer.effect: ShaderEffect {
            property var paletteTexture: paletteTextureSource
            property real paletteSize: staticImageRoot.optimizedPalette.length
            property real texWidth: rawImage.width
            property real texHeight: rawImage.height

            vertexShader: "palette.vert.qsb"
            fragmentShader: "palette.frag.qsb"
        }
    }
}
