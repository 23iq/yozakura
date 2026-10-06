import QtQuick
import qs.modules.components
import qs.modules.theme
import qs.modules.shell.osd

// Level track shared by the OSD styles: a rounded groove with a fill that
// grows left to right, or bottom to top when vertical. Muted dims the fill.
Item {
    id: root

    property real value: 0
    property bool muted: false
    property bool vertical: false
    property int thickness: 4

    implicitWidth: root.vertical ? root.thickness : 100
    implicitHeight: root.vertical ? 100 : root.thickness

    StyledRect {
        anchors.fill: parent
        variant: "internalbg"
        enableBorder: false
        radius: Math.min(width, height) / 2
    }

    StyledRect {
        id: fill
        variant: root.muted ? "common" : "primary"
        enableBorder: false
        radius: Math.min(root.width, root.height) / 2
        opacity: root.muted ? 0.5 : 1
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.vertical ? parent.width : Math.max(root.thickness, parent.width * root.value)
        height: root.vertical ? Math.max(root.thickness, parent.height * root.value) : parent.height

        Behavior on width {
            enabled: !root.vertical
            NumberAnimation {
                duration: OsdMotion.enterMs
                easing.type: OsdMotion.enterEasing
            }
        }
        Behavior on height {
            enabled: root.vertical
            NumberAnimation {
                duration: OsdMotion.enterMs
                easing.type: OsdMotion.enterEasing
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: OsdMotion.enterMs
            }
        }
    }
}
