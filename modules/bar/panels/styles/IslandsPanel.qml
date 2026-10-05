pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar
import qs.modules.bar.panels

// "islands": each group is its own notch-like tab hanging from the frame;
// no continuous strip behind them. Start and end tabs merge with the side
// frame in the screen corners; the center tab hangs free.
PanelStyleBase {
    id: islands

    readonly property var b: islands.barRoot
    // Corner tabs (CornersPanel) leave the middle of the edge free
    property bool showCenter: true

    implicitThickness: Math.max(startIsland.hasContent ? startIsland.bodyThickness : 0, endIsland.hasContent ? endIsland.bodyThickness : 0, centerIsland.hasContent ? centerIsland.bodyThickness : 0)
    // Islands hang directly from the frame/screen edge: no floating margin
    outerMargin: 0
    // Outer ends of the tab bodies along the bar (fillets excluded) and the
    // fillet size, for live activities sitting between the tabs and the notch
    startReach: startIsland.visible ? startIsland.width : 0
    endReach: endIsland.visible ? endIsland.width : 0
    fillet: startIsland.fillet

    Bar.BarIsland {
        id: startIsland
        barRoot: islands.b
        side: "start"
        padding: islands.b.islandPadding
        layoutItem: startLayout
        x: islands.vertical ? (islands.edge === "right" ? islands.width - width : 0) : 0
        y: islands.vertical ? 0 : (islands.edge === "bottom" ? islands.height - height : 0)

        GridLayout {
            id: startLayout
            // Natural size, pinned to the outer edge; the tab
            // body reveals it while animating
            width: islands.vertical ? parent.width : implicitWidth
            height: islands.vertical ? implicitHeight : parent.height
            flow: islands.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 4
            columnSpacing: 4

            Bar.BarModuleGroup {
                barRoot: islands.b
                ids: islands.b.startIds
                outerRadius: islands.b.outerRadius
                innerRadius: islands.b.innerRadius
                enableShadow: false
            }
        }
    }

    Bar.BarIsland {
        id: centerIsland
        barRoot: islands.b
        side: "center"
        flush: false
        padding: islands.b.islandPadding
        layoutItem: centerLayout
        x: islands.vertical ? (islands.edge === "right" ? islands.width - width : 0) : Math.round((islands.width - width) / 2)
        y: islands.vertical ? Math.round((islands.height - height) / 2) : (islands.edge === "bottom" ? islands.height - height : 0)

        GridLayout {
            id: centerLayout
            x: islands.vertical ? 0 : Math.round((parent.width - width) / 2)
            y: islands.vertical ? Math.round((parent.height - height) / 2) : 0
            width: islands.vertical ? parent.width : implicitWidth
            height: islands.vertical ? implicitHeight : parent.height
            flow: islands.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 4
            columnSpacing: 4

            Bar.BarModuleGroup {
                barRoot: islands.b
                ids: islands.showCenter ? islands.b.centerIds : []
                outerRadius: islands.b.outerRadius
                innerRadius: islands.b.innerRadius
                enableShadow: false
            }
        }
    }

    Bar.BarIsland {
        id: endIsland
        barRoot: islands.b
        side: "end"
        padding: islands.b.islandPadding
        layoutItem: endLayout
        animateSize: !islandDrawer.transitioning
        x: islands.vertical ? (islands.edge === "right" ? islands.width - width : 0) : islands.width - width
        y: islands.vertical ? islands.height - height : (islands.edge === "bottom" ? islands.height - height : 0)

        HoverHandler {
            onHoveredChanged: islands.b.drawerHovered = hovered
        }

        GridLayout {
            id: endLayout
            x: islands.vertical ? 0 : parent.width - width
            y: islands.vertical ? parent.height - height : 0
            width: islands.vertical ? parent.width : implicitWidth
            height: islands.vertical ? implicitHeight : parent.height
            flow: islands.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 0
            columnSpacing: 0

            Bar.BarDrawer {
                id: islandDrawer
                barRoot: islands.b
                ids: islands.b.drawerIds
                expanded: islands.b.drawerExpanded
                outerRadius: islands.b.outerRadius
                innerRadius: islands.b.innerRadius
                enableShadow: false
            }

            GridLayout {
                flow: islands.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rowSpacing: 4
                columnSpacing: 4
                Layout.fillWidth: islands.vertical
                Layout.fillHeight: !islands.vertical

                Bar.BarModuleGroup {
                    barRoot: islands.b
                    ids: islands.b.endIds
                    outerRadius: islands.b.outerRadius
                    innerRadius: islands.b.innerRadius
                    startConnected: islandDrawer.open
                    enableShadow: false
                }
            }
        }
    }

    // Modules floating (flat, no tab) between the tabs and the center/notch
    PanelGapSlots {
        anchors.fill: parent
        barRoot: islands.b
        startLimit: islands.startReach + islands.fillet + 8
        endLimit: islands.endReach + islands.fillet + 8
        centerLength: centerIsland.visible ? (islands.vertical ? centerIsland.height : centerIsland.width) + 2 * centerIsland.fillet : 0
    }
}
