import QtQuick
import Quickshell.Widgets
import qs.config
import qs.modules.theme

// Leading visual of an activity island, `size` x `size`:
//   "dot"   pulsing accent dot (recording)
//   "ring"  progress ring around the icon/app image (timers, jobs)
//   "glyph" the icon or app image alone (privacy)
Item {
    id: indicator

    property string kind: "glyph"
    property string icon: ""
    property string image: ""
    property real progress: -1
    property color accent: Colors.primary
    property real size: 18
    property bool animate: Config.animDuration > 0

    // Rings get a little more room so the glyph inside stays legible
    readonly property real box: kind === "ring" ? Math.round(size * 1.2) : size
    implicitWidth: box
    implicitHeight: box

    readonly property bool hasImage: image !== "" && appImage.status === Image.Ready
    readonly property real innerSize: kind === "ring" ? Math.round(box * 0.56) : size

    // Recording dot with a soft halo; breathes while animations are on
    Item {
        anchors.fill: parent
        visible: indicator.kind === "dot"

        Rectangle {
            anchors.centerIn: parent
            width: Math.round(indicator.size * 0.78)
            height: width
            radius: width / 2
            color: indicator.accent
            opacity: 0.22 * pulse.value
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(indicator.size * 0.44)
            height: width
            radius: width / 2
            color: indicator.accent
        }

        QtObject {
            id: pulse
            property real value: 1
        }
        SequentialAnimation {
            running: indicator.visible && indicator.kind === "dot" && indicator.animate
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                pulse.value = 1
            NumberAnimation {
                target: pulse
                property: "value"
                from: 1
                to: 0.15
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: pulse
                property: "value"
                from: 0.15
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    ActivityRing {
        anchors.fill: parent
        visible: indicator.kind === "ring"
        progress: indicator.progress
        color: indicator.accent
        lineWidth: Math.max(1.5, indicator.box / 10)
    }

    IconImage {
        id: appImage
        anchors.centerIn: parent
        implicitSize: indicator.innerSize
        source: indicator.kind !== "dot" ? indicator.image : ""
        visible: indicator.hasImage
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        visible: indicator.kind !== "dot" && !indicator.hasImage
        text: indicator.icon
        font.family: Icons.font
        font.pixelSize: indicator.kind === "ring" ? Math.round(indicator.box * 0.52) : indicator.size
        color: indicator.accent
    }
}
