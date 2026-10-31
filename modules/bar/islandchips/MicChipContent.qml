import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The island's microphone state as a chip: the muted glyph while the
// default source is muted, plus the label of a just-made change (the mic
// notice, MicrophoneStatus.noticeVisible) on a horizontal chip. Used by the
// bar's mic module and the corner pills.
Item {
    id: root

    property bool vertical: false
    property real moduleSize: 32
    property real glyphSize: 16
    property int textSize: Type.size("body")
    property int textWeight: Font.Medium
    property string textFont: Type.bodyFont
    property color ink: Type.text
    // The notice is for this screen (MicrophoneStatus.noticeScreen)
    property bool notice: false

    readonly property bool muted: MicrophoneStatus.muted === true
    readonly property bool labelShown: root.notice && !root.vertical

    implicitWidth: root.vertical ? root.moduleSize : content.implicitWidth
    implicitHeight: root.moduleSize

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Space.xs

        Text {
            objectName: "micGlyph"
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? Icons.micSlash : Icons.mic
            font.family: Icons.font
            font.pixelSize: root.glyphSize
            // Muted is a warning state: the palette's error role
            color: root.muted ? Colors.error : root.ink
        }
        Text {
            objectName: "micLabel"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.labelShown
            text: I18n.t(root.muted ? "bar.mic.muted" : "bar.mic.live")
            textFormat: Text.PlainText
            font.family: root.textFont
            font.pixelSize: root.textSize
            font.weight: root.textWeight
            color: root.ink
        }
    }
}
