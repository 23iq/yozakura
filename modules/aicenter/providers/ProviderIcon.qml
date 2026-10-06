import QtQuick
import QtQuick.Effects
import qs.modules.theme

// A provider's logo (assets/aiproviders/<icon>, monochrome SVGs tinted
// with `color`) or a plug glyph for presets without one (Custom).
Item {
    id: root

    property string icon: ""
    property int size: 22
    property color color: Colors.overSurface

    implicitWidth: size
    implicitHeight: size

    Image {
        id: logo
        anchors.fill: parent
        visible: false
        source: root.icon ? Qt.resolvedUrl("../../../assets/aiproviders/" + root.icon) : ""
        sourceSize: Qt.size(root.size, root.size)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.icon.length > 0
        source: logo
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
    }
    Text {
        anchors.centerIn: parent
        visible: root.icon.length === 0
        text: Icons.plug
        font.family: Icons.font
        font.pixelSize: Math.round(root.size * 0.85)
        color: root.color
    }
}
