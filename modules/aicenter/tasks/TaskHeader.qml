pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "../../services/tasks/TaskModel.js" as TaskModel

// Header of the open task: back (compact), status, title, agents, branch,
// elapsed/cost, and the task actions (cancel, open folder, discard, delete).
ColumnLayout {
    id: root

    property var task: null
    property var run: null
    property bool showBack: false
    property real now: Date.now()
    signal backRequested
    signal discardRequested
    signal deleteRequested

    readonly property var info: TaskModel.statusInfo(root.task ? root.task.status : "")
    readonly property var acts: TaskModel.actions(root.task)

    spacing: Space.s

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.s
        IconButton {
            size: "xs"
            objectName: "taskBack"
            visible: root.showBack
            icon: Icons.caretLeft
            tooltip: I18n.t("ai.tasks.back") + " (Esc)"
            onClicked: root.backRequested()
        }
        StatusIcon {
            status: root.task ? root.task.status : ""
        }
        AiText {
            objectName: "taskTitle"
            role: "body"
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            text: root.task ? root.task.title : ""
            color: Colors.overBackground
        }
        IconButton {
            size: "xs"
            objectName: "taskCancel"
            visible: root.acts.cancel
            icon: Icons.stop
            tooltip: I18n.t("ai.tasks.cancel_task")
            onClicked: TasksService.cancel(root.task.id)
        }
        IconButton {
            size: "xs"
            visible: !!root.run && !!root.run.worktree && root.task.status !== "accepted" && root.task.status !== "discarded"
            icon: Icons.folderOpen
            tooltip: I18n.t("ai.tasks.open_folder")
            onClicked: Qt.openUrlExternally("file://" + root.run.worktree)
        }
        IconButton {
            size: "xs"
            objectName: "taskDiscard"
            visible: root.acts.discard
            danger: true
            icon: Icons.trash
            tooltip: I18n.t("ai.tasks.discard") + " (D)"
            onClicked: root.discardRequested()
        }
        IconButton {
            size: "xs"
            objectName: "taskDelete"
            visible: root.acts.remove
            danger: true
            icon: Icons.broom
            tooltip: I18n.t("ai.tasks.delete")
            onClicked: root.deleteRequested()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: root.showBack ? 36 : 0
        spacing: Space.s
        StyledRect {
            implicitWidth: statusText.implicitWidth + 2 * Space.s
            implicitHeight: statusText.implicitHeight + Space.xs
            radius: Look.radius("round", height)
            variant: "internalbg"
            border.width: 1
            border.color: Colors[root.info.color] !== undefined ? Colors[root.info.color] : Colors.outline
            AiText {
                id: statusText
                role: "caption"
                anchors.centerIn: parent
                text: I18n.t("ai.tasks.status." + (root.task ? root.task.status : "queued"))
                color: Colors[root.info.color] !== undefined ? Colors[root.info.color] : Colors.outline
            }
        }
        AgentIcons {
            agents: TaskModel.taskAgents(root.task)
        }
        AiText {
            role: "caption"
            visible: !!root.run
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            elide: Text.ElideRight
            text: root.run ? [TaskModel.agentLabel(root.run.agent, Ai.agents ? Ai.agents.agents : []), root.run.model, root.run.effort].filter(Boolean).join(" · ") : ""
        }
        Icon {
            role: "caption"
            size: BarLook.size("caption")
            tone: "muted"
            visible: branchLabel.text.length > 0
            icon: Icons.gitBranch
        }
        AiText {
            id: branchLabel
            role: "caption"
            Layout.fillWidth: true
            text: root.task && root.task.inPlace ? I18n.t("ai.tasks.in_place_badge") + " · " + (root.task.baseBranch || "") : (root.run ? root.run.branch || "" : "")
            mono: true
            elide: Text.ElideMiddle
        }
        AiText {
            role: "caption"
            text: [TaskModel.elapsed(root.task, root.now), Config.ai.tasks.showCosts ? TaskModel.cost(root.task) : ""].filter(Boolean).join(" · ")
        }
    }

    AiText {
        role: "caption"
        Layout.fillWidth: true
        visible: !!root.task && !!root.task.error
        text: root.task ? root.task.error || "" : ""
        color: Colors.error
        wrapMode: Text.Wrap
    }
}
