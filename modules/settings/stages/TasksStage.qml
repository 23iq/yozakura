pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.store

// Stage of Code tasks: the task board as the options make it. Columns
// (queued, running, to review, done) or one list; as many tasks running at
// once as allowed (the rest wait); each card with its agent and, when
// shown, its branch (a worktree, or the current branch when tasks work in
// place), its time and its cost; a planned task waits for its plan to be
// approved; the task to review says how it will be accepted (one commit
// or a merge commit) and, with notifications on, a toast says it is ready.
// A click on the layout switch flips columns and list (one undo step).
Stage {
    id: stage

    readonly property real u: Math.max(Space.px(10), stage.height * 0.052)
    readonly property bool list: SettingsStore.get("ai.tasks.boardLayout") === "list"
    readonly property var agents: {
        const a = SettingsStore.get("ai.tasks.defaultAgents");
        return Array.isArray(a) && a.length > 0 ? a : ["claude"];
    }
    readonly property int parallel: Math.max(1, Number(SettingsStore.get("ai.tasks.maxParallel") ?? 2))
    readonly property bool planFirst: SettingsStore.get("ai.tasks.planFirst") === true
    readonly property bool inPlace: SettingsStore.get("ai.tasks.inPlace") === true
    readonly property bool notify: SettingsStore.get("ai.tasks.notifications") !== false
    readonly property bool squash: SettingsStore.get("ai.tasks.mergeMode") !== "merge"
    readonly property bool costs: SettingsStore.get("ai.tasks.showCosts") !== false
    readonly property bool elapsed: SettingsStore.get("ai.tasks.showElapsed") !== false
    readonly property bool branch: SettingsStore.get("ai.tasks.showBranch") !== false
    readonly property var agentIcon: ({
            "claude": "robot",
            "codex": "terminal",
            "opencode": "code"
        })
    // the tasks on the board: {title, column, agent, time, cost}
    readonly property var tasks: {
        const names = ["prefs.ai.tasks.stage.t1", "prefs.ai.tasks.stage.t2", "prefs.ai.tasks.stage.t3", "prefs.ai.tasks.stage.t4", "prefs.ai.tasks.stage.t5", "prefs.ai.tasks.stage.t6"];
        const out = [];
        const running = Math.min(stage.parallel, 3);
        let n = 0;
        const add = (column, time, cost) => {
            out.push({
                "title": I18n.t(names[n % names.length]),
                "column": column,
                "agent": stage.agents[n % stage.agents.length],
                "time": time,
                "cost": cost,
                "slug": "task/" + ["fix-login", "dark-mode", "flaky-test", "docs", "cache", "icons"][n % 6]
            });
            n++;
        };
        for (let i = 0; i < running; i++)
            add("running", (4 + i * 3) + "m", "$0.0" + (3 + i));
        add("queued", "", "");
        if (stage.parallel < 3)
            add("queued", "", "");
        add("review", "12m", "$0.21");
        add("done", "8m", "$0.09");
        return out;
    }
    readonly property var columns: [
        {
            "id": "queued",
            "label": "prefs.ai.tasks.stage.queued",
            "icon": "hourglass"
        },
        {
            "id": "running",
            "label": "prefs.ai.tasks.stage.running",
            "icon": "play"
        },
        {
            "id": "review",
            "label": "prefs.ai.tasks.stage.review",
            "icon": "eye"
        },
        {
            "id": "done",
            "label": "prefs.ai.tasks.stage.done",
            "icon": "checkCircle"
        }
    ]

    stageHeight: Space.px(300)

    // the board's window
    Mark {
        id: board
        objectName: "tasksBoard"
        anchors.fill: parent
        anchors.margins: Math.round(stage.u * 0.9)
        radius: Look.radius("surface", Math.min(height, stage.u * 6))
        color: Qt.alpha(Colors.surfaceContainer, 0.9)
        border.width: Space.hairline
        border.color: Qt.alpha(Colors.outlineVariant, 0.7)

        // header: the title and the layout switch
        Item {
            id: header
            x: Math.round(stage.u * 0.8)
            y: Math.round(stage.u * 0.6)
            width: board.width - x * 2
            height: Math.round(stage.u * 1.5)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(stage.u * 0.4)
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.kanban
                    size: Math.round(stage.u * 0.85)
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "title"
                    font.pixelSize: Math.round(stage.u * 0.75)
                    text: I18n.t("prefs.ai.tasks")
                }
                // how many work at once: - n +
                Mark {
                    id: parallelBox
                    objectName: "tasksParallel"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parallelRow.implicitWidth + stage.u * 0.4
                    height: Math.round(stage.u * 1.3)
                    radius: Look.radius("control", height)
                    color: Qt.alpha(Type.text, 0.06)
                    StageSpot {
                        keys: ["ai.tasks.maxParallel"]
                        cornerRadius: parallelBox.radius
                    }
                    Row {
                        id: parallelRow
                        anchors.centerIn: parent
                        spacing: Math.round(stage.u * 0.2)
                        Step {
                            objectName: "tasksParallelLess"
                            icon: Icons.minus
                            delta: -1
                        }
                        KitText {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "caption"
                            font.pixelSize: Math.round(stage.u * 0.55)
                            color: Type.text
                            text: I18n.t("prefs.ai.tasks.stage.at_once").replace("%1", stage.parallel)
                        }
                        Step {
                            objectName: "tasksParallelMore"
                            icon: Icons.plus
                            delta: 1
                        }
                    }
                }
            }

            // columns | list
            Mark {
                id: layoutSwitch
                objectName: "tasksLayoutSwitch"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: switchRow.implicitWidth + stage.u * 0.4
                height: Math.round(stage.u * 1.3)
                radius: Look.radius("control", height)
                color: Qt.alpha(Type.text, 0.06)
                Row {
                    id: switchRow
                    anchors.centerIn: parent
                    spacing: Math.round(stage.u * 0.15)
                    Repeater {
                        model: ["kanban", "list"]
                        delegate: Mark {
                            id: seg
                            required property string modelData
                            readonly property bool on: (seg.modelData === "list") === stage.list
                            width: Math.round(stage.u * 1.6)
                            height: Math.round(stage.u * 1.05)
                            radius: Look.radius("control", height)
                            color: seg.on ? Type.accent : "transparent"
                            Icon {
                                anchors.centerIn: parent
                                icon: Icons[seg.modelData] ?? ""
                                size: Math.round(stage.u * 0.65)
                                tone: seg.on ? "accentInk" : "secondary"
                            }
                        }
                    }
                }
                MouseArea {
                    objectName: "tasksLayoutFlip"
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsStore.transaction("prefs.undo.board_layout", () => SettingsStore.set("ai.tasks.boardLayout", stage.list ? "columns" : "list"))
                }
            }
            StageSpot {
                anchors.fill: layoutSwitch
                keys: ["ai.tasks.boardLayout"]
                cornerRadius: layoutSwitch.radius
            }
        }

        // columns
        Row {
            id: lanes
            visible: !stage.list
            x: header.x
            y: header.y + header.height + Math.round(stage.u * 0.5)
            width: header.width
            height: board.height - y - Math.round(stage.u * 0.7)
            spacing: Math.round(stage.u * 0.5)
            Repeater {
                model: stage.columns
                delegate: Mark {
                    id: lane
                    required property var modelData
                    width: (lanes.width - lanes.spacing * 3) / 4
                    height: lanes.height
                    radius: Look.radius("box", Math.min(height, stage.u * 4))
                    color: Qt.alpha(Type.text, 0.04)
                    Column {
                        x: Math.round(stage.u * 0.4)
                        y: Math.round(stage.u * 0.4)
                        width: lane.width - x * 2
                        spacing: Math.round(stage.u * 0.4)
                        Row {
                            spacing: Math.round(stage.u * 0.3)
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: Icons[lane.modelData.icon] ?? ""
                                size: Math.round(stage.u * 0.6)
                                tone: lane.modelData.id === "running" ? "accent" : "muted"
                            }
                            KitText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "caption"
                                font.pixelSize: Math.round(stage.u * 0.55)
                                font.weight: Font.Medium
                                text: I18n.t(lane.modelData.label)
                            }
                        }
                        Repeater {
                            model: stage.tasks.filter(t => t.column === lane.modelData.id)
                            delegate: TaskCard {
                                required property var modelData
                                width: lane.width - stage.u * 0.8
                                task: modelData
                            }
                        }
                    }
                }
            }
        }

        // one list
        Column {
            visible: stage.list
            x: header.x
            y: header.y + header.height + Math.round(stage.u * 0.5)
            width: header.width
            spacing: Math.round(stage.u * 0.35)
            Repeater {
                model: stage.list ? stage.tasks : []
                delegate: TaskCard {
                    required property var modelData
                    width: header.width
                    task: modelData
                    wide: true
                }
            }
        }
        StageSpot {
            x: lanes.x
            y: lanes.y
            width: lanes.width
            height: lanes.height
            keys: ["ai.tasks.showCosts", "ai.tasks.showBranch", "ai.tasks.showElapsed", "ai.tasks.maxParallel", "ai.tasks.defaultAgents", "ai.tasks.mergeMode", "ai.tasks.planFirst", "ai.tasks.inPlace", "ai.tasks.commitWithAi"]
        }

        // ready for review
        Mark {
            id: toast
            objectName: "tasksToast"
            visible: stage.notify
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(stage.u * 0.8)
            width: toastRow.implicitWidth + stage.u * 1.2
            height: Math.round(stage.u * 1.7)
            radius: Look.radius("box", height)
            color: Colors.surfaceContainerHighest
            border.width: Space.hairline
            border.color: Qt.alpha(Type.accent, 0.6)
            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: Math.round(stage.u * 0.35)
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Icons.bellRinging
                    size: Math.round(stage.u * 0.7)
                    tone: "accent"
                }
                KitText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    font.pixelSize: Math.round(stage.u * 0.55)
                    color: Type.text
                    text: I18n.t("prefs.ai.tasks.stage.ready")
                }
            }
        }
        StageSpot {
            anchors.fill: toast
            visible: stage.notify
            keys: ["ai.tasks.notifications", "ai.tasks.notifyEvents"]
            cornerRadius: toast.radius
        }
    }

    // One task: its title, its agent, its state line.
    component TaskCard: Mark {
        id: card
        property var task: ({})
        property bool wide: false
        readonly property bool planned: stage.planFirst && card.task.column === "running" && card.task.slug === (stage.tasks[0] || {}).slug
        height: card.wide ? Math.round(stage.u * 1.6) : cardColumn.implicitHeight + Math.round(stage.u * 0.7)
        radius: Look.radius("box", Math.min(height, stage.u * 2))
        color: card.task.column === "running" ? Qt.alpha(Type.accent, 0.12) : Qt.alpha(Colors.surfaceContainerHighest, 0.9)
        border.width: Space.hairline
        border.color: card.task.column === "running" ? Qt.alpha(Type.accent, 0.45) : Type.hairline

        Column {
            id: cardColumn
            visible: !card.wide
            x: Math.round(stage.u * 0.4)
            y: Math.round(stage.u * 0.35)
            width: card.width - x * 2
            spacing: Math.round(stage.u * 0.25)
            KitText {
                width: parent.width
                role: "caption"
                font.pixelSize: Math.round(stage.u * 0.52)
                color: Type.text
                elide: Text.ElideRight
                text: card.task.title || ""
            }
            Meta {
                width: parent.width
                task: card.task
                planned: card.planned
            }
        }
        Row {
            visible: card.wide
            x: Math.round(stage.u * 0.5)
            anchors.verticalCenter: parent.verticalCenter
            width: card.width - x * 2
            spacing: Math.round(stage.u * 0.6)
            KitText {
                width: card.width * 0.32
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                font.pixelSize: Math.round(stage.u * 0.55)
                color: Type.text
                elide: Text.ElideRight
                text: card.task.title || ""
            }
            KitText {
                width: card.width * 0.12
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                font.pixelSize: Math.round(stage.u * 0.5)
                color: Type.muted
                text: I18n.t("prefs.ai.tasks.stage." + card.task.column)
            }
            Meta {
                anchors.verticalCenter: parent.verticalCenter
                width: card.width * 0.48
                task: card.task
                planned: card.planned
            }
        }
    }

    // A task's line: agent, branch, time, cost (as shown), and the plan or
    // accept state.
    component Meta: Flow {
        id: meta
        property var task: ({})
        property bool planned: false
        spacing: Math.round(stage.u * 0.25)
        Icon {
            icon: Icons[stage.agentIcon[meta.task.agent] || "robot"] ?? ""
            size: Math.round(stage.u * 0.55)
            tone: "secondary"
        }
        Tag {
            visible: meta.planned
            icon: Icons.listChecks
            text: I18n.t("prefs.ai.tasks.stage.plan")
            accent: true
        }
        Tag {
            visible: meta.task.column === "review"
            icon: stage.squash ? Icons.stack : Icons.gitBranch
            text: I18n.t(stage.squash ? "prefs.ai.tasks.stage.one_commit" : "prefs.ai.tasks.stage.merge")
            accent: true
        }
        Tag {
            visible: stage.branch && meta.task.column !== "queued" && !meta.planned && meta.task.column !== "review"
            icon: Icons.gitBranch
            text: stage.inPlace ? I18n.t("prefs.ai.tasks.stage.current") : (meta.task.slug || "")
        }
        Tag {
            visible: stage.elapsed && (meta.task.time || "") !== ""
            text: meta.task.time || ""
        }
        Tag {
            visible: stage.costs && (meta.task.cost || "") !== ""
            text: meta.task.cost || ""
        }
    }

    // One step of the tasks-at-once control (1 to 8).
    component Step: Mark {
        id: step
        property string icon: ""
        property int delta: 1
        readonly property int next: Math.max(1, Math.min(8, stage.parallel + step.delta))
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(stage.u * 1.05)
        height: width
        color: area.containsMouse && step.next !== stage.parallel ? Qt.alpha(Type.accent, 0.2) : "transparent"
        opacity: step.next !== stage.parallel ? 1 : 0.35
        Icon {
            anchors.centerIn: parent
            icon: step.icon
            size: Math.round(stage.u * 0.55)
            tone: "secondary"
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (step.next !== stage.parallel)
                SettingsStore.set("ai.tasks.maxParallel", step.next)
        }
    }

    component Tag: Row {
        id: tag
        property string icon: ""
        property string text: ""
        property bool accent: false
        spacing: Math.round(stage.u * 0.12)
        Icon {
            visible: tag.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            icon: tag.icon
            size: Math.round(stage.u * 0.5)
            tone: tag.accent ? "accent" : "muted"
        }
        KitText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            font.pixelSize: Math.round(stage.u * 0.46)
            color: tag.accent ? Type.accent : Type.muted
            text: tag.text
        }
    }
}
