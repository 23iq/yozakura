pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit

// Code space without an open session: pick the agent; the first message
// from the composer starts a session in the project of the ProjectBar.
Item {
    id: root
    objectName: "codeEmpty"

    readonly property var agents: Ai.agents ? Ai.agents.agents : []

    CenteredScroll {
        anchors.fill: parent
        maxContentWidth: 520
        spacing: BarLook.groupGap

        ColumnLayout {
            Layout.fillWidth: true
            spacing: BarLook.gap
            Icon {
                role: "title"
                tone: "secondary"
                Layout.alignment: Qt.AlignHCenter
                icon: Icons.terminalWindow
                size: BarLook.size("title")
            }
            AiText {
                role: "title"
                Layout.alignment: Qt.AlignHCenter
                text: I18n.t("ai.code_title")
                font.weight: Font.Bold
            }
            AiText {
                role: "secondary"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: I18n.t("ai.agent_hint")
                color: Type.muted
            }
            UsingModel {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Space.s
            Repeater {
                model: root.agents
                delegate: Chip {
                    id: chip
                    required property var modelData
                    icon: chip.modelData.available ? Icons.robot : Icons.warning
                    text: chip.modelData.label + (chip.modelData.available ? "" : " · " + I18n.t("ai.not_installed"))
                    active: Ai.agentSettings.agent === chip.modelData.id
                    enabled: chip.modelData.available
                    opacity: enabled ? 1 : 0.55
                    onClicked: Ai.setModel("agent:" + chip.modelData.id)
                }
            }
            AiText {
                role: "caption"
                visible: root.agents.length === 0
                text: BackendService.socketAvailable ? I18n.t("ai.agents_loading") : I18n.t("ai.backend_offline")
            }
        }
    }
}
