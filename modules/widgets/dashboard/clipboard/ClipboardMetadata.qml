import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView

// Metadata strip under the preview: MIME type, size, date, checksum, plus
// the Open and drag-out buttons.
Item {
    id: meta

    property var item: null
    property string content: ""

    signal openRequested(string itemId)

    Row {
        anchors.fill: parent
        spacing: 8

        Grid {
            // Always reserve space for the buttons when there is an item
            width: parent.width - (meta.item ? 36 + 8 : 0)
            height: parent.height
            columns: 2
            columnSpacing: 16
            rowSpacing: 4

            ClipboardMetadataField {
                width: (parent.width - parent.columnSpacing) / 2
                label: I18n.t("clipboard.mime_type")
                value: meta.item ? meta.item.mime : ""
                elideValue: true
            }

            ClipboardMetadataField {
                width: (parent.width - parent.columnSpacing) / 2
                label: I18n.t("clipboard.size")
                value: meta.item ? ClipboardView.formatSize(meta.item.size) : ""
            }

            ClipboardMetadataField {
                width: (parent.width - parent.columnSpacing) / 2
                label: I18n.t("clipboard.date")
                value: meta.item && meta.item.createdAt ? ClipboardView.fullDate(meta.item.createdAt, (key, n) => n === undefined ? I18n.t(key) : I18n.t(key, n)) : I18n.t("player.unknown")
            }

            ClipboardMetadataField {
                width: (parent.width - parent.columnSpacing) / 2
                label: I18n.t("clipboard.checksum")
                value: ClipboardView.shortHash(meta.item ? meta.item.hash : "")
                elideValue: true
                valueElide: Text.ElideMiddle
            }
        }

        ClipboardMetadataActions {
            width: 36
            height: parent.height
            visible: meta.item !== null
            item: meta.item
            content: meta.content
            onOpenRequested: itemId => meta.openRequested(itemId)
        }
    }
}
