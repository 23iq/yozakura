pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components

// One floating pill of the "pills" style: the bar surface sized to the
// modules it holds (children go into its row/column). The theme shadow is
// cast by shell/PanelShadows like every bar surface.
StyledRect {
    id: pill

    property bool vertical: false
    // Cross-edge size (module size + padding on both sides)
    property real thickness: 0
    property int pad: 4
    property bool hasContent: true
    default property alias content: layout.data

    readonly property real bodyLength: (vertical ? layout.implicitHeight : layout.implicitWidth) + 2 * pad

    visible: hasContent
    variant: "barbg"
    enableShadow: false
    radius: Math.min(Styling.radius(pad), thickness / 2)
    implicitWidth: vertical ? thickness : bodyLength
    implicitHeight: vertical ? bodyLength : thickness
    width: implicitWidth
    height: implicitHeight

    GridLayout {
        id: layout
        anchors.centerIn: parent
        flow: pill.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4
        columnSpacing: 4
    }
}
