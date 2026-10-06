import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.config

// Base of the registry widgets that are shared between hosts (the dashboard
// bento grid, the desktop, the clock popup). A host never hands over its own
// state, only these inputs:
//   cellW, cellH  pixel size of one grid cell (BentoTile; the desktop sends
//                 its own size through `k` instead)
//   compact       true when the widget gets a single row or column
//   options       per-instance options (the desktop's generic options)
//   ink           text colour of the surface the widget sits on
//   active        on screen: poll and animate only then
//   preview       drawn in settings: no side effects
//   k             scale of the widget vs its default size (text grows)
//   framed        draw its own pane (hosts that already provide a surface,
//                 like the desktop, turn it off)
Item {
    id: root

    property real cellW: Metrics.bentoCell
    property real cellH: Metrics.bentoCell
    property bool compact: false
    property var options: ({})
    property bool framed: true
    property color ink: framed ? Styling.srItem("pane") : Colors.overBackground
    property bool active: true
    property bool preview: false
    property real k: 1

    readonly property color inkSoft: Qt.rgba(ink.r, ink.g, ink.b, 0.68)
    readonly property color inkFaint: Qt.rgba(ink.r, ink.g, ink.b, 0.14)
    // Padding inside the surface, scaled with the widget.
    readonly property real pad: Math.round(16 * k)
    readonly property string font: Config.theme.font

    // Font size: the theme size (offset like Styling.fontSize) a bit larger
    // than in panels, since widgets are read from further away, times k.
    function px(offset) {
        return Math.max(8, Math.round(Styling.fontSize(offset) * 1.2 * k));
    }

    StyledRect {
        anchors.fill: parent
        z: -1
        visible: root.framed
        variant: "pane"
        radius: Styling.radius(4)
    }
}
