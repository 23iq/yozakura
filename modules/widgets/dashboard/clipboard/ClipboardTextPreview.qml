import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import "clipboard_utils.js" as ClipboardUtils

// Scrollable preview of a text item: link embed / loading state / plain URL
// card for links, then the full text.
Flickable {
    id: preview

    // Selected item (or null), its full content, the link preview metadata
    // and whether it is still being fetched.
    property var item: null
    property string content: ""
    property var linkPreview: null
    property bool loadingLinkPreview: false

    signal openRequested(string itemId)

    clip: true
    contentWidth: width
    contentHeight: textPreviewColumn.height
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: textPreviewColumn
        width: parent.width
        spacing: 12

        ClipboardLinkEmbed {
            preview: preview.linkPreview
            url: preview.content
        }

        // Loading indicator for the link preview
        Rectangle {
            id: linkPreviewLoadingRect
            width: parent.width
            height: 60
            visible: preview.loadingLinkPreview && preview.item && ClipboardUtils.isUrl(preview.content)
            color: Colors.surface
            radius: Styling.radius(4)

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: Icons.spinnerGap
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Styling.srItem("overprimary")
                    textFormat: Text.RichText

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: linkPreviewLoadingRect.visible
                    }
                }

                Text {
                    text: I18n.t("clipboard.loading_preview")
                    font.family: Config.theme.font
                    font.pixelSize: Config.theme.fontSize
                    color: Colors.outline
                }
            }
        }

        // Plain URL card when there is no embed
        Item {
            width: parent.width
            height: urlCard.visible ? 60 : 0
            visible: preview.item && ClipboardUtils.isUrl(preview.content) && !preview.loadingLinkPreview && (!preview.linkPreview || (!preview.linkPreview.title && !preview.linkPreview.description && !preview.linkPreview.image))

            ClipboardUrlCard {
                id: urlCard
                anchors.centerIn: parent
                width: parent.width
                item: preview.item
                url: preview.content
                onOpenRequested: itemId => preview.openRequested(itemId)
            }
        }

        Text {
            id: previewText
            text: preview.content
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.overBackground
            wrapMode: Text.Wrap
            width: parent.width
            textFormat: Text.PlainText
        }
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
}
