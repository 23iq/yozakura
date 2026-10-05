import QtQuick
import QtQuick.Effects

// The selected user's picture: the synced ~/.face (only for the user it was
// synced from), else the SDDM user icon, else the theme glyph.
Item {
    id: avatar

    required property Item greeter
    property color ink: "white"
    // Corner radius as a share of the size (0.5 = circle).
    property real roundness: 0.5
    readonly property bool usesSynced: greeter.userName !== "" && greeter.userName === greeter.cfg("avatarUser", "")
    readonly property Image active: synced.status === Image.Ready ? synced : (model.status === Image.Ready ? model : null)

    implicitWidth: 28
    implicitHeight: 28

    Image {
        id: synced
        anchors.fill: parent
        source: avatar.usesSynced ? avatar.greeter.fileUrl(avatar.greeter.cfg("avatar", "")) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(192, 192)
        mipmap: true
        smooth: true
        visible: false
    }
    Image {
        id: model
        anchors.fill: parent
        source: synced.status !== Image.Ready && avatar.greeter.currentUser ? avatar.greeter.fileUrl(avatar.greeter.currentUser.uIcon) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(192, 192)
        mipmap: true
        smooth: true
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width * avatar.roundness
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: avatar.active !== null && !avatar.greeter.softwareRendering
        source: avatar.active
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        maskSource: mask
    }
    Image {
        anchors.fill: parent
        visible: avatar.active !== null && avatar.greeter.softwareRendering
        source: avatar.active ? avatar.active.source : ""
        fillMode: Image.PreserveAspectCrop
    }
    Rectangle {
        anchors.fill: parent
        radius: width * avatar.roundness
        visible: avatar.active === null
        color: Qt.rgba(avatar.ink.r, avatar.ink.g, avatar.ink.b, 0.12)

        // No picture: the theme glyph (plain user icon without effects).
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            visible: !avatar.greeter.softwareRendering
            source: "yozakura-icon.svg"
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectFit
            layer.enabled: visible
            layer.effect: MultiEffect {
                brightness: 1.0
                colorization: 1.0
                colorizationColor: avatar.ink
            }
        }
        Text {
            anchors.centerIn: parent
            visible: avatar.greeter.softwareRendering
            text: avatar.greeter.iconUser
            font.family: avatar.greeter.iconFont
            font.pixelSize: Math.round(parent.width * 0.5)
            color: avatar.ink
        }
    }
}
