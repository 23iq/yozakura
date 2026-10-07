import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView

// One history row. Left click copies, right click toggles the options menu,
// long press copies, swipe left asks to delete, vertical drag reorders
// (within the pinned / unpinned group).
Rectangle {
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
    property color textColor: {
        if (isInDeleteMode) {
            return Styling.srItem("error");
        } else if (isExpanded) {
            return Styling.srItem("pane");
        } else {
            return Colors.overSurface;
        }
    }
    property string displayText: ClipboardView.rowText(modelData, isInDeleteMode)

    // Neighbour in the same pin group, or null.
    function sameGroupNeighbour(offset) {
        const other = row.tab.allItems[row.index + offset];
        return other && other.pinned === row.modelData.pinned ? other : null;
    }

    width: row.view.width
    height: ClipboardView.rowHeight(modelData, index === row.tab.expandedItemIndex && !isInDeleteMode && !isInAliasMode)
    color: "transparent"
    radius: 16

    Behavior on y {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    Behavior on height {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: row.isExpanded ? 48 : parent.height
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
                if (Math.abs(deltaY) > 48 / 2) {
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

        // Delete confirmation, slides in from the right
        ClipboardConfirmActions {
            width: 68
            height: 32
            shown: row.isInDeleteMode
            highlightVariant: "overerror"
            buttonIndex: row.tab.deleteButtonIndex
            idleColor: Colors.overError
            activeColor: Colors.overErrorContainer
            onHovered: i => row.tab.deleteButtonIndex = i
            onCancelled: row.tab.cancelDeleteMode()
            onConfirmed: row.tab.confirmDeleteItem()
        }

        // Alias confirmation
        ClipboardConfirmActions {
            width: 76
            height: 36
            radius: 6
            shown: row.isInAliasMode
            highlightVariant: "oversecondary"
            buttonIndex: row.tab.aliasButtonIndex
            idleColor: Colors.overSecondary
            activeColor: Colors.overSecondaryContainer
            onHovered: i => row.tab.aliasButtonIndex = i
            onCancelled: row.tab.cancelAliasMode()
            onConfirmed: row.tab.confirmAliasItem()
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

    ClipboardItemOptions {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        tab: row.tab
        entry: row.modelData
        shown: row.isExpanded && !row.isInDeleteMode && !row.isInAliasMode
    }

    ClipboardItemRow {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        tab: row.tab
        entry: row.modelData
        isInDeleteMode: row.isInDeleteMode
        isInAliasMode: row.isInAliasMode
        isExpanded: row.isExpanded
        isSelected: row.isSelected
        displayText: row.displayText
        textColor: row.textColor
    }
}
