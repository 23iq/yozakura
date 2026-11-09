import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
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
        spacing: Space.m

        ClipboardLinkEmbed {
            preview: preview.linkPreview
            url: preview.content
        }

        // Loading indicator for the link preview
        ClipboardCard {
            id: loadingCard
            objectName: "linkLoading"
            width: parent.width
            height: loadingRow.implicitHeight + Look.boxPadding * 2
            interactive: false
            visible: preview.loadingLinkPreview && preview.item && ClipboardUtils.isUrl(preview.content)

            Row {
                id: loadingRow
                anchors.centerIn: parent
                spacing: Space.m

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.spinnerGap
                    role: "title"
                    tone: "progress"

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: loadingCard.visible
                    }
                }

                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    text: I18n.t("clipboard.loading_preview")
                }
            }
        }

        // Plain URL card when there is no embed
        ClipboardUrlCard {
            id: urlCard
            width: parent.width
            visible: preview.item && ClipboardUtils.isUrl(preview.content) && !preview.loadingLinkPreview && (!preview.linkPreview || (!preview.linkPreview.title && !preview.linkPreview.description && !preview.linkPreview.image))
            clipItem: preview.item
            url: preview.content
            onOpenRequested: itemId => preview.openRequested(itemId)
        }

        KitText {
            id: previewText
            objectName: "previewText"
            width: parent.width
            role: "body"
            text: preview.content
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }

    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }
}
