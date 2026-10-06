pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.aicenter.transcript
import "../../services/tasks/TaskModel.js" as TaskModel

// The open task: header, run switcher (best-of-N), a "waiting for you"
// banner, and tabs: Plan (plan mode) | Review | Transcript (live agent
// session, permission cards inline) | Changes | Checks | Debug.
StyledRect {
    id: root
    objectName: "taskDetail"

    property var task: null
    property bool showBack: false
    property real now: Date.now()
    property string tab: "transcript"
    signal closeRequested

    readonly property int run: TasksService.selectedRun >= 0 && TaskModel.runAt(root.task, TasksService.selectedRun) ? TasksService.selectedRun : TaskModel.primaryRun(root.task)
    readonly property var current: TaskModel.runAt(root.task, root.run)
    readonly property bool hasPlan: !!root.task && (root.task.mode === "plan" || (root.task.plan || []).length > 0)
    readonly property bool hasReview: !!root.task && (root.task.status === "review" || TaskModel.reviewRuns(root.task).length > 0)
    readonly property var tabs: (root.hasPlan ? ["plan"] : []).concat(root.hasReview ? ["review"] : []).concat(["transcript", "changes", "checks", "debug"])
    readonly property bool permissionWaiting: !!root.current && (root.current.pending || []).length > 0

    function defaultTab() {
        const s = root.task ? root.task.status : "";
        if (s === "awaiting_plan" || s === "planning")
            return "plan";
        if (s === "review")
            return "review";
        return "transcript";
    }
    // Keyboard actions (TaskWorkspace): A, R, D.
    function accept() {
        if (root.task && root.task.status === "review") {
            root.tab = "review";
            Qt.callLater(() => review.accept());
        }
    }
    function requestChanges() {
        if (TaskModel.actions(root.task).followup) {
            root.tab = root.task.status === "awaiting_plan" ? "plan" : "review";
            Qt.callLater(() => root.tab === "review" ? review.requestChanges() : null);
        }
    }
    function discard() {
        if (!TaskModel.actions(root.task).discard)
            return;
        if (Config.ai.tasks.confirmDiscard)
            confirmDiscard.ask();
        else
            TasksService.discard(root.task.id, -1);
    }

    property string _tabFor: ""
    onTaskChanged: {
        const key = root.task ? root.task.id + ":" + root.task.status : "";
        if (key !== root._tabFor) {
            root._tabFor = key;
            root.tab = root.defaultTab();
        }
    }

    variant: "pane"
    radius: Styling.radius(-2)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: BarLook.pad
        spacing: BarLook.gap

        TaskHeader {
            Layout.fillWidth: true
            task: root.task
            run: root.current
            showBack: root.showBack
            now: root.now
            onBackRequested: root.closeRequested()
            onDiscardRequested: root.discard()
            onDeleteRequested: TasksService.remove(root.task.id)
        }

        ConfirmStrip {
            id: confirmDiscard
            objectName: "detailConfirmDiscard"
            Layout.fillWidth: true
            danger: true
            text: I18n.t("ai.tasks.confirm_discard")
            confirmLabel: I18n.t("ai.tasks.discard")
            onConfirmed: TasksService.discard(root.task.id, -1)
        }

        StyledRect {
            objectName: "waitingBanner"
            Layout.fillWidth: true
            visible: root.permissionWaiting
            implicitHeight: bannerRow.implicitHeight + 12
            radius: Styling.radius(-4)
            variant: "common"
            border.width: 1
            border.color: Colors.warning
            RowLayout {
                id: bannerRow
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8
                Glyph {
                    text: Icons.hand
                    role: "warning"
                }
                UiText {
                    Layout.fillWidth: true
                    text: I18n.t("ai.tasks.activity_waiting").replace("%1", root.current ? TaskModel.agentLabel(root.current.agent, Ai.agents ? Ai.agents.agents : []) : "")
                    size: -2
                    strong: true
                }
                Chip {
                    visible: root.tab !== "transcript"
                    label: I18n.t("ai.tasks.show_request")
                    onClicked: root.tab = "transcript"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: (root.task ? root.task.runs || [] : []).length > 1 ? root.task.runs : []
                delegate: Chip {
                    id: runChip
                    required property var modelData
                    required property int index
                    readonly property int runIndex: runChip.modelData.index !== undefined ? runChip.modelData.index : runChip.index
                    objectName: "runChip_" + runIndex
                    label: (runIndex + 1) + " · " + TaskModel.agentLabel(runChip.modelData.agent, Ai.agents ? Ai.agents.agents : [])
                    active: root.run === runIndex
                    onClicked: TasksService.selectedRun = runIndex
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Repeater {
                model: root.tabs
                delegate: Chip {
                    id: tabChip
                    required property string modelData
                    objectName: "tab_" + modelData
                    label: I18n.t("ai.tasks.tab." + tabChip.modelData)
                    variant: root.tab === tabChip.modelData ? "primary" : "transparent"
                    onClicked: root.tab = tabChip.modelData
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["plan", "review", "transcript", "changes", "checks", "debug"].indexOf(root.tab)

            PlanEditor {
                task: root.task
            }
            ReviewView {
                id: review
                task: root.task
                run: Math.max(0, root.run)
                onRunChosen: index => TasksService.selectedRun = index
            }
            Item {
                TranscriptView {
                    anchors.fill: parent
                    visible: !!root.current && !!root.current.sessionId
                    style: "detailed"
                    agentId: root.current ? root.current.sessionId || "" : ""
                    persistKey: root.current ? "task:" + root.task.id + ":" + root.run : ""
                    agentLabel: root.current ? TaskModel.agentLabel(root.current.agent, Ai.agents ? Ai.agents.agents : []) : ""
                }
                UiText {
                    anchors.centerIn: parent
                    visible: !root.current || !root.current.sessionId
                    text: I18n.t(root.task && root.task.status === "queued" ? "ai.tasks.queued_hint" : "ai.tasks.no_session")
                    muted: true
                }
            }
            TaskChanges {
                taskId: root.task ? root.task.id : ""
                run: Math.max(0, root.run)
                revision: root.task ? root.task.updatedAt || 0 : 0
            }
            ChecksView {
                run: root.current
                maxAttempts: TasksService.projects[root.task ? root.task.projectDir : ""] ? TasksService.projects[root.task.projectDir].maxAttempts : 0
            }
            DebugView {
                taskId: root.task ? root.task.id : ""
                run: Math.max(0, root.run)
            }
        }
    }
}
