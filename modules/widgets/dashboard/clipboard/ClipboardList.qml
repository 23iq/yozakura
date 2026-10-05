pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import "ClipboardView.js" as ClipboardView

// History list of the clipboard tab: rows, the moving selection highlight,
// an overlay that closes delete mode / the options menu on outside clicks,
// and the empty state.
Item {
    id: list

    required property ClipboardTabBase tab
    required property ListModel model
    property alias view: resultsList

    // Whether a row is drawn expanded (options menu open).
    function isExpandedRow(i) {
        return i === list.tab.expandedItemIndex && !list.tab.deleteMode && !list.tab.aliasMode;
    }

    function rowY(index) {
        return ClipboardView.rowY(index, list.model.count, list.tab.expandedItemIndex, !list.tab.deleteMode && !list.tab.aliasMode, i => list.model.get(i).itemData);
    }

    ListView {
        id: resultsList
        anchors.fill: parent
        visible: ClipboardService.items.length > 0
        clip: true
        interactive: !list.tab.deleteMode && list.tab.expandedItemIndex === -1
        cacheBuffer: 96
        reuseItems: false
        boundsBehavior: Flickable.StopAtBounds

        // Moving (drag or flick)
        property bool isScrolling: dragging || flicking

        model: list.model
        currentIndex: list.tab.selectedIndex

        property bool enableScrollAnimation: true

        Behavior on contentY {
            enabled: Config.animDuration > 0 && resultsList.enableScrollAnimation && !resultsList.moving
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutCubic
            }
        }

        onCurrentIndexChanged: {
            if (currentIndex !== list.tab.selectedIndex) {
                list.tab.selectedIndex = currentIndex;
            }

            // Manual smooth auto-scroll (variable height rows)
            if (currentIndex >= 0) {
                const itemY = list.rowY(currentIndex);
                const expanded = list.isExpandedRow(currentIndex) && currentIndex < list.model.count;
                const height = ClipboardView.rowHeight(expanded ? list.model.get(currentIndex).itemData : null, expanded);
                const y = ClipboardView.scrollToShow(itemY, height, resultsList.contentY, resultsList.height);
                if (y !== -1)
                    resultsList.contentY = y;
            }
        }

        highlight: Item {
            width: resultsList.width
            height: {
                if (list.isExpandedRow(resultsList.currentIndex))
                    return ClipboardView.rowHeight(list.model.get(resultsList.currentIndex).itemData, true);
                return ClipboardView.ROW_HEIGHT;
            }

            // Y from the index, not from the delegate position
            y: list.rowY(resultsList.currentIndex)

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

            onHeightChanged: {
                if (list.tab.expandedItemIndex >= 0 && height > ClipboardView.ROW_HEIGHT) {
                    Qt.callLater(() => {
                        list.tab.adjustScrollForExpandedItem(list.tab.expandedItemIndex);
                    });
                }
            }

            StyledRect {
                anchors.fill: parent
                variant: {
                    if (list.tab.deleteMode) {
                        return "error";
                    } else if (list.tab.aliasMode) {
                        return "secondary";
                    } else if (list.tab.expandedItemIndex >= 0 && list.tab.selectedIndex === list.tab.expandedItemIndex) {
                        return "pane";
                    } else {
                        return "primary";
                    }
                }
                radius: Styling.radius(4)
                visible: list.tab.selectedIndex >= 0

                Behavior on color {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }
                }
            }
        }

        highlightFollowsCurrentItem: false

        delegate: ClipboardItemDelegate {
            tab: list.tab
            view: resultsList
            viewScrolling: resultsList.isScrolling
        }
    }

    // While deleting or with the options menu open, clicks outside the active
    // row cancel it; clicks inside go through to the row.
    MouseArea {
        anchors.fill: resultsList
        enabled: list.tab.deleteMode || list.tab.expandedItemIndex >= 0
        z: 1000
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function isClickInsideActiveItem(mouseY) {
            var activeIndex = -1;
            var isExpanded = false;

            if (list.tab.deleteMode || list.tab.aliasMode) {
                activeIndex = list.tab.selectedIndex;
            } else if (list.tab.expandedItemIndex >= 0) {
                activeIndex = list.tab.expandedItemIndex;
                isExpanded = true;
            }

            if (activeIndex < 0)
                return false;

            // Rows above are collapsed in these modes
            var itemY = activeIndex * ClipboardView.ROW_HEIGHT;
            var itemHeight = ClipboardView.rowHeight(isExpanded ? list.model.get(activeIndex).itemData : null, isExpanded);
            var clickY = mouseY + resultsList.contentY;
            return clickY >= itemY && clickY < itemY + itemHeight;
        }

        onClicked: mouse => {
            if (list.tab.deleteMode) {
                if (!isClickInsideActiveItem(mouse.y)) {
                    list.tab.cancelDeleteMode();
                }
                mouse.accepted = true;
            } else if (list.tab.expandedItemIndex >= 0) {
                if (!isClickInsideActiveItem(mouse.y)) {
                    list.tab.collapseOptions();
                    mouse.accepted = true;
                }
            }
        }

        onPressed: mouse => {
            mouse.accepted = !isClickInsideActiveItem(mouse.y);
        }

        onReleased: mouse => {
            mouse.accepted = !isClickInsideActiveItem(mouse.y);
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: ClipboardService.items.length === 0

        Text {
            text: Icons.clipboard
            font.family: Icons.font
            font.pixelSize: 48
            color: Colors.surfaceBright
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
        }

        Text {
            text: I18n.t("clipboard.no_history")
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            font.weight: Font.Bold
            color: Colors.overBackground
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: I18n.t("clipboard.copy_to_start")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.outline
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
