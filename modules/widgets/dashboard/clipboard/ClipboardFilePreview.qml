import QtQuick
import qs.modules.theme
import qs.config
import "ClipboardView.js" as ClipboardView

// Preview of a copied non-image file (text/uri-list): icon, file name and
// folder. Clicking opens it.
Item {
    id: preview

    property var item: null
    property string content: ""

    readonly property string filePath: preview.item ? ClipboardView.filePathFromUri(preview.content) : ""
    readonly property bool isImage: ClipboardView.isImagePath(preview.filePath)

    signal openRequested(string itemId)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (preview.item) {
                preview.openRequested(preview.item.id);
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 16

        Rectangle {
            width: 120
            height: 120
            color: Colors.surfaceBright
            radius: Styling.radius(4)
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: Icons.file
                textFormat: Text.RichText
                font.family: Icons.font
                font.pixelSize: 48
                color: Styling.srItem("overprimary")
            }
        }

        Column {
            width: preview.width - 16
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: preview.item ? ClipboardView.uriFileName(preview.content) : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize + 2
                font.weight: Font.Bold
                color: Colors.overBackground
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.Wrap
            }

            Text {
                text: preview.item ? ClipboardView.uriDirectory(preview.content) : ""
                font.family: Config.theme.font
                font.pixelSize: Config.theme.fontSize - 1
                color: Colors.outline
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideMiddle
            }
        }
    }
}
