pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.bar as Bar
import qs.modules.bar.panels

// "pills": every group is its own floating pill of bar surface, with gaps
// between them and to the screen edge; start and end pills sit at the ends,
// the center pill in the middle. The drawer opens inside the end pill.
PanelStyleBase {
    id: pills

    readonly property var b: pills.barRoot
    readonly property int pad: b ? b.islandPadding : 0
    readonly property real thickness: (b ? b.moduleSize : BarMetrics.moduleSize) + 2 * pad

    implicitThickness: thickness
    outerMargin: Metrics.spacing
    sideMargin: Metrics.spacing
    startReach: startPill.visible ? (vertical ? startPill.height : startPill.width) : 0
    endReach: endPill.visible ? (vertical ? endPill.height : endPill.width) : 0

    // Pinned to the screen edge across the panel (left/right/top/bottom)
    function crossPos(item) {
        return (pills.edge === "right" || pills.edge === "bottom") ? (vertical ? pills.width - item.width : pills.height - item.height) : 0;
    }

    BarPill {
        id: startPill
        vertical: pills.vertical
        thickness: pills.thickness
        pad: pills.pad
        hasContent: pills.b !== null && pills.b.startIds.length > 0
        x: pills.vertical ? pills.crossPos(startPill) : 0
        y: pills.vertical ? 0 : pills.crossPos(startPill)

        Bar.BarModuleGroup {
            barRoot: pills.b
            ids: pills.b ? pills.b.startIds : []
            outerRadius: pills.b ? pills.b.outerRadius : 0
            innerRadius: pills.b ? pills.b.innerRadius : 0
            enableShadow: false
        }
    }

    BarPill {
        id: centerPill
        vertical: pills.vertical
        thickness: pills.thickness
        pad: pills.pad
        hasContent: pills.b !== null && pills.b.centerIds.length > 0
        x: pills.vertical ? pills.crossPos(centerPill) : Math.round((pills.width - width) / 2)
        y: pills.vertical ? Math.round((pills.height - height) / 2) : pills.crossPos(centerPill)

        Bar.BarModuleGroup {
            barRoot: pills.b
            ids: pills.b ? pills.b.centerIds : []
            outerRadius: pills.b ? pills.b.outerRadius : 0
            innerRadius: pills.b ? pills.b.innerRadius : 0
            enableShadow: false
        }
    }

    BarPill {
        id: endPill
        vertical: pills.vertical
        thickness: pills.thickness
        pad: pills.pad
        hasContent: pills.b !== null && (pills.b.endIds.length > 0 || pills.b.drawerIds.length > 0)
        x: pills.vertical ? pills.crossPos(endPill) : pills.width - width
        y: pills.vertical ? pills.height - height : pills.crossPos(endPill)

        HoverHandler {
            onHoveredChanged: if (pills.b)
                pills.b.drawerHovered = hovered
        }

        Bar.BarDrawer {
            id: pillDrawer
            barRoot: pills.b
            ids: pills.b ? pills.b.drawerIds : []
            expanded: pills.b ? pills.b.drawerExpanded : false
            outerRadius: pills.b ? pills.b.outerRadius : 0
            innerRadius: pills.b ? pills.b.innerRadius : 0
            enableShadow: false
        }

        Bar.BarModuleGroup {
            barRoot: pills.b
            ids: pills.b ? pills.b.endIds : []
            outerRadius: pills.b ? pills.b.outerRadius : 0
            innerRadius: pills.b ? pills.b.innerRadius : 0
            startConnected: pillDrawer.open
            enableShadow: false
        }
    }
}
