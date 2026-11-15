import QtQuick
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.settings.live
import "../../bar/panels/PanelStyles.js" as PanelStyles
import "../live/LivePatch.js" as LivePatch

// Picture of a bar style (the Shape cards): your bar (its modules, icons,
// workspaces, clock: a few of its modules) drawn live by the shell's own
// panel in style `style` (live/LivePanel) on a narrow screen, so the whole
// silhouette fits. A style that cannot sit on the top edge is shown on its
// own first edge; "none" (no bar) is an outline where the bar would be.
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
        nativeWidth: root.shownEdge === "top" ? 520 : 160
        nativeHeight: root.shownEdge === "top" ? 140 : 420
        maxZoom: 1
        patch: Object.assign(LivePatch.style(root.style), LivePatch.sample(panel.base.groups), {
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
