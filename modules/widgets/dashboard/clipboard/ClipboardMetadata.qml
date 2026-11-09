import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
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
        spacing: Space.s

        Grid {
            // Always reserve space for the buttons when there is an item
            width: parent.width - (meta.item ? Space.controlS + Space.s : 0)
            height: parent.height
            columns: 2
            columnSpacing: Space.l
            rowSpacing: Space.xs

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
            width: Space.controlS
            height: parent.height
            visible: meta.item !== null
            item: meta.item
            content: meta.content
            onOpenRequested: itemId => meta.openRequested(itemId)
        }
    }
}
