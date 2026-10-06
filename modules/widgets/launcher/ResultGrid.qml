pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.config
import "ResultStyles.js" as ResultStyles

// App icon grid (layout.launcher.resultStyle = "grid"). Selection is owned by
// LauncherSearch; arrows reach it through move() (2D navigation), the grid
// reports hover/click like ResultList.
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

    highlight: Item {
        width: grid.cellWidth
        height: grid.cellHeight
        x: Math.max(0, grid.selectedIndex) % grid.columns * grid.cellWidth
        y: Math.floor(Math.max(0, grid.selectedIndex) / grid.columns) * grid.cellHeight
        visible: grid.selectedIndex >= 0 && grid.count > 0

        Behavior on x {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration / 2
                easing.type: Motion.enter.easing
            }
        }
        Behavior on y {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.enter.duration / 2
                easing.type: Motion.enter.easing
            }
        }

        StyledRect {
            anchors.fill: parent
            anchors.margins: Metrics.spacing / 4
            variant: "primary"
            radius: Styling.radius(4)
        }
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool selected: grid.selectedIndex === index

        width: grid.cellWidth
        height: grid.cellHeight

        ResultIcon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Metrics.spacing
            item: cell.modelData
            selected: cell.selected
            size: Math.round(Metrics.iconSize * 1.5)
        }

        Text {
            anchors.top: icon.bottom
            anchors.topMargin: Metrics.spacing / 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Metrics.spacing / 2
            anchors.rightMargin: Metrics.spacing / 2
            text: cell.modelData.title || ""
            horizontalAlignment: Text.AlignHCenter
            color: cell.selected ? Styling.srItem("primary") : Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: cell.selected ? Font.Bold : Font.Medium
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            Behavior on color {
                enabled: Motion.enter.duration > 0
                ColorAnimation {
                    duration: Motion.enter.duration / 2
                    easing.type: Motion.enter.easing
                }
            }
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
