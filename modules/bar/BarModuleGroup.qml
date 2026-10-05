pragma ComponentBehavior: Bound

import QtQuick
import "BarLayout.js" as BarLayout

// One group of bar modules. The root is a Repeater, so the modules become
// direct children of the enclosing RowLayout/ColumnLayout and keep the
// layout's spacing exactly as the old hand-written groups did.
Repeater {
    id: group

    required property var barRoot
    property var ids: []
    property real outerRadius: 0
    property real innerRadius: 0
    // A connected edge joins another pill run (integrated dock, drawer)
    property bool startConnected: false
    property bool endConnected: false
    property bool enableShadow: true
    property int forcedAlignment: 0
    // Gap slots: modules without their own background on any style
    property bool forceFlat: false
    // Strip styles: "line", "dot" or "slash" drawn between modules
    property string separator: ""
    // Look of "__sep__" entries (interleaved ones, or listed in `ids`)
    property string separatorStyle: separator !== "" ? separator : "line"

    model: separator !== "" ? BarLayout.withSeparators(ids) : ids

    delegate: BarModuleSlot {
        required property var modelData
        required property int index

        readonly property int moduleIndex: group.separator !== "" ? Math.floor(index / 2) : index
        readonly property var radii: BarLayout.edgeRadii(moduleIndex, group.ids.length, group.outerRadius, group.innerRadius, group.startConnected, group.endConnected)

        barRoot: group.barRoot
        moduleId: modelData
        startRadius: radii.start
        endRadius: radii.end
        enableShadow: group.enableShadow
        forcedAlignment: group.forcedAlignment
        forceFlat: group.forceFlat
        separatorStyle: group.separatorStyle
    }
}
