pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.components.kit

// One volume of the mixer (the device, or an app stream): a mute icon
// button and the level slider, over a caption line with the name, the
// volume protection shield (main device, while it holds the level back)
// and the percentage.
ColumnLayout {
    id: root

    required property PwNode node
    property string icon: ""
    property bool isMainDevice: false

    readonly property bool isMuted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0
    readonly property bool protecting: Audio.protectionTriggered && root.isMainDevice

    spacing: Space.xs

    PwObjectTracker {
        objects: [root.node]
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.s

        IconButton {
            objectName: "muteButton"
            size: "s"
            icon: root.isMuted ? Icons.speakerSlash : (root.icon || Icons.speakerHigh)
            active: root.isMuted
            danger: root.isMuted
            tooltip: root.isMuted ? I18n.t("mixer.unmute") : I18n.t("mixer.mute")
            onClicked: {
                if (root.node?.audio)
                    root.node.audio.muted = !root.node.audio.muted;
            }
        }

        LineSlider {
            id: volumeSlider
            objectName: "volumeSlider"
            Layout.fillWidth: true
            Layout.preferredHeight: Space.l
            wheelEnabled: false
            fillColor: root.isMuted ? Type.muted : (root.protecting ? Colors.warning : Type.progress)

            onMoved: v => {
                if (root.node?.audio && Math.abs(v - root.volume) > 0.001)
                    Audio.setNodeVolume(root.node, v);
            }

            Binding {
                target: volumeSlider
                property: "value"
                value: root.volume
                when: !volumeSlider.pressed
            }

            Behavior on fillColor {
                enabled: Motion.micro.duration > 0
                ColorAnimation {
                    duration: Motion.micro.duration
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.s

        KitText {
            Layout.maximumWidth: root.width * 0.7
            role: "caption"
            color: Type.secondary
            text: root.isMainDevice ? Audio.friendlyDeviceName(root.node) : Audio.appNodeDisplayName(root.node)
        }

        // A hairline leader to the value (just room where dividers are off)
        Item {
            Layout.fillWidth: true
            implicitHeight: Space.hairline

            Divider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }
        }

        Icon {
            visible: root.protecting
            icon: Icons.shieldCheck
            role: "caption"
            color: Colors.warning

            StyledToolTip {
                visible: parent.visible && protectionMouse.containsMouse
                tooltipText: I18n.t("controls.volume_protection")
            }

            MouseArea {
                id: protectionMouse
                anchors.fill: parent
                hoverEnabled: true
            }
        }

        KitText {
            role: "caption"
            tabular: true
            color: Type.secondary
            text: `${Math.round(root.volume * 100)}%`
        }
    }
}
