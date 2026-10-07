pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.components.kit
import "EmojiModel.js" as EmojiModel

// The emoji tab's list: the recent strip (row 0 while not searching) and
// one kit ListRow per emoji. Rows have their own selected look; the view
// scrolls the cursor row (with its tone options) into sight.
ListView {
    id: list

    required property var tab
    property bool enableScrollAnimation: true
    readonly property var geometry: ({
            row: Space.rowHeight,
            option: Space.controlS,
            // label, the strip of cells, label
            recent: Space.xl * 2 + Space.rowHeight,
            expanded: list.tab.expandedItemIndex
        })

    // [{recent, tones}] of the model, for the row geometry.
    function rows() {
        const r = [];
        for (let i = 0; i < list.tab.model.count; i++) {
            const it = list.tab.model.get(i);
            r.push({
                recent: it.isRecentContainer,
                tones: !it.isRecentContainer && !!it.emojiData.skin_tone_support
            });
        }
        return r;
    }

    function reveal(index) {
        if (index < 0)
            return;
        const r = list.rows();
        const y = EmojiModel.rowY(r, index, list.geometry);
        const to = EmojiModel.scrollToShow(y, EmojiModel.rowHeight(r, index, list.geometry), list.contentY, list.height);
        if (to !== -1)
            list.contentY = Math.max(0, Math.min(to, list.contentHeight - list.height));
    }

    function scrollToTop() {
        list.enableScrollAnimation = false;
        list.contentY = 0;
        Qt.callLater(() => list.enableScrollAnimation = true);
    }

    clip: true
    model: list.tab.model
    currentIndex: list.tab.selectedIndex
    highlightFollowsCurrentItem: false
    boundsBehavior: Flickable.StopAtBounds

    Behavior on contentY {
        enabled: Config.animDuration > 0 && list.enableScrollAnimation && !list.moving
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex !== list.tab.selectedIndex)
            list.tab.selectedIndex = currentIndex;
        if (currentIndex === -1 && count > 0)
            positionViewAtIndex(0, ListView.Beginning);
        list.reveal(currentIndex);
    }

    Connections {
        target: list.tab
        function onExpandedItemIndexChanged() {
            Qt.callLater(() => list.reveal(list.tab.expandedItemIndex));
        }
    }

    delegate: Loader {
        id: cell
        required property var emojiData
        required property bool isRecentContainer
        required property int index

        width: list.width
        sourceComponent: cell.isRecentContainer ? recentStrip : emojiRow

        Component {
            id: recentStrip
            EmojiRecentStrip {
                tab: list.tab
                rowIndex: cell.index
            }
        }

        Component {
            id: emojiRow
            EmojiRow {
                tab: list.tab
                entry: cell.emojiData
                index: cell.index
                rowHeight: list.geometry.row
                optionHeight: list.geometry.option
            }
        }
    }
}
