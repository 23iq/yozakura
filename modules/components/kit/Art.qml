import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.modules.components.kit

// A rounded-square image (album art, thumbnails, app art) with a quiet
// placeholder: an `icon` glyph or `placeholderText` (initials) while the
// image is empty or loading. Avatar is the circular variant.
Item {
    id: root

    property url source: ""
    property string icon: Icons.image
    property string placeholderText: ""
    property real radius: Space.clampRadius(Space.controlRadius, Math.min(width, height))
    property int fillMode: Image.PreserveAspectCrop
    readonly property bool ready: image.status === Image.Ready

    implicitWidth: Space.controlM
    implicitHeight: Space.controlM

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Type.placeholder
        visible: !root.ready

        KitText {
            anchors.centerIn: parent
            visible: root.placeholderText !== ""
            role: root.height >= 56 ? "title" : "secondary"
            color: Type.secondary
            text: root.placeholderText
        }

        Text {
            anchors.centerIn: parent
            visible: root.placeholderText === ""
            text: root.icon
            font.family: Icons.font
            font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.4)
            color: Type.muted
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        cache: true
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
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
        visible: root.ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
