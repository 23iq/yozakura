pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.bar as Bar
import qs.modules.bar.panels

// "dock": a floating container detached from the edge, sized to its
// content (align: center/start/end), groups packed in one row with a
// divider between non-empty groups. Pairs with the taskbar, downloads and
// workspacePreviews modules (dock.magnification / launchBounce).
PanelStyleBase {
    id: dock

    readonly property var b: dock.barRoot
    readonly property int moduleSize: b ? b.moduleSize : BarMetrics.moduleSize
    readonly property int pad: Math.round(moduleSize * 0.14)
    // Every group in one run, "__sep__" between non-empty groups
    readonly property var ids: {
        if (!b)
            return [];
        const groups = [b.startIds, b.centerIds, b.endIds].filter(g => g.length > 0);
        let out = [];
        for (let i = 0; i < groups.length; i++) {
            if (i > 0)
                out.push("__sep__");
            out = out.concat(groups[i]);
        }
        return out;
    }

    // Surface variant and own shadow ("dock-like" uses the bar surface)
    property string surface: "bg"
    property bool ownShadow: true

    implicitThickness: moduleSize + 2 * pad
    implicitLength: (vertical ? row.implicitHeight : row.implicitWidth) + 2 * pad
    outerMargin: Math.round(moduleSize * 0.16)
    sideMargin: 0

    StyledRect {
        anchors.fill: parent
        variant: dock.surface
        enableShadow: dock.ownShadow
        radius: Math.min(Styling.radius(10), dock.implicitThickness / 2)
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: dock.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4
        columnSpacing: 4
        width: dock.vertical ? dock.moduleSize : implicitWidth
        height: dock.vertical ? implicitHeight : dock.moduleSize

        Bar.BarModuleGroup {
            barRoot: dock.b
            ids: dock.ids
            // Non-flat modules (dock-like) draw their group pills
            outerRadius: dock.b ? dock.b.outerRadius : 0
            innerRadius: dock.b ? dock.b.innerRadius : 0
            enableShadow: false
            separatorStyle: "line"
        }
    }
}
