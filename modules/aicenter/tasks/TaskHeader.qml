pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
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

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconButton {
            objectName: "taskBack"
            visible: root.showBack
            glyph: Icons.caretLeft
            tooltip: I18n.t("ai.tasks.back") + " (Esc)"
            onClicked: root.backRequested()
        }
        StatusIcon {
            status: root.task ? root.task.status : ""
            size: 1
        }
        UiText {
            objectName: "taskTitle"
            Layout.fillWidth: true
            text: root.task ? root.task.title : ""
            size: 2
            strong: true
            color: Colors.overBackground
        }
        IconButton {
            objectName: "taskCancel"
            visible: root.acts.cancel
            glyph: Icons.stop
            tooltip: I18n.t("ai.tasks.cancel_task")
            onClicked: TasksService.cancel(root.task.id)
        }
        IconButton {
            visible: !!root.run && !!root.run.worktree && root.task.status !== "accepted" && root.task.status !== "discarded"
            glyph: Icons.folderOpen
            tooltip: I18n.t("ai.tasks.open_folder")
            onClicked: Qt.openUrlExternally("file://" + root.run.worktree)
        }
        IconButton {
            objectName: "taskDiscard"
            visible: root.acts.discard
            danger: true
            glyph: Icons.trash
            tooltip: I18n.t("ai.tasks.discard") + " (D)"
            onClicked: root.discardRequested()
        }
        IconButton {
            objectName: "taskDelete"
            visible: root.acts.remove
            danger: true
            glyph: Icons.broom
            tooltip: I18n.t("ai.tasks.delete")
            onClicked: root.deleteRequested()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: root.showBack ? 36 : 0
        spacing: 8
        StyledRect {
            implicitWidth: statusText.implicitWidth + 14
            implicitHeight: statusText.implicitHeight + 4
            radius: height / 2
            variant: "internalbg"
            border.width: 1
            border.color: Colors[root.info.color] !== undefined ? Colors[root.info.color] : Colors.outline
            UiText {
                id: statusText
                anchors.centerIn: parent
                text: I18n.t("ai.tasks.status." + (root.task ? root.task.status : "queued"))
                size: -3
                color: Colors[root.info.color] !== undefined ? Colors[root.info.color] : Colors.outline
            }
        }
        AgentIcons {
            agents: TaskModel.taskAgents(root.task)
        }
        UiText {
            visible: !!root.run
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            elide: Text.ElideRight
            text: root.run ? [TaskModel.agentLabel(root.run.agent, Ai.agents ? Ai.agents.agents : []), root.run.model, root.run.effort].filter(Boolean).join(" · ") : ""
            muted: true
            size: -3
        }
        Glyph {
            visible: branchLabel.text.length > 0
            text: Icons.gitBranch
            role: "outline"
            size: -3
        }
        UiText {
            id: branchLabel
            Layout.fillWidth: true
            text: root.task && root.task.inPlace ? I18n.t("ai.tasks.in_place_badge") + " · " + (root.task.baseBranch || "") : (root.run ? root.run.branch || "" : "")
            mono: true
            muted: true
            size: -4
            elide: Text.ElideMiddle
        }
        UiText {
            text: [TaskModel.elapsed(root.task, root.now), Config.ai.tasks.showCosts ? TaskModel.cost(root.task) : ""].filter(Boolean).join(" · ")
            muted: true
            size: -3
        }
    }

    UiText {
        Layout.fillWidth: true
        visible: !!root.task && !!root.task.error
        text: root.task ? root.task.error || "" : ""
        color: Colors.error
        wrapMode: Text.Wrap
        size: -2
    }
}
