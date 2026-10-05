pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.bar as Bar
import qs.modules.bar.panels

// Shared body of the strip styles (menubar, statusline, ribbon, rail): one
// continuous band on the edge, flat modules, start / center / end groups,
// the drawer sliding out of the end group. The style files only tune it.
PanelStyleBase {
    id: strip

    readonly property var b: strip.barRoot
    readonly property int moduleSize: b ? b.moduleSize : BarMetrics.moduleSize

    // Space between the band's edges and the modules
    property int crossPadding: 2
    // Space before the first / after the last module along the band
    property int endPadding: 8
    property int spacing: 4
    // Divider between modules ("", "line", "dot", "slash")
    property string separator: ""
    // Tinted segment behind the start group (statusline)
    property bool accentStart: false
    // Hairline along the inner edge of the band (ribbon)
    property bool hairline: false
    // Band surface (panel options.surface): "bg" (the islands/notch
    // surface), "bar" (theme bar background) or "none"
    readonly property string surface: b && b.options && b.options.surface ? b.options.surface : "bg"

    readonly property real along: vertical ? height : width

    implicitThickness: moduleSize + 2 * crossPadding
    outerMargin: 0
    padding: crossPadding
    startReach: endPadding + (vertical ? startGroup.implicitHeight : startGroup.implicitWidth)
    endReach: endPadding + (vertical ? endGroup.implicitHeight : endGroup.implicitWidth)

    Bar.BarBg {
        anchors.fill: parent
        visible: strip.surface !== "none"
        variant: strip.surface === "bar" ? "barbg" : "bg"
        position: strip.edge
        effectiveContainBar: strip.b ? strip.b.contained : false
    }

    // Statusline: the start group sits on a tinted segment ending in a wedge
    Item {
        id: accent
        visible: strip.accentStart && strip.b !== null && strip.b.startIds.length > 0
        readonly property real length: strip.endPadding + (strip.vertical ? startGroup.height : startGroup.width) + strip.endPadding
        width: strip.vertical ? strip.width : length
        height: strip.vertical ? length : strip.height

        Rectangle {
            anchors.fill: parent
            color: Colors.primary
            opacity: 0.2
        }
        Rectangle {
            // The wedge: a rotated square cut by the band
            readonly property real side: (strip.vertical ? strip.width : strip.height) / Math.SQRT2
            width: side
            height: side
            rotation: 45
            color: Colors.primary
            opacity: 0.2
            x: strip.vertical ? (strip.width - width) / 2 : accent.width - width / 2
            y: strip.vertical ? accent.height - height / 2 : (strip.height - height) / 2
        }
        clip: false
    }

    Rectangle {
        visible: strip.hairline
        color: Colors.outlineVariant
        opacity: 0.8
        width: strip.vertical ? 1 : strip.width
        height: strip.vertical ? strip.height : 1
        x: strip.edge === "left" ? strip.width - 1 : 0
        y: strip.edge === "top" ? strip.height - 1 : 0
    }

    GridLayout {
        id: startGroup
        flow: strip.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: strip.spacing
        columnSpacing: strip.spacing
        x: strip.vertical ? strip.crossPadding : strip.endPadding
        y: strip.vertical ? strip.endPadding : strip.crossPadding
        width: strip.vertical ? strip.width - 2 * strip.crossPadding : implicitWidth
        height: strip.vertical ? implicitHeight : strip.height - 2 * strip.crossPadding

        Bar.BarModuleGroup {
            barRoot: strip.b
            ids: strip.b ? strip.b.startIds : []
            outerRadius: strip.b ? strip.b.outerRadius : 0
            innerRadius: strip.b ? strip.b.innerRadius : 0
            enableShadow: false
            separator: strip.separator
        }
    }

    PanelCenterGroup {
        barRoot: strip.b
        rowSpacing: strip.spacing
        columnSpacing: strip.spacing
        separator: strip.separator
        x: strip.vertical ? strip.crossPadding : Math.round((strip.width - width) / 2)
        y: strip.vertical ? Math.round((strip.height - height) / 2) : strip.crossPadding
        width: strip.vertical ? strip.width - 2 * strip.crossPadding : implicitWidth
        height: strip.vertical ? implicitHeight : strip.height - 2 * strip.crossPadding
    }

    // End group; the drawer slides out of its start edge
    GridLayout {
        id: endGroup
        flow: strip.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 0
        columnSpacing: 0
        x: strip.vertical ? strip.crossPadding : strip.width - strip.endPadding - width
        y: strip.vertical ? strip.height - strip.endPadding - height : strip.crossPadding
        width: strip.vertical ? strip.width - 2 * strip.crossPadding : implicitWidth
        height: strip.vertical ? implicitHeight : strip.height - 2 * strip.crossPadding

        HoverHandler {
            onHoveredChanged: if (strip.b)
                strip.b.drawerHovered = hovered
        }

        Bar.BarDrawer {
            id: drawer
            barRoot: strip.b
            ids: strip.b ? strip.b.drawerIds : []
            expanded: strip.b ? strip.b.drawerExpanded : false
            spacing: strip.spacing
            enableShadow: false
        }

        GridLayout {
            flow: strip.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: strip.spacing
            columnSpacing: strip.spacing
            Layout.fillWidth: strip.vertical
            Layout.fillHeight: !strip.vertical

            Bar.BarModuleGroup {
                barRoot: strip.b
                ids: strip.b ? strip.b.endIds : []
                outerRadius: strip.b ? strip.b.outerRadius : 0
                innerRadius: strip.b ? strip.b.innerRadius : 0
                enableShadow: false
                separator: strip.separator
            }
        }
    }
}
