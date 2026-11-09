import QtQuick
import qs.modules.theme
import qs.modules.components.kit
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
        spacing: Space.l

        Art {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Space.controlXL
            height: Space.controlXL
            icon: Icons.file
        }

        Column {
            width: preview.width - Space.l
            spacing: Space.s
            anchors.horizontalCenter: parent.horizontalCenter

            KitText {
                objectName: "fileName"
                width: parent.width
                role: "title"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: preview.item ? ClipboardView.uriFileName(preview.content) : ""
            }

            KitText {
                width: parent.width
                role: "caption"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideMiddle
                text: preview.item ? ClipboardView.uriDirectory(preview.content) : ""
            }
        }
    }
}
