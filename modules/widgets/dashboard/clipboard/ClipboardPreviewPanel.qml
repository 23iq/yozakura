import QtQuick
import qs.modules.theme
import qs.modules.components

// Right side of the clipboard tab: preview of the selected item (image, text
// / link, or file) above its metadata; a placeholder when nothing is selected.
Item {
    id: previewPanel

    required property ClipboardTabBase tab

    readonly property var currentItem: previewPanel.tab.selectedIndex >= 0 && previewPanel.tab.selectedIndex < previewPanel.tab.allItems.length ? previewPanel.tab.allItems[previewPanel.tab.selectedIndex] : null
    readonly property string content: previewPanel.tab.safeCurrentContent

    function open(itemId) {
        previewPanel.tab.openItem(itemId);
    }

    Item {
        anchors.fill: parent
        visible: previewPanel.currentItem

        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: separator.top
            anchors.bottomMargin: 8

            ClipboardImagePreview {
                anchors.fill: parent
                item: previewPanel.currentItem
                content: previewPanel.content
            }

            ClipboardTextPreview {
                anchors.fill: parent
                visible: previewPanel.currentItem && !previewPanel.currentItem.isImage && !previewPanel.currentItem.isFile
                item: previewPanel.currentItem
                content: previewPanel.content
                linkPreview: previewPanel.tab.linkPreviewData
                loadingLinkPreview: previewPanel.tab.loadingLinkPreview
                onOpenRequested: itemId => previewPanel.open(itemId)
            }

            // Non-image files (text/uri-list)
            ClipboardFilePreview {
                id: filePreview
                anchors.fill: parent
                visible: previewPanel.currentItem && previewPanel.currentItem.isFile && !filePreview.isImage
                item: previewPanel.currentItem
                content: previewPanel.content
                onOpenRequested: itemId => previewPanel.open(itemId)
            }
        }

        Separator {
            id: separator
            anchors.bottom: metadataSection.top
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            vert: false
        }

        ClipboardMetadata {
            id: metadataSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            item: previewPanel.currentItem
            content: previewPanel.content
            onOpenRequested: itemId => previewPanel.open(itemId)
        }
    }

    // Nothing selected
    Column {
        anchors.centerIn: parent
        spacing: 16
        visible: !previewPanel.currentItem

        Text {
            text: Icons.cactus
            font.family: Icons.font
            font.pixelSize: 48
            color: Colors.surfaceBright
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
        }
    }
}
