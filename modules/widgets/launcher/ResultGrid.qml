pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import "../../components/kit/KitStates.js" as KitStates
import "ResultStyles.js" as ResultStyles

// App icon grid (layout.launcher.resultStyle = "grid"): icons with their
// names, the selected cell in the kit's selected look. Selection is owned by
// LauncherSearch; arrows reach it through nextIndex() (2D navigation), the
// grid reports hover/click like ResultList.
GridView {
    id: grid

    property var items: []
    property int selectedIndex: -1
    readonly property int baseCell: Metrics.iconSize * 3
    readonly property int columns: ResultStyles.columns(width, baseCell)
    readonly property bool isScrolling: dragging || flicking

    signal hoveredRow(int index)
    signal clickedRow(int index)
    signal rightClickedRow(int index)

    clip: true
    model: items
    currentIndex: selectedIndex
    cellWidth: Math.floor(width / columns)
    cellHeight: Math.round(Metrics.iconSize * 3.25)
    cacheBuffer: cellHeight * 2
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false

    // Index after an arrow key ("left" | "right" | "up" | "down").
    function nextIndex(dir) {
        return ResultStyles.gridMove(selectedIndex, dir, columns, items.length);
    }

    function reveal(index) {
        if (index >= 0)
            positionViewAtIndex(index, GridView.Contain);
    }

    onSelectedIndexChanged: reveal(selectedIndex)

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool selected: grid.selectedIndex === index

        width: grid.cellWidth
        height: grid.cellHeight

        // The cell box: the kit's selected look (KitStates "active").
        StyledRect {
            readonly property string look: KitStates.look(false, cell.selected, false)
            anchors.fill: parent
            anchors.margins: Space.xs
            variant: KitStates.variant(look, "transparent")
            backgroundOpacity: KitStates.opacity(look, false)
            enableBorder: false
            radius: Look.chipRadius(height)
        }

        ResultIcon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Space.m
            item: cell.modelData
            size: Math.round(Metrics.iconSize * 1.5)
        }

        KitText {
            anchors.top: icon.bottom
            anchors.topMargin: Space.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Space.s
            anchors.rightMargin: Space.s
            role: "secondary"
            color: cell.selected ? Type.text : Type.secondary
            text: cell.modelData.title || ""
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: !grid.isScrolling
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                if (!grid.isScrolling)
                    grid.hoveredRow(cell.index);
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    grid.rightClickedRow(cell.index);
                else
                    grid.clickedRow(cell.index);
            }
        }
    }
}
