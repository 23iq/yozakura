pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel

// Best-of-N: the runs of a task side by side (agent, changes, check,
// summary); clicking one makes it the run under review.
RowLayout {
    id: root
    objectName: "runChoice"

    property var task: null
    property int run: 0
    signal chosen(int index)

    spacing: BarLook.gap

    Repeater {
        model: root.task ? root.task.runs || [] : []
        delegate: StyledRect {
            id: card
            required property var modelData
            required property int index
            readonly property int runIndex: card.modelData.index !== undefined ? card.modelData.index : card.index
            readonly property var stats: TaskModel.changes(card.modelData)
            readonly property var check: TaskModel.lastCheck(card.modelData)
            objectName: "runCard_" + runIndex
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: cardCol.implicitHeight + 2 * Space.s
            radius: Look.radius("control")
            variant: root.run === card.runIndex ? "focus" : (hover.hovered ? "common" : "pane")
            border.width: root.run === card.runIndex ? 1 : 0
            border.color: Colors.primary
            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.chosen(card.runIndex)
            }
            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Space.s
                spacing: Space.xs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Space.s
                    AgentIcons {
                        agents: [card.modelData.agent]
                    }
                    AiText {
                        role: "caption"
                        font.weight: Font.DemiBold
                        color: Type.text
                        Layout.fillWidth: true
                        text: TaskModel.agentLabel(card.modelData.agent, Ai.agents ? Ai.agents.agents : [])
                    }
                    StatusIcon {
                        status: card.modelData.status || ""
                    }
                }
                RowLayout {
                    spacing: Space.s
                    AiText {
                        role: "caption"
                        text: I18n.t("ai.files_changed").replace("%1", card.stats.files)
                    }
                    AiText {
                        role: "caption"
                        text: "+" + card.stats.insertions
                        color: Colors.success
                        mono: true
                    }
                    AiText {
                        role: "caption"
                        text: "−" + card.stats.deletions
                        color: Colors.error
                        mono: true
                    }
                    Icon {
                        role: "caption"
                        size: BarLook.size("caption")
                        color: Colors[card.check && card.check.status === "pass" ? "success" : "error"] ?? Type.text
                        visible: card.check !== null
                        icon: card.check && card.check.status === "pass" ? Icons.checkCircle : Icons.xCircle
                    }
                }
                AiText {
                    role: "caption"
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.modelData.summary || card.modelData.error || ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                }
            }
        }
    }
}
