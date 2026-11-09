pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.components.kit

Item {
    id: root

    required property PwNode node
    property string icon: ""
    property bool isMainDevice: false

    implicitHeight: 56
    implicitWidth: parent?.width ?? 300

    PwObjectTracker {
        objects: [root.node]
    }

    readonly property bool isMuted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0
    property real lastSetVolume: volume

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        // First row: Icon + Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Mute button with icon
            Button {
                id: muteButton
                flat: true
                implicitWidth: 32
                implicitHeight: 32
                Layout.preferredWidth: 32
                Layout.maximumWidth: 32
                Layout.fillWidth: false

                background: StyledRect {
                    variant: muteButton.hovered ? "focus" : "common"
                    radius: Styling.radius(4)
                }

                contentItem: Item {
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.isMuted)
                                return Icons.speakerSlash;
                            if (root.icon)
                                return root.icon;
                            return Icons.speakerHigh;
                        }
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: root.isMuted ? Colors.error : Colors.overBackground

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                            }
                        }
                    }
                }

                onClicked: {
                    if (root.node?.audio) {
                        root.node.audio.muted = !root.node.audio.muted;
                    }
                }

                StyledToolTip {
                    visible: muteButton.hovered
                    tooltipText: root.isMuted ? "Unmute" : "Mute"
                }
            }

            // Volume slider
            LineSlider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.preferredHeight: Space.l
                wheelEnabled: false
                fillColor: {
                    if (root.isMuted)
                        return Type.muted;
                    if (Audio.protectionTriggered && root.isMainDevice)
                        return Colors.warning;
                    return Type.progress;
                }

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

        // Second row: Name + Separator + Percentage
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Source name
            Text {
                text: root.isMainDevice ? Audio.friendlyDeviceName(root.node) : Audio.appNodeDisplayName(root.node)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }

            // Separator line
            Divider {
                Layout.fillWidth: true
            }

            // Protection indicator
            Text {
                visible: Audio.protectionTriggered && root.isMainDevice
                text: Icons.shieldCheck
                font.family: Icons.font
                font.pixelSize: 12
                color: Colors.warning

                StyledToolTip {
                    visible: parent.visible && protectionIndicatorMa.containsMouse
                    tooltipText: I18n.t("controls.volume_protection")
                }

                MouseArea {
                    id: protectionIndicatorMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Percentage
            Text {
                text: `${Math.round(root.volume * 100)}%`
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
