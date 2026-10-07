pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "Downloads.js" as Downloads
import "../../services/activities/TransferModel.js" as Transfers

// The Downloads popup of DownloadsStack: downloads in progress (kit rows
// with a ProgressLine, fed by ActivityService transfers) over the latest
// files of the folder (rows that open the file), and a quiet "open folder"
// action. `opened()` after anything was opened.
Column {
    id: root

    property var files: []
    property var transfers: []
    property string folder: ""
    signal opened

    readonly property var active: Downloads.active(root.transfers)

    spacing: Look.groupGap

    Group {
        width: parent.width
        visible: root.active.length > 0
        label: I18n.t("bar.downloads.in_progress")

        Repeater {
            model: root.active

            Column {
                id: transfer
                required property var modelData
                readonly property real progress: Transfers.progress(transfer.modelData)

                width: parent.width
                spacing: Space.xs

                ListRow {
                    width: parent.width
                    title: transfer.modelData.title || ""
                    subtitle: Downloads.transferLine(Transfers.formatTransferSizes(transfer.modelData), Transfers.formatPercent(transfer.progress))
                    leading: FileIcon {
                        name: transfer.modelData.title || ""
                    }
                }

                ProgressLine {
                    x: Space.s
                    width: parent.width - Space.s * 2
                    value: Math.max(0, transfer.progress)
                }
            }
        }
    }

    Group {
        width: parent.width
        label: I18n.t("bar.downloads.recent")
        actionText: I18n.t("bar.downloads.open_folder")
        divider: root.active.length > 0
        onActionTriggered: {
            Qt.openUrlExternally("file://" + root.folder);
            root.opened();
        }

        KitText {
            width: parent.width
            visible: root.files.length === 0
            role: "caption"
            text: I18n.t("bar.downloads.empty")
        }

        Repeater {
            model: root.files

            ListRow {
                id: row
                required property var modelData

                width: parent.width
                title: row.modelData.name
                leading: FileIcon {
                    name: row.modelData.name
                    url: row.modelData.url
                }
                onClicked: {
                    Qt.openUrlExternally(row.modelData.url);
                    root.opened();
                }
            }
        }
    }

    // A file's thumbnail (images) or its type icon, at the row glyph size
    component FileIcon: Item {
        id: icon
        property string name: ""
        property string url: ""
        readonly property bool image: icon.url !== "" && Downloads.isImage(icon.name)

        implicitWidth: Space.controlS
        implicitHeight: Space.controlS

        Art {
            anchors.fill: parent
            visible: icon.image
            source: icon.image ? icon.url : ""
        }

        Image {
            anchors.fill: parent
            anchors.margins: Space.xs
            visible: !icon.image
            source: "image://icon/" + Downloads.iconFor(icon.name)
            sourceSize: Qt.size(width * 2, height * 2)
        }
    }
}
