pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.services
import qs.modules.bar as Bar

// Gap slots: `gapStart` / `gapEnd` modules floating flat (no background) in
// the free spans between the end groups and the middle (center group or the
// notch when it shares the edge), each centered in its span. Empty by default.
Item {
    id: gaps

    required property var barRoot
    // Space taken from each end of the panel by the start/end groups
    property real startLimit: 0
    property real endLimit: 0
    // Length of the center group (0 when empty)
    property real centerLength: 0

    readonly property bool vertical: barRoot ? barRoot.orientation === "vertical" : false
    readonly property real length: vertical ? height : width
    readonly property Item notchItem: barRoot && !vertical && barRoot.notchPosition === barRoot.barPosition ? Visibilities.getNotchForScreen(barRoot.screen.name) : null
    readonly property real notchFillet: Config.roundness > 0 ? Config.roundness + 4 : 0
    readonly property real middleHalf: Math.max(centerLength / 2, notchItem ? notchItem.width / 2 + notchFillet : 0)
    readonly property real spacing: 12

    // [from, to] spans along the panel
    readonly property real startFrom: startLimit
    readonly property real startTo: length / 2 - middleHalf - spacing
    readonly property real endFrom: length / 2 + middleHalf + spacing
    readonly property real endTo: length - endLimit

    visible: barRoot !== null && (barRoot.gapStartIds.length > 0 || barRoot.gapEndIds.length > 0)

    Repeater {
        model: [
            {
                "group": "gapStart",
                "from": gaps.startFrom,
                "to": gaps.startTo
            },
            {
                "group": "gapEnd",
                "from": gaps.endFrom,
                "to": gaps.endTo
            }
        ]

        delegate: GridLayout {
            id: group
            required property var modelData
            readonly property var ids: gaps.barRoot ? (modelData.group === "gapStart" ? gaps.barRoot.gapStartIds : gaps.barRoot.gapEndIds) : []
            readonly property real span: Math.max(0, modelData.to - modelData.from)
            readonly property real natural: gaps.vertical ? implicitHeight : implicitWidth

            visible: ids.length > 0 && span >= natural
            flow: gaps.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 6
            columnSpacing: 6
            x: gaps.vertical ? Math.round((gaps.width - implicitWidth) / 2) : Math.round(modelData.from + (span - implicitWidth) / 2)
            y: gaps.vertical ? Math.round(modelData.from + (span - implicitHeight) / 2) : Math.round((gaps.height - implicitHeight) / 2)

            Bar.BarModuleGroup {
                barRoot: gaps.barRoot
                ids: group.ids
                outerRadius: gaps.barRoot ? gaps.barRoot.outerRadius : 0
                innerRadius: gaps.barRoot ? gaps.barRoot.innerRadius : 0
                enableShadow: false
                forceFlat: true
            }
        }
    }
}
