import QtQuick

// The shader pass of a wallpaper transition: blends `fromItem` into `toItem`
// (mode 0 fade, 1 grow, 2 wipe, 3 dissolve). WallpaperImage only mounts it
// while a transition runs.
Item {
    id: layer

    property Item fromItem: null
    property Item toItem: null
    property real progress: 0
    property real mode: 0
    property point origin: Qt.point(0.5, 0.5)
    property real angle: 0
    property real seed: 0

    // Un-hides both slots synchronously (Loader teardown only deleteLater()s).
    function release() {
        fromTexture.sourceItem = null;
        toTexture.sourceItem = null;
    }

    ShaderEffectSource {
        id: fromTexture
        anchors.fill: parent
        sourceItem: layer.fromItem
        hideSource: true
        live: true
        visible: false
    }

    ShaderEffectSource {
        id: toTexture
        anchors.fill: parent
        sourceItem: layer.toItem
        hideSource: true
        live: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        property var fromSource: fromTexture
        property var toSource: toTexture
        property real progress: layer.progress
        property real mode: layer.mode
        property real aspect: height > 0 ? width / height : 1
        property point origin: layer.origin
        property real angle: layer.angle
        property real seed: layer.seed
        fragmentShader: "wallpaper_transition.frag.qsb"
    }
}
