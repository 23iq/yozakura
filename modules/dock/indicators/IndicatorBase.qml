pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.config
import "IndicatorRegistry.js" as Registry

// Contract of every dock indicator style: fills the app icon's cell and draws
// `count` marks (at most three) on the side facing the screen edge the dock
// sits on. A style only supplies `mark`, the Component of one mark; it reads
// `along` / `across` (the mark's length and thickness in the strip's
// direction) and `tint` from this base.
Item {
    id: root

    readonly property bool vertical: side === "left" || side === "right"
    property string side: "bottom"
    property int count: 0
    property bool active: false
    property real size: 4
    property real spacing: 3
    property Component mark: null

    readonly property var info: Registry.shown(count)
    readonly property real along: info.wide ? size * 2.5 : size
    readonly property real across: size
    readonly property real cell: vertical ? height : width
    readonly property color tint: active ? Styling.srItem("overprimary") : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.4)

    anchors.fill: parent

    Grid {
        id: strip
        columns: root.vertical ? 1 : 3
        spacing: root.spacing
        // Plain x/y (not conditional anchors): the side can change at runtime.
        x: root.side === "left" ? -2 : (root.side === "right" ? root.width - width + 2 : (root.width - width) / 2)
        y: root.side === "top" ? -2 : (root.side === "bottom" ? root.height - height + 2 : (root.height - height) / 2)

        Repeater {
            model: root.info.n
            delegate: root.mark
        }
    }
}
