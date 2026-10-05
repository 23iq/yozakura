import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.theme

// The user's picture (~/.face.icon, then ~/.face) clipped to a rounded
// shape, or a user glyph when there is none.
Item {
    id: root

    property color ink: Colors.secondaryFixed
    // Corner radius as a share of the size (0.5 = circle).
    property real roundness: 0.5
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property bool hasPicture: avatar.status === Image.Ready

    implicitWidth: 28
    implicitHeight: 28

    Image {
        id: avatar
        anchors.fill: parent
        property int attempt: 0
        source: root.home === "" ? "" : (attempt === 0 ? "file://" + root.home + "/.face.icon" : "file://" + root.home + "/.face")
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        visible: false
        onStatusChanged: {
            if (status === Image.Error && attempt === 0)
                attempt = 1;
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: avatar
        visible: root.hasPicture
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        maskSource: ShaderEffectSource {
            hideSource: true
            sourceItem: Rectangle {
                width: root.width
                height: root.height
                radius: width * root.roundness
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width * root.roundness
        visible: !root.hasPicture
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)

        Text {
            anchors.centerIn: parent
            text: Icons.user
            font.family: Icons.font
            font.pixelSize: Math.round(root.width * 0.5)
            color: root.ink
        }
    }
}
