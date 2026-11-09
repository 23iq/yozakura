pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components.kit
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
    radius: Look.radius("control")
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
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s
            StatusIcon {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Space.xs / 2
                status: root.task.status || ""
            }
            AiText {
                role: "body"
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                text: root.task.title || ""
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }

        AiText {
            role: "caption"
            Layout.fillWidth: true
            visible: root.waiting
            text: I18n.t(root.task.status === "awaiting_plan" ? "ai.tasks.waiting_plan" : "ai.tasks.waiting_permission")
            color: Colors.warning
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.s
            AgentIcons {
                agents: TaskModel.taskAgents(root.task)
            }
            StyledRect {
                visible: root.branchText.length > 0
                Layout.maximumWidth: Math.max(60, col.width * 0.45)
                implicitWidth: branchRow.implicitWidth + 2 * Space.xs
                implicitHeight: branchRow.implicitHeight + Space.xs
                radius: Look.radius("small")
                variant: "internalbg"
                RowLayout {
                    id: branchRow
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 10)
                    spacing: Space.xs
                    Icon {
                        role: "caption"
                        size: BarLook.size("caption")
                        tone: "muted"
                        icon: Icons.gitBranch
                    }
                    AiText {
                        role: "caption"
                        Layout.fillWidth: true
                        text: root.branchText
                        mono: true
                        elide: Text.ElideMiddle
                    }
                }
            }
            StyledRect {
                visible: !!root.task.inPlace
                implicitWidth: inPlace.implicitWidth + 2 * Space.xs
                implicitHeight: inPlace.implicitHeight + Space.xs
                radius: Look.radius("small")
                variant: "internalbg"
                AiText {
                    id: inPlace
                    role: "caption"
                    anchors.centerIn: parent
                    text: I18n.t("ai.tasks.in_place_badge")
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Icon {
                role: "caption"
                size: BarLook.size("caption")
                color: Colors[root.check === "pass" ? "success" : "error"] ?? Type.text
                visible: root.check.length > 0 && root.check !== "skipped"
                icon: root.check === "pass" ? Icons.checkCircle : (root.check === "timeout" ? Icons.hourglass : Icons.xCircle)
            }
            AiText {
                role: "caption"
                visible: root.attempts > 0
                text: "×" + root.attempts
            }
            AiText {
                role: "caption"
                visible: text.length > 0
                text: root.costText
                mono: true
            }
            AiText {
                role: "caption"
                visible: text.length > 0
                text: root.elapsedText
            }
        }
    }
}
