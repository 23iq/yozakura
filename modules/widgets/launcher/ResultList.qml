pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// The launcher result list: rows of ResultRow, a sliding selection
// highlight, and one row at a time expanded into its ResultOptions.
// Selection and expansion are owned by LauncherSearch (keyboard first);
// the list reports hover/click.
ListView {
    id: list

    property var items: []
    property int selectedIndex: -1
    property int expandedIndex: -1
    property var expandedOptions: []
    property int optionIndex: 0
    property bool enableScrollAnimation: true
    property string emptyText: ""
    readonly property int rowHeight: 48
    readonly property int expandedExtra: expandedIndex >= 0 ? 4 + expandedOptions.length * 36 + 8 : 0
    readonly property bool isScrolling: dragging || flicking

    signal hoveredRow(int index)
    signal clickedRow(int index)
    signal rightClickedRow(int index)
    signal optionHovered(int index)
    signal optionTriggered(int index)

    clip: true
    model: items
    currentIndex: selectedIndex
    interactive: expandedIndex === -1
    cacheBuffer: 96
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false

    function rowY(index) {
        let y = index * rowHeight;
        if (expandedIndex >= 0 && index > expandedIndex)
            y += expandedExtra;
        return y;
    }

    function heightOf(index) {
        return rowHeight + (index === expandedIndex ? expandedExtra : 0);
    }

    // Keeps the selected row (and its options) inside the viewport.
    function reveal(index) {
        if (index < 0)
            return;
        const top = rowY(index);
        const bottom = top + heightOf(index);
        if (top < contentY)
            contentY = top;
        else if (bottom > contentY + height)
            contentY = Math.min(bottom - height, Math.max(0, contentHeight - height));
    }

    onSelectedIndexChanged: reveal(selectedIndex)
    onExpandedIndexChanged: Qt.callLater(() => list.reveal(list.expandedIndex))

    Behavior on contentY {
        enabled: Config.animDuration > 0 && list.enableScrollAnimation && !list.moving
        NumberAnimation {
            duration: Config.animDuration / 2
            easing.type: Easing.OutCubic
        }
    }

    highlight: Item {
        width: list.width
        height: list.heightOf(list.selectedIndex)
        y: list.rowY(Math.max(0, list.selectedIndex))
        visible: list.selectedIndex >= 0 && list.count > 0

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

        StyledRect {
            anchors.fill: parent
            variant: list.expandedIndex >= 0 && list.selectedIndex === list.expandedIndex ? "pane" : "primary"
            radius: Styling.radius(4)
        }
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool expanded: index === list.expandedIndex

        width: list.width
        height: list.heightOf(index)

        Behavior on height {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        ResultRow {
            id: resultRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: list.rowHeight
            item: cell.modelData
            selected: list.selectedIndex === cell.index
            expanded: cell.expanded
        }

        MouseArea {
            anchors.fill: resultRow
            hoverEnabled: !list.isScrolling
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: cell.modelData.inert ? Qt.ArrowCursor : Qt.PointingHandCursor
            onEntered: {
                if (!list.isScrolling && list.expandedIndex === -1)
                    list.hoveredRow(cell.index);
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    list.rightClickedRow(cell.index);
                else
                    list.clickedRow(cell.index);
            }
        }

        ResultOptions {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            visible: cell.expanded
            opacity: cell.expanded ? 1 : 0
            options: cell.expanded ? list.expandedOptions : []
            currentIndex: list.optionIndex
            onHovered: index => list.optionHovered(index)
            onTriggered: index => list.optionTriggered(index)
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutQuart
                }
            }
        }
    }

    // Nothing matched
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: list.count === 0 && list.emptyText !== ""
        opacity: 0.8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.magnifyingGlass
            font.family: Icons.font
            font.pixelSize: 26
            color: Colors.outline
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: list.emptyText
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.outline
        }
    }
}
