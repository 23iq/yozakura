pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar

// The `center` group of a strip style, laid out along the panel and sized to
// its content (the style centers it).
GridLayout {
    id: center

    required property var barRoot
    property bool active: true
    property bool enableShadow: false
    property var ids: barRoot ? barRoot.centerIds : []
    property string separator: ""

    readonly property bool vertical: barRoot ? barRoot.orientation === "vertical" : false

    visible: active && ids.length > 0
    flow: vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 4
    columnSpacing: 4
    width: vertical ? (parent ? parent.width : 0) : implicitWidth
    height: vertical ? implicitHeight : (parent ? parent.height : 0)

    Bar.BarModuleGroup {
        barRoot: center.barRoot
        ids: center.active ? center.ids : []
        outerRadius: center.barRoot ? center.barRoot.outerRadius : 0
        innerRadius: center.barRoot ? center.barRoot.innerRadius : 0
        enableShadow: center.enableShadow
        forcedAlignment: center.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        separator: center.separator
    }
}
