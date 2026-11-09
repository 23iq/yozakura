pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// The audio mixer (settings Connect page), from the kit: the output /
// input switch with the protection and pavucontrol actions, the devices of
// that side (the default one selected), then the device volume and one
// volume per app stream, scrolling.
Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    // true = output, false = input
    property bool showOutput: true
    readonly property var appNodes: root.showOutput ? Audio.outputAppNodes : Audio.inputAppNodes

    DeviceListHeader {
        id: header
        objectName: "mixerHeader"
        x: root.sideMargin
        width: root.contentWidth
        showSwitch: false
        leading: Component {
            Segmented {
                objectName: "mixerSide"
                model: [
                    {
                        "name": "mixerOutput",
                        "icon": Icons.speakerHigh,
                        "text": I18n.t("mixer.output")
                    },
                    {
                        "name": "mixerInput",
                        "icon": Icons.mic,
                        "text": I18n.t("mixer.input")
                    }
                ]
                currentIndex: root.showOutput ? 0 : 1
                onActivated: index => root.showOutput = index === 0
            }
        }
        actions: [
            {
                icon: Audio.protectionEnabled ? Icons.shieldCheck : Icons.shield,
                tooltip: Audio.protectionEnabled ? I18n.t("mixer.protection_enabled") : I18n.t("mixer.protection_disabled"),
                onClicked: () => Audio.setProtectionEnabled(!Audio.protectionEnabled)
            },
            {
                icon: Icons.popOpen,
                tooltip: I18n.t("mixer.open_pavucontrol"),
                onClicked: () => Quickshell.execDetached(["pavucontrol"])
            }
        ]
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.topMargin: header.height + Space.s
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: root.sideMargin
            width: root.contentWidth
            spacing: Space.s

            SectionLabel {
                Layout.fillWidth: true
                text: root.showOutput ? I18n.t("mixer.output_device") : I18n.t("mixer.input_device")
            }

            Repeater {
                model: root.showOutput ? Audio.outputDevices : Audio.inputDevices

                delegate: AudioDeviceItem {
                    required property var modelData
                    Layout.fillWidth: true
                    node: modelData
                    isOutput: root.showOutput
                    isSelected: (root.showOutput ? Audio.sink : Audio.source) === modelData
                }
            }

            Divider {
                Layout.fillWidth: true
                Layout.topMargin: Space.s
                Layout.bottomMargin: Space.s
            }

            SectionLabel {
                Layout.fillWidth: true
                text: I18n.t("mixer.volume_mixer")
            }

            AudioVolumeEntry {
                Layout.fillWidth: true
                Layout.leftMargin: Look.rowInset
                Layout.rightMargin: Look.rowInset
                node: root.showOutput ? Audio.sink : Audio.source
                icon: root.showOutput ? Icons.speakerHigh : Icons.mic
                isMainDevice: true
            }

            Repeater {
                model: root.appNodes

                delegate: AudioVolumeEntry {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Look.rowInset
                    Layout.rightMargin: Look.rowInset
                    node: modelData
                }
            }

            KitText {
                objectName: "mixerNoApps"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Space.l
                visible: root.appNodes.length === 0
                role: "caption"
                text: I18n.t("mixer.no_apps")
            }
        }
    }
}
