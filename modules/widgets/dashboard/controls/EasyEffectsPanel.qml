pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// EasyEffects (settings Connect page), from the kit: the on / bypass
// switch with the open-app and refresh actions, the output and input
// presets as chips (the loaded one active), and what is loaded now.
Item {
    id: root

    // Polled only while shown (EasyEffectsService.setConsumer); the window
    // check covers a Settings window kept alive hidden between opens.
    readonly property string consumerKey: "easyeffects-panel-" + Date.now().toString(36) + Math.random().toString(36).slice(2)
    readonly property bool shown: root.visible && root.Window.window !== null && root.Window.window.visible
    onShownChanged: EasyEffectsService.setConsumer(root.consumerKey, root.shown)
    Component.onCompleted: {
        EasyEffectsService.initialize();
        EasyEffectsService.setConsumer(root.consumerKey, root.shown);
    }
    Component.onDestruction: EasyEffectsService.setConsumer(root.consumerKey, false)

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2
    readonly property bool available: EasyEffectsService.available
    readonly property bool hasPresets: EasyEffectsService.outputPresets.length > 0 || EasyEffectsService.inputPresets.length > 0

    // One line of the "active" section: a glyph and the loaded preset.
    component ActiveLine: Row {
        id: line

        property string icon: ""
        property string text: ""

        visible: line.text !== ""
        leftPadding: Look.rowInset
        spacing: Space.m

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            icon: line.icon
            role: "secondary"
            tone: "secondary"
        }

        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "secondary"
            text: line.text
        }
    }

    // A section of presets: its label over one chip per preset.
    component PresetSection: ColumnLayout {
        id: section

        property string label: ""
        property var presets: []
        property string activePreset: ""

        signal picked(string preset)

        visible: section.presets.length > 0
        spacing: Space.s

        SectionLabel {
            Layout.fillWidth: true
            text: section.label
        }

        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Look.rowInset
            Layout.rightMargin: Look.rowInset
            spacing: Space.s

            Repeater {
                model: section.presets

                Chip {
                    required property string modelData
                    objectName: "preset_" + modelData
                    active: section.activePreset === modelData
                    icon: active ? Icons.sparkle : ""
                    text: modelData
                    onClicked: section.picked(modelData)
                }
            }
        }
    }

    DeviceListHeader {
        id: header
        objectName: "effectsHeader"
        x: root.sideMargin
        width: root.contentWidth
        showSwitch: root.available
        checked: !EasyEffectsService.bypassed
        status: EasyEffectsService.bypassed ? I18n.t("effects.bypassed") : ""
        actions: root.available ? [
            {
                icon: Icons.popOpen,
                tooltip: I18n.t("effects.open"),
                onClicked: () => EasyEffectsService.openApp()
            },
            {
                icon: Icons.sync,
                tooltip: I18n.t("effects.refresh"),
                onClicked: () => EasyEffectsService.refresh()
            }
        ] : []
        onToggled: value => {
            if (value !== !EasyEffectsService.bypassed)
                EasyEffectsService.setBypass(!value);
        }
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
            spacing: Space.l

            KitText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Space.xxl
                visible: !root.available
                role: "caption"
                text: I18n.t("effects.not_installed")
            }

            PresetSection {
                Layout.fillWidth: true
                visible: root.available && presets.length > 0
                label: I18n.t("effects.output_presets")
                presets: EasyEffectsService.outputPresets
                activePreset: EasyEffectsService.activeOutputPreset
                onPicked: preset => EasyEffectsService.loadOutputPreset(preset)
            }

            PresetSection {
                Layout.fillWidth: true
                visible: root.available && presets.length > 0
                label: I18n.t("effects.input_presets")
                presets: EasyEffectsService.inputPresets
                activePreset: EasyEffectsService.activeInputPreset
                onPicked: preset => EasyEffectsService.loadInputPreset(preset)
            }

            KitText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Space.l
                visible: root.available && !root.hasPresets
                role: "caption"
                text: I18n.t("presets.no_presets")
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.available && (EasyEffectsService.activeOutputPreset || EasyEffectsService.activeInputPreset)
                spacing: Space.s

                SectionLabel {
                    Layout.fillWidth: true
                    text: I18n.t("common.active")
                }

                ActiveLine {
                    icon: Icons.speakerHigh
                    text: EasyEffectsService.activeOutputPreset
                }

                ActiveLine {
                    icon: Icons.mic
                    text: EasyEffectsService.activeInputPreset
                }
            }
        }
    }
}
