pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "TmuxModel.js" as TmuxModel

// Session list of the tmux tab: rows (TmuxSessionDelegate, kit ListRows
// that draw their own selection) and an overlay that closes the options / cancels a rename or delete when the
// click lands outside the active row.
ListView {
    id: resultsList

    required property var tab

    // Dragging or flicking: rows ignore hover meanwhile.
    property bool isScrolling: dragging || flicking
    property bool enableScrollAnimation: true

    readonly property bool editing: resultsList.tab.deleteMode || resultsList.tab.renameMode

    clip: true
    interactive: !resultsList.editing && resultsList.tab.expandedItemIndex === -1
    cacheBuffer: 96
    reuseItems: false
    currentIndex: resultsList.tab.selectedIndex

    Behavior on contentY {
        enabled: Config.animDuration > 0 && resultsList.enableScrollAnimation && !resultsList.moving
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    onCurrentIndexChanged: {
        if (resultsList.currentIndex !== resultsList.tab.selectedIndex) {
            resultsList.tab.selectedIndex = resultsList.currentIndex;
        }

        // Manual smooth auto-scroll (rows have variable heights)
        if (resultsList.currentIndex >= 0) {
            const expanded = resultsList.tab.expandedItemIndex;
            const itemY = TmuxModel.rowY(resultsList.currentIndex, expanded, resultsList.editing, resultsList.count);
            const currentItemHeight = TmuxModel.rowHeight(resultsList.currentIndex, expanded, resultsList.editing);
            const viewportTop = resultsList.contentY;
            const viewportBottom = viewportTop + resultsList.height;

            if (itemY < viewportTop) {
                resultsList.contentY = itemY;
            } else if (itemY + currentItemHeight > viewportBottom) {
                resultsList.contentY = itemY + currentItemHeight - resultsList.height;
            }
        }
    }

    // Scroll so that the expanded row at `index` is fully visible.
    function adjustScrollForExpandedItem(index) {
        if (index < 0 || index >= resultsList.count)
            return;

        // Every row before the expanded one is collapsed.
        const itemY = index * TmuxModel.ROW_HEIGHT;
        const itemBottom = itemY + TmuxModel.expandedRowHeight();
        const maxContentY = Math.max(0, resultsList.contentHeight - resultsList.height);
        const viewportTop = resultsList.contentY;
        const viewportBottom = viewportTop + resultsList.height;

        if (itemY < viewportTop) {
            resultsList.contentY = itemY;
        } else if (itemBottom > viewportBottom) {
            resultsList.contentY = Math.min(itemBottom - resultsList.height, maxContentY);
        }
    }

    delegate: TmuxSessionDelegate {
        tab: resultsList.tab
        list: resultsList
    }

    // Keep the expanded row visible once it has grown
    Connections {
        target: resultsList.tab
        function onExpandedItemIndexChanged() {
            if (resultsList.tab.expandedItemIndex >= 0)
                revealExpanded.restart();
        }
    }

    Timer {
        id: revealExpanded
        interval: Math.max(1, Config.animDuration)
        onTriggered: resultsList.adjustScrollForExpandedItem(resultsList.tab.expandedItemIndex)
    }

    MouseArea {
        id: outsideClick
        anchors.fill: parent
        enabled: resultsList.editing || resultsList.tab.expandedItemIndex >= 0
        z: 1000
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function isClickInsideActiveItem(mouseY) {
            const t = resultsList.tab;
            let activeIndex = -1;
            let isExpanded = false;

            if (t.deleteMode || t.renameMode) {
                // The edited row keeps the base height
                activeIndex = t.selectedIndex;
            } else if (t.expandedItemIndex >= 0) {
                activeIndex = t.expandedItemIndex;
                isExpanded = true;
            }

            if (activeIndex < 0)
                return false;

            // Only the active row can be expanded: every row before it is collapsed
            const itemY = activeIndex * TmuxModel.ROW_HEIGHT;
            const itemHeight = isExpanded ? TmuxModel.expandedRowHeight() : TmuxModel.ROW_HEIGHT;
            const clickY = mouseY + resultsList.contentY;
            return clickY >= itemY && clickY < itemY + itemHeight;
        }

        onClicked: mouse => {
            const t = resultsList.tab;
            if (t.deleteMode) {
                if (!outsideClick.isClickInsideActiveItem(mouse.y)) {
                    t.cancelDeleteMode();
                }
                mouse.accepted = true;
            } else if (t.renameMode) {
                if (!outsideClick.isClickInsideActiveItem(mouse.y)) {
                    t.cancelRenameMode();
                }
                mouse.accepted = true;
            } else if (t.expandedItemIndex >= 0) {
                if (!outsideClick.isClickInsideActiveItem(mouse.y)) {
                    t.expandedItemIndex = -1;
                    t.selectedOptionIndex = 0;
                    t.keyboardNavigation = false;
                    mouse.accepted = true;
                }
            }
        }

        onPressed: mouse => {
            mouse.accepted = !outsideClick.isClickInsideActiveItem(mouse.y);
        }

        onReleased: mouse => {
            mouse.accepted = !outsideClick.isClickInsideActiveItem(mouse.y);
        }
    }
}
