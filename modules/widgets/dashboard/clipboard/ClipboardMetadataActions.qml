import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ClipboardView.js" as ClipboardView
import "clipboard_utils.js" as ClipboardUtils

// Open button (files, images, URLs) and drag handle that drags the item out
// as a file URI or plain text.
Column {
    id: actions

    property var item: null
    property string content: ""

    signal openRequested(string itemId)

    spacing: Space.xs

    IconButton {
        objectName: "metadataOpen"
        size: "s"
        icon: Icons.popOpen
        visible: !!actions.item && (actions.item.isFile || actions.item.isImage || ClipboardUtils.isUrl(actions.content))
        onClicked: {
            if (actions.item)
                actions.openRequested(actions.item.id);
        }
    }

    IconButton {
        id: dragButton
        objectName: "metadataDrag"
        size: "s"
        icon: Icons.handGrab
        highlighted: dragArea.containsMouse

        // Invisible drag source
        Item {
            id: dragTarget

            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: {
                ClipboardService.revision;
                const item = actions.item;
                const imagePath = item && item.isImage ? ClipboardService.getImagePath(item.id) : "";
                return ClipboardView.dragMimeData(item, actions.content.trim(), imagePath);
            }
        }

        // Over the button: a drag, not a click
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.OpenHandCursor
            drag.target: dragTarget
        }
    }
}
