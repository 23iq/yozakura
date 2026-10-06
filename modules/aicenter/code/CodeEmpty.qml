pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Code space without an open session: pick the agent; the first message
// from the composer starts a session in the project of the ProjectBar.
Item {
    id: root
    objectName: "codeEmpty"

    readonly property var agents: Ai.agents ? Ai.agents.agents : []

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * BarLook.pad, 520)
        spacing: BarLook.groupGap

        ColumnLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Icons.terminalWindow
                font.family: Icons.font
                font.pixelSize: BarLook.font(18)
                color: Colors.primary
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("ai.code_title")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(8)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: I18n.t("ai.agent_hint")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-1)
                color: Colors.outline
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: root.agents
                delegate: Chip {
                    id: chip
                    required property var modelData
                    glyph: chip.modelData.available ? Icons.robot : Icons.warning
                    label: chip.modelData.label + (chip.modelData.available ? "" : " · " + I18n.t("ai.not_installed"))
                    active: Ai.agentSettings.agent === chip.modelData.id
                    enabled: chip.modelData.available
                    opacity: enabled ? 1 : 0.55
                    onClicked: Ai.setModel("agent:" + chip.modelData.id)
                }
            }
            Text {
                visible: root.agents.length === 0
                text: BackendService.socketAvailable ? I18n.t("ai.agents_loading") : I18n.t("ai.backend_offline")
                font.family: Config.theme.font
                font.pixelSize: BarLook.font(-2)
                color: Colors.outline
            }
        }
    }
}
