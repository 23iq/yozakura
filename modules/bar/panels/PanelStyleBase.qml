import QtQuick

// Contract between BarContent and a panel style (panels/styles/*.qml, listed
// in PanelStyles.js). The style fills the panel body BarContent places on the
// edge and lays out `barRoot.startIds/centerIds/endIds/drawerIds/gap*Ids`.
//
// barRoot (BarContent) also offers: orientation, barPosition, vertical-aware
// moduleSize, flat, options, outerRadius/innerRadius, shadowsEnabled,
// contained, drawerExpanded/drawerHovered, screen.
Item {
    // BarContent hosting the style (set when the style is loaded)
    property var barRoot: null

    readonly property bool vertical: barRoot ? barRoot.orientation === "vertical" : false
    readonly property string edge: barRoot ? barRoot.barPosition : "top"

    // Size across the edge the style needs (BarContent.panelThickness unless
    // the panel sets `thickness`)
    property real implicitThickness: 0
    // Length along the edge, for panels that do not fill it (align != fill)
    property real implicitLength: 0
    // Gap to the screen/frame edge, and to the screen ends along the edge
    property int outerMargin: 0
    property int sideMargin: outerMargin
    // Inner padding of a strip-like background (0 for tab styles)
    property int padding: 0
    // Extent of the content from each end of the edge (horizontal panels),
    // so live activities next to the notch stop before it
    property real startReach: 0
    property real endReach: 0
    // Fillet of tab-shaped styles, 0 for strips
    property real fillet: 0
}
