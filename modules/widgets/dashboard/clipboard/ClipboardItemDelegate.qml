pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.config
import "ClipboardView.js" as ClipboardView

// One history row. Left click copies, right click toggles the options menu,
// long press copies, swipe left asks to delete, vertical drag reorders
// (within the pinned / unpinned group). The row is a kit ListRow (type glyph
// or favicon, text, relative time; the pin glyph and the Enter hint
// trailing); the options open below it.
Item {
    id: row

    required property string itemId
    required property var itemData
    required property int index
    required property ClipboardTabBase tab
    required property ListView view
    // The list is being dragged or flicked: hover must not change selection
    property bool viewScrolling: false

    property var modelData: itemData

    property bool isInDeleteMode: row.tab.deleteMode && modelData.id === row.tab.itemToDelete
    property bool isInAliasMode: row.tab.aliasMode && modelData.id === row.tab.itemToAlias
    property bool isSelected: row.tab.selectedIndex === index
    property bool isExpanded: index === row.tab.expandedItemIndex
    property bool isDraggingForReorder: false
    property string displayText: ClipboardView.rowText(modelData, isInDeleteMode)

    // Neighbour in the same pin group, or null.
    function sameGroupNeighbour(offset) {
        const other = row.tab.allItems[row.index + offset];
        return other && other.pinned === row.modelData.pinned ? other : null;
    }

    width: row.view.width
    height: ClipboardView.rowHeight(modelData, index === row.tab.expandedItemIndex && !isInDeleteMode && !isInAliasMode)

    Behavior on y {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Motion.morph.easing
        }
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    ListRow {
        id: listRow
        width: parent.width
        height: ClipboardView.ROW_HEIGHT
        title: row.displayText
        subtitle: ClipboardView.relativeTime(row.modelData.createdAt, new Date(), (key, n) => n === undefined ? I18n.t(key) : I18n.t(key, n))
        selected: row.isSelected && !row.isInDeleteMode && !row.isInAliasMode
        highlighted: row.isInDeleteMode || row.isInAliasMode
        titleEditor: row.isInAliasMode ? aliasEditor : null

        leading: Component {
            ClipboardItemIcon {
                tab: row.tab
                entry: row.modelData
                isInDeleteMode: row.isInDeleteMode
                isInAliasMode: row.isInAliasMode
            }
        }

        trailing: Component {
            Row {
                spacing: Space.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!row.modelData.pinned
                    text: Icons.pin
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("caption")
                    color: Type.muted
                }

                KeyHint {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isSelected && !row.isExpanded && !row.isInDeleteMode && !row.isInAliasMode
                    icon: Icons.arrowElbowDownLeft
                }

                // Room for the confirm pair drawn over the row
                Item {
                    width: deleteActions.width
                    height: 1
                    visible: row.isInDeleteMode || row.isInAliasMode
                }
            }
        }
    }

    Component {
        id: aliasEditor
        InlineEdit {
            text: row.tab.newAlias
            onTextChanged: row.tab.newAlias = text
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    row.tab.confirmAliasItem();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    row.tab.cancelAliasMode();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    row.tab.aliasButtonIndex = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    row.tab.aliasButtonIndex = 1;
                    event.accepted = true;
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: row.isExpanded ? ClipboardView.ROW_HEIGHT : parent.height
        hoverEnabled: !row.isDraggingForReorder && !row.viewScrolling
        enabled: !row.tab.deleteMode && !row.tab.aliasMode
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startX: 0
        property real startY: 0
        property bool isDragging: false
        property bool longPressTriggered: false
        property bool isVerticalDrag: false

        onEntered: {
            // Keep the selection while a menu is open, dragging or scrolling
            if (!row.tab.deleteMode && row.tab.expandedItemIndex === -1 && !row.isDraggingForReorder && !row.viewScrolling) {
                row.tab.selectedIndex = row.index;
                row.view.currentIndex = row.index;
            }
        }

        onClicked: mouse => {
            const tab = row.tab;
            if (mouse.button === Qt.LeftButton && !row.isInDeleteMode) {
                if (tab.deleteMode && row.modelData.id !== tab.itemToDelete) {
                    tab.cancelDeleteMode();
                    return;
                }

                if (!tab.deleteMode && !row.isExpanded) {
                    tab.copyToClipboard(row.modelData.id);
                    Visibilities.setActiveModule("");
                }
            } else if (mouse.button === Qt.RightButton) {
                if (tab.deleteMode) {
                    tab.cancelDeleteMode();
                    return;
                }

                // Toggle the options menu
                if (tab.expandedItemIndex === row.index) {
                    tab.collapseOptions();
                    tab.selectedIndex = row.index;
                    row.view.currentIndex = row.index;
                } else {
                    tab.expandedItemIndex = row.index;
                    tab.selectedIndex = row.index;
                    row.view.currentIndex = row.index;
                    tab.selectedOptionIndex = 0;
                    tab.keyboardNavigation = false;
                }
            }
        }

        onPressed: mouse => {
            startX = mouse.x;
            startY = mouse.y;
            isDragging = false;
            longPressTriggered = false;
            isVerticalDrag = false;

            if (mouse.button !== Qt.RightButton) {
                longPressTimer.start();
            }
        }

        onPositionChanged: mouse => {
            if (pressed && mouse.button !== Qt.RightButton) {
                let deltaX = mouse.x - startX;
                let deltaY = mouse.y - startY;
                let distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

                if (distance > 10) {
                    isDragging = true;
                    longPressTimer.stop();

                    // Horizontal drag deletes, vertical drag reorders
                    if (!isVerticalDrag && Math.abs(deltaX) > Math.abs(deltaY)) {
                        if (deltaX < -50 && Math.abs(deltaY) < 30) {
                            if (!longPressTriggered) {
                                row.tab.enterDeleteMode(row.modelData.id);
                                longPressTriggered = true;
                            }
                        }
                    } else if (Math.abs(deltaY) > Math.abs(deltaX)) {
                        isVerticalDrag = true;
                        row.isDraggingForReorder = true;
                        row.tab.anyItemDragging = true;
                    }
                }
            }
        }

        onReleased: mouse => {
            longPressTimer.stop();

            // Reorder on release after a vertical drag of more than half a row
            if (isVerticalDrag && row.isDraggingForReorder) {
                let deltaY = mouse.y - startY;
                if (Math.abs(deltaY) > ClipboardView.ROW_HEIGHT / 2) {
                    if (deltaY > 0 && row.index < row.tab.allItems.length - 1) {
                        if (row.sameGroupNeighbour(1)) {
                            row.tab.pendingItemIdToSelect = row.modelData.id;
                            ClipboardService.moveItemDown(row.modelData.id);
                        }
                    } else if (deltaY < 0 && row.index > 0) {
                        if (row.sameGroupNeighbour(-1)) {
                            row.tab.pendingItemIdToSelect = row.modelData.id;
                            ClipboardService.moveItemUp(row.modelData.id);
                        }
                    }
                }
            }

            isDragging = false;
            longPressTriggered = false;
            isVerticalDrag = false;
            row.isDraggingForReorder = false;
            row.tab.anyItemDragging = false;
        }

        Timer {
            id: longPressTimer
            interval: 800
            repeat: false
            onTriggered: {
                if (!mouseArea.isDragging) {
                    row.tab.copyToClipboard(row.modelData.id);
                    Visibilities.setActiveModule("");
                    mouseArea.longPressTriggered = true;
                }
            }
        }
    }

    // Over the row, outside the gesture area (disabled in these modes)
    Item {
        anchors.fill: listRow

        // Delete confirmation
        ClipboardConfirmActions {
            id: deleteActions
            shown: row.isInDeleteMode
            buttonIndex: row.tab.deleteButtonIndex
            onHovered: i => row.tab.deleteButtonIndex = i
            onCancelled: row.tab.cancelDeleteMode()
            onConfirmed: row.tab.confirmDeleteItem()
        }

        // Alias confirmation
        ClipboardConfirmActions {
            id: aliasActions
            shown: row.isInAliasMode
            buttonIndex: row.tab.aliasButtonIndex
            onHovered: i => row.tab.aliasButtonIndex = i
            onCancelled: row.tab.cancelAliasMode()
            onConfirmed: row.tab.confirmAliasItem()
        }
    }

    ClipboardItemOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: listRow.bottom
        anchors.topMargin: Space.xs
        tab: row.tab
        entry: row.modelData
        shown: row.isExpanded && !row.isInDeleteMode && !row.isInAliasMode
    }
}
