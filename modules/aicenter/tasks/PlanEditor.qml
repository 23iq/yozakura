pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import qs.modules.aicenter.markdown
import "../../services/tasks/TaskModel.js" as TaskModel

// Plan review of a task in plan mode: the agent's steps, editable (edit,
// delete, add, move up/down), then Run (tasks.run with the steps), Save
// (tasks.plan.update) or Revise (a note back to the planner).
ColumnLayout {
    id: root
    objectName: "planEditor"

    property var task: null
    property var steps: []
    property bool dirty: false
    property string error: ""
    readonly property bool editable: !!root.task && root.task.status === "awaiting_plan"

    function load() {
        root.steps = root.task && root.task.plan ? root.task.plan.slice() : [];
        root.dirty = false;
    }
    function edit(next) {
        root.steps = next;
        root.dirty = true;
    }
    function done(res, error) {
        root.error = error || "";
        if (!error)
            root.dirty = false;
    }
    function save() {
        TasksService.updatePlan(root.task.id, root.steps, (r, e) => root.done(r, e));
    }
    function run() {
        TasksService.runPlan(root.task.id, root.steps, (r, e) => root.done(r, e));
    }
    function revise() {
        const note = reviseField.text.trim();
        if (!note)
            return;
        TasksService.followup(root.task.id, TaskModel.primaryRun(root.task), note, (r, e) => {
            root.done(r, e);
            if (!e)
                reviseField.text = "";
        });
    }

    property string _loadedFor: ""
    onTaskChanged: {
        const key = root.task ? root.task.id : "";
        if (key !== root._loadedFor || !root.dirty) {
            root._loadedFor = key;
            root.load();
        }
    }

    spacing: BarLook.gap

    AiText {
        role: "caption"
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: root.editable ? I18n.t("ai.tasks.plan_hint") : (root.task && root.task.status === "planning" ? I18n.t("ai.tasks.planning") : I18n.t("ai.tasks.plan_used"))
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: stepCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: stepCol
            width: parent.width
            spacing: Space.xs
            Repeater {
                model: root.steps.length
                delegate: StyledRect {
                    id: stepRow
                    required property int index
                    objectName: "planStep_" + index
                    Layout.fillWidth: true
                    implicitHeight: Math.max(36, field.implicitHeight + 2 * Space.xs)
                    radius: Look.radius("control")
                    variant: field.activeFocus ? "focus" : "pane"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Space.s
                        anchors.rightMargin: Space.xs
                        spacing: Space.s
                        AiText {
                            role: "caption"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Space.s
                            text: (stepRow.index + 1) + "."
                            mono: true
                        }
                        TextArea {
                            id: field
                            Layout.fillWidth: true
                            readOnly: !root.editable
                            wrapMode: TextArea.Wrap
                            text: root.steps[stepRow.index] || ""
                            font.family: Config.theme.font
                            font.pixelSize: BarLook.size("secondary")
                            color: Colors.overSurface
                            selectionColor: Colors.primary
                            selectedTextColor: Colors.overPrimary
                            background: null
                            onTextChanged: if (activeFocus && text !== root.steps[stepRow.index])
                                root.edit(TaskModel.planSet(root.steps, stepRow.index, text))
                        }
                        IconButton {
                            visible: root.editable
                            size: "xs"
                            icon: Icons.caretUp
                            enabled: stepRow.index > 0
                            tooltip: I18n.t("ai.tasks.move_up")
                            onClicked: root.edit(TaskModel.planMove(root.steps, stepRow.index, stepRow.index - 1))
                        }
                        IconButton {
                            visible: root.editable
                            size: "xs"
                            icon: Icons.caretDown
                            enabled: stepRow.index < root.steps.length - 1
                            tooltip: I18n.t("ai.tasks.move_down")
                            onClicked: root.edit(TaskModel.planMove(root.steps, stepRow.index, stepRow.index + 1))
                        }
                        IconButton {
                            visible: root.editable
                            size: "xs"
                            danger: true
                            icon: Icons.trash
                            tooltip: I18n.t("ai.tasks.remove_step")
                            onClicked: root.edit(TaskModel.planRemove(root.steps, stepRow.index))
                        }
                    }
                }
            }
            Chip {
                objectName: "planAddStep"
                visible: root.editable
                icon: Icons.plus
                text: I18n.t("ai.tasks.add_step")
                quiet: true
                onClicked: root.edit(TaskModel.planInsert(root.steps, -1, ""))
            }
            MarkdownView {
                Layout.fillWidth: true
                visible: root.steps.length === 0 && !!root.task && !!root.task.planText
                text: root.task ? root.task.planText || "" : ""
            }
        }
    }

    AiText {
        role: "caption"
        Layout.fillWidth: true
        visible: root.error.length > 0
        text: root.error
        color: Colors.error
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.editable
        spacing: Space.s
        TextField {
            id: reviseField
            objectName: "planRevise"
            Layout.fillWidth: true
            placeholderText: I18n.t("ai.tasks.revise_placeholder")
            placeholderTextColor: Colors.outline
            color: Colors.overSurface
            font.family: Config.theme.font
            font.pixelSize: BarLook.size("secondary")
            background: StyledRect {
                variant: "common"
                radius: Look.radius("control")
            }
            onAccepted: root.revise()
        }
        Chip {
            visible: reviseField.text.trim().length > 0
            icon: Icons.arrowsClockwise
            text: I18n.t("ai.tasks.revise")
            onClicked: root.revise()
        }
        Chip {
            objectName: "planSave"
            visible: root.dirty
            icon: Icons.accept
            text: I18n.t("ai.tasks.save_plan")
            onClicked: root.save()
        }
        Chip {
            objectName: "planRun"
            icon: Icons.play
            text: I18n.t("ai.tasks.run_plan")
            active: true
            enabled: TaskModel.planClean(root.steps).length > 0
            onClicked: root.run()
        }
    }
}
