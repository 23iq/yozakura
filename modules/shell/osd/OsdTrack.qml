import QtQuick
import qs.modules.shell.osd
import qs.modules.components.kit

// The level line shared by the OSD styles, drawn like the kit's LineSlider
// track: a Space.stroke groove with an accent fill that grows left to right
// (bottom to top when vertical) and eases to each new level. Display only:
// the OSD window handles scroll and click over the whole OSD.
Item {
    id: root

    property real value: 0
    property bool vertical: false
    readonly property real fraction: Math.max(0, Math.min(1, root.value))

    implicitWidth: root.vertical ? Space.stroke : 120
    implicitHeight: root.vertical ? 120 : Space.stroke

    Rectangle {
        id: groove
        anchors.centerIn: parent
        width: root.vertical ? Space.stroke : parent.width
        height: root.vertical ? parent.height : Space.stroke
        radius: Space.stroke / 2
        color: Type.track

        Rectangle {
            x: 0
            y: root.vertical ? groove.height - height : 0
            width: root.vertical ? groove.width : groove.width * root.fraction
            height: root.vertical ? groove.height * root.fraction : groove.height
            radius: groove.radius
            color: Type.accent

            Behavior on width {
                enabled: !root.vertical && OsdMotion.enterMs > 0
                NumberAnimation {
                    duration: OsdMotion.enterMs
                    easing.type: OsdMotion.enterEasing
                }
            }
            Behavior on height {
                enabled: root.vertical && OsdMotion.enterMs > 0
                NumberAnimation {
                    duration: OsdMotion.enterMs
                    easing.type: OsdMotion.enterEasing
                }
            }
        }
    }
}
