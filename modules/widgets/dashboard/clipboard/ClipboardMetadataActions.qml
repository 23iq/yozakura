import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView
import "clipboard_utils.js" as ClipboardUtils

// Open button (files, images, URLs) and drag handle that drags the item out
// as a file URI or plain text.
Column {
    id: actions

    property var item: null
    property string content: ""

    signal openRequested(string itemId)

    spacing: 4

    StyledRect {
        width: height
        height: 36
        variant: metadataOpenButtonMouseArea.containsMouse ? "focus" : "common"
        color: metadataOpenButtonMouseArea.containsMouse ? Colors.surfaceBright : Colors.surface
        radius: Styling.radius(0)
        visible: !!actions.item && (actions.item.isFile || actions.item.isImage || ClipboardUtils.isUrl(actions.content))

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }

        MouseArea {
            id: metadataOpenButtonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (actions.item) {
                    actions.openRequested(actions.item.id);
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.popOpen
            font.family: Icons.font
            font.pixelSize: 20
            color: metadataOpenButtonMouseArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
            textFormat: Text.RichText

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.morph.easing
                }
            }
        }
    }

    StyledRect {
        id: dragButton
        width: height
        height: 36
        variant: metadataDragArea.containsMouse ? "focus" : "common"
        color: metadataDragArea.containsMouse ? Colors.surfaceBright : Colors.surface
        radius: Styling.radius(0)

        Behavior on color {
            enabled: Config.animDuration > 0
            ColorAnimation {
                duration: Config.animDuration / 2
                easing.type: Motion.morph.easing
            }
        }

        // Invisible drag source
        Item {
            id: dragTarget

            Drag.active: metadataDragArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: {
                ClipboardService.revision;
                const item = actions.item;
                const imagePath = item && item.isImage ? ClipboardService.getImagePath(item.id) : "";
                return ClipboardView.dragMimeData(item, actions.content.trim(), imagePath);
            }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.handGrab
            font.family: Icons.font
            font.pixelSize: 20
            color: metadataDragArea.containsMouse ? Styling.srItem("overprimary") : Colors.overBackground
            textFormat: Text.RichText

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.morph.easing
                }
            }
        }

        MouseArea {
            id: metadataDragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.OpenHandCursor
            drag.target: dragTarget
        }
    }
}
