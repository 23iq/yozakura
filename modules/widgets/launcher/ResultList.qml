pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ResultStyles.js" as ResultStyles

// The launcher result list: results grouped under a SectionLabel per
// provider, each a ResultRow (kit ListRow, `cards` for the roomier look);
// one row at a time expands into its ResultActions. Selection and expansion
// are owned by LauncherSearch (keyboard first); the list reports hover/click.
ListView {
    id: list

    property var items: []
    property int selectedIndex: -1
    property int expandedIndex: -1
    property var expandedOptions: []
    property int optionIndex: 0
    property bool enableScrollAnimation: true
    property string emptyText: ""
    // "list" or "cards" (ResultStyles.effective picks; grid has its own view)
    property string style: "list"
    // Beside the detail pane (rows drop their Enter label).
    property bool narrow: false
    readonly property int rowHeight: ResultStyles.rowHeight(style, Metrics.rowHeight)
    readonly property int labelHeight: Type.size("label") + Space.l + Space.s
    readonly property var groups: ResultStyles.sections(items)
    readonly property int expandedExtra: expandedIndex >= 0 ? expandedOptions.length * Space.controlS + Space.s : 0
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

    function startsGroup(index) {
        return !!groups.starts[index];
    }

    // Top of row `index` itself (below its section label).
    function rowY(index) {
        let y = index * rowHeight + (groups.before[index] || 0) * labelHeight;
        if (expandedIndex >= 0 && index > expandedIndex)
            y += expandedExtra;
        return y;
    }

    function heightOf(index) {
        return (startsGroup(index) ? labelHeight : 0) + rowHeight + (index === expandedIndex ? expandedExtra : 0);
    }

    // Keeps the selected row (its label, its options) inside the viewport.
    function reveal(index) {
        if (index < 0)
            return;
        const top = rowY(index) - (startsGroup(index) ? labelHeight : 0);
        const bottom = rowY(index) + rowHeight + (index === expandedIndex ? expandedExtra : 0);
        if (top < contentY)
            contentY = top;
        else if (bottom > contentY + height)
            contentY = Math.min(bottom - height, Math.max(0, contentHeight - height));
    }

    onSelectedIndexChanged: reveal(selectedIndex)
    onExpandedIndexChanged: Qt.callLater(() => list.reveal(list.expandedIndex))

    Behavior on contentY {
        enabled: Motion.enter.duration > 0 && list.enableScrollAnimation && !list.moving
        NumberAnimation {
            duration: Motion.enter.duration / 2
            easing.type: Motion.enter.easing
        }
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool expanded: index === list.expandedIndex
        readonly property bool labelled: list.startsGroup(index)

        width: list.width
        height: list.heightOf(index)

        Behavior on height {
            enabled: Motion.enter.duration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }

        SectionLabel {
            objectName: "resultSection"
            visible: cell.labelled
            x: Space.s
            width: parent.width - Space.s * 2
            y: list.labelHeight - height - Space.s
            text: I18n.t("launcher.provider." + (cell.modelData.provider || ""))
        }

        ResultRow {
            id: row
            y: cell.labelled ? list.labelHeight : 0
            width: parent.width
            height: list.rowHeight - (list.style === "cards" ? Space.xs : 0)
            result: cell.modelData
            cards: list.style === "cards"
            narrow: list.narrow
            selected: list.selectedIndex === cell.index
            expanded: cell.expanded
        }

        MouseArea {
            anchors.fill: row
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

        ResultActions {
            objectName: "resultOptions"
            anchors.top: row.bottom
            anchors.topMargin: Space.xs
            // Option glyphs line up with the row's title.
            x: row.iconSize + Space.m
            width: parent.width - x
            visible: cell.expanded
            opacity: cell.expanded ? 1 : 0
            options: cell.expanded ? list.expandedOptions : []
            currentIndex: list.optionIndex
            showKeys: false
            onHovered: index => list.optionHovered(index)
            onTriggered: index => list.optionTriggered(index)
            Behavior on opacity {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }
        }
    }

    // Nothing matched
    Column {
        anchors.centerIn: parent
        spacing: Space.s
        visible: list.count === 0 && list.emptyText !== ""

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.magnifyingGlass
            font.family: Icons.font
            font.pixelSize: Type.iconSize("title")
            color: Type.muted
        }
        KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "secondary"
            text: list.emptyText
        }
    }
}
