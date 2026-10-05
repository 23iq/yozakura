import QtQuick

// The wallpaper's subject, cut out of a matte-mode VideoWallpaper (colour
// with alpha from the stream's mask half). Drawn by the wallpaper above the
// depth clock, so the time sits between the video and its subject. Shares
// the video's offscreen texture: no extra decoding or copies.
ShaderEffect {
    id: root

    property VideoWallpaper video: null

    // Guarded: the binding may briefly see no video while the loader that
    // owns this item is being deactivated.
    property var source: video ? video.matteTexture : null
    property var paletteTexture: video ? video.paletteTexture : null
    property vector2d cropOffset: video ? video.cropOffset : Qt.vector2d(0, 0)
    property vector2d cropScale: video ? video.cropScale : Qt.vector2d(1, 1)
    property real contentFrac: video ? video.contentFrac : 1
    property real texelY: video && video.height > 0 ? 1 / (video.height * 2) : 0
    property real foreground: 1
    property real tint: video && video.tint ? 1 : 0
    property real paletteSize: video ? video.paletteSize : 0

    fragmentShader: "depth_matte.frag.qsb"
}
