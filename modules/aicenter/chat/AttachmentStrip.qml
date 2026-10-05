pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.aicenter.common

// Attachment thumbnails/chips under a user message or in the composer.
Flow {
    id: root

    property var attachments: []
    property bool removable: false

    signal removeRequested(int index)

    spacing: 6
    visible: attachments.length > 0

    function iconFor(a) {
        switch (a.kind) {
        case "selection":
            return Icons.cursorText;
        case "clipboard":
            return Icons.clipboardText;
        case "window":
            return Icons.appWindow;
        case "file":
            return Icons.fileText;
        default:
            return Icons.clip;
        }
    }

    Repeater {
        model: root.attachments

        delegate: Loader {
            id: entry
            required property var modelData
            required property int index
            sourceComponent: entry.modelData.type === "image" && entry.modelData.base64 ? imageC : chipC

            Component {
                id: imageC
                StyledRect {
                    variant: "common"
                    width: 64
                    height: 64
                    radius: Styling.radius(-6)
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        source: "data:" + entry.modelData.mimeType + ";base64," + entry.modelData.base64
                        asynchronous: true
                        sourceSize: Qt.size(128, 128)
                    }
                    IconButton {
                        visible: root.removable
                        anchors.top: parent.top
                        anchors.right: parent.right
                        size: 20
                        iconSize: 10
                        glyph: Icons.cancel
                        onClicked: root.removeRequested(entry.index)
                    }
                }
            }
            Component {
                id: chipC
                Chip {
                    glyph: root.iconFor(entry.modelData)
                    label: entry.modelData.name || entry.modelData.kind
                    closable: root.removable
                    maxLabelWidth: 160
                    onCloseClicked: root.removeRequested(entry.index)
                }
            }
        }
    }
}
