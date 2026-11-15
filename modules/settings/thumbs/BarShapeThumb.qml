import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.live
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../live/LivePatch.js" as LivePatch

// Picture of a bar style (the Shape cards): your bar (its modules, icons,
// workspaces, clock) drawn live by the shell's own panel in style `style`
// (live/LivePanel) on your screen's real size, framed on the screen's band
// along the bar's edge and cut to its two ends side by side (the gap to
// the edge, the radius, the islands / segments, the first and last
// modules), at the zoom where its smallest text is 10 px: the styles
// differ at a glance and the modules read. A style that cannot sit on the
// top edge is shown on its own first edge (a rail: its top and bottom);
// "none" (no bar) is an outline where the bar would be. Pictures, not live
// bars: a gallery holds no BarContent.
MiniScreen {
    id: root

    property string style: "classic"
    // (the edge the cards' caller has: the picture shows the top edge)
    property string edge: "top"
    readonly property bool hidden: PanelStyles.isHidden(root.style)
    readonly property string shownEdge: PanelStyles.supportsEdge(root.style, "top") ? "top" : PanelStyles.get(root.style).edges[0]

    LivePanel {
        id: panel
        anchors.fill: parent
        anchors.margins: Math.round(root.u * 4)
        visible: !root.hidden
        // your screen's real size: the gaps, radii and ends are the real
        // ones; the screen's band along the edge, its two ends side by
        // side at a size where the modules read
        nativeWidth: LiveTarget.width
        nativeHeight: LiveTarget.height
        frame: "edge"
        cut: "ends"
        readableGlyph: 10
        maxZoom: 1
        // a picture (taken again when the bar or the look changes)
        snapshot: true
        patch: Object.assign(LivePatch.style(root.style), {
            "edge": root.shownEdge
        })
    }

    DashedFrame {
        visible: root.hidden
        x: Math.round(root.u * 6)
        y: Math.round(root.u * 6)
        width: parent.width - x * 2
        height: Math.round(root.height * 0.22)
        radius: Space.smallRadius
        color: Qt.alpha(Colors.overBackground, 0.55)
    }
}
