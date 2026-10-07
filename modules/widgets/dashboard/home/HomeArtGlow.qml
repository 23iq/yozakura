import QtQuick
import QtQuick.Effects

// A soft tint behind the player: the album art, heavily blurred and faint,
// clipped to the block's rounded shape. Invisible without art.
Item {
    id: root

    property url source: ""
    property real radius: 0
    property real strength: 0.32

    visible: image.status === Image.Ready

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        visible: root.visible
        opacity: root.strength
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: 0.2
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
