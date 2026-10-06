pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import "../../services/tasks/TaskModel.js" as TaskModel

// One task on the board: status, title, agents (several for best-of-N),
// branch badge, elapsed time, cost, check result and fix attempts. Tasks
// waiting for the user get an accent border and a one-line reason.
StyledRect {
    id: root

    property var task: ({})
    property real now: Date.now()
    property bool selected: false
    property bool current: false        // keyboard cursor
    signal opened

    readonly property var cfg: Config.ai.tasks
    readonly property var info: TaskModel.statusInfo(task.status)
    readonly property bool waiting: info.section === "waiting"
    readonly property string check: TaskModel.checkStatus(task)
    readonly property int attempts: TaskModel.attempts(task)
    readonly property string costText: cfg.showCosts ? TaskModel.cost(task) : ""
    readonly property string elapsedText: cfg.showElapsed ? TaskModel.elapsed(task, now) : ""
    readonly property string branchText: cfg.showBranch ? TaskModel.branch(task) : ""

    objectName: "taskCard_" + (task.id || "")
    implicitHeight: col.implicitHeight + 2 * BarLook.gap
    radius: Styling.radius(-2)
    variant: selected || hover.hovered ? "focus" : "common"
    border.width: waiting || current || selected ? 1 : 0
    border.color: waiting ? Colors.warning : Colors.primary

    Behavior on border.width {
        enabled: BarLook.animDuration > 0
        NumberAnimation {
            duration: BarLook.animDuration / 3
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.opened()
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: BarLook.gap
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StatusIcon {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                status: root.task.status || ""
            }
            UiText {
                Layout.fillWidth: true
                text: root.task.title || ""
                size: 0
                strong: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        UiText {
            Layout.fillWidth: true
            visible: root.waiting
            text: I18n.t(root.task.status === "awaiting_plan" ? "ai.tasks.waiting_plan" : "ai.tasks.waiting_permission")
            color: Colors.warning
            size: -2
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            AgentIcons {
                agents: TaskModel.taskAgents(root.task)
            }
            StyledRect {
                visible: root.branchText.length > 0
                Layout.maximumWidth: Math.max(60, col.width * 0.45)
                implicitWidth: branchRow.implicitWidth + 10
                implicitHeight: branchRow.implicitHeight + 4
                radius: Styling.radius(-6)
                variant: "internalbg"
                RowLayout {
                    id: branchRow
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 10)
                    spacing: 3
                    Glyph {
                        text: Icons.gitBranch
                        size: -4
                        role: "outline"
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: root.branchText
                        mono: true
                        muted: true
                        size: -4
                        elide: Text.ElideMiddle
                    }
                }
            }
            StyledRect {
                visible: !!root.task.inPlace
                implicitWidth: inPlace.implicitWidth + 10
                implicitHeight: inPlace.implicitHeight + 4
                radius: Styling.radius(-6)
                variant: "internalbg"
                UiText {
                    id: inPlace
                    anchors.centerIn: parent
                    text: I18n.t("ai.tasks.in_place_badge")
                    muted: true
                    size: -4
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Glyph {
                visible: root.check.length > 0 && root.check !== "skipped"
                text: root.check === "pass" ? Icons.checkCircle : (root.check === "timeout" ? Icons.hourglass : Icons.xCircle)
                role: root.check === "pass" ? "success" : "error"
                size: -2
            }
            UiText {
                visible: root.attempts > 0
                text: "×" + root.attempts
                muted: true
                size: -3
            }
            UiText {
                visible: text.length > 0
                text: root.costText
                muted: true
                mono: true
                size: -4
            }
            UiText {
                visible: text.length > 0
                text: root.elapsedText
                muted: true
                size: -3
            }
        }
    }
}
