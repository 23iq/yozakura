pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.settings.controls
import qs.modules.settings.editors
import "../../../routines/RoutineModel.js" as RoutineModel

// One routine in settings: a header (icon, name, step count, run, open)
// and, expanded, the editor: name, icon, keywords, steps, add-step chips
// and Save / Test run / Discard / Delete. Works on a draft owned by
// RoutinesEditor; nothing is written until Save.
StyledRect {
    id: root

    property var routine: RoutineModel.newRoutine("")
    property bool isNew: false
    property bool dirty: false
    property bool expanded: false
    property bool busy: false
    property var report: null
    property string error: ""
    property bool armed: false

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = false
    }

    signal edited(var routine)
    signal saveRequested
    signal testRequested
    signal runRequested
    signal discardRequested
    signal removeRequested
    signal toggleRequested

    readonly property var problems: RoutineModel.problems(routine)
    readonly property var stepProblems: {
        const out = {};
        problems.forEach(p => {
            if (p.index >= 0 && out[p.index] === undefined)
                out[p.index] = p.key;
        });
        return out;
    }
    readonly property var stepStatus: {
        const out = {};
        ((report && report.steps) || []).forEach(s => out[s.index] = s.status);
        return out;
    }

    objectName: "routineCard:" + (routine.id || "new")
    variant: expanded ? "pane" : "common"
    radius: Styling.radius(-1)
    implicitHeight: col.implicitHeight + 20

    function patch(fields) {
        root.edited(Object.assign(RoutineModel.clone(root.routine), fields));
    }

    ColumnLayout {
        id: col
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StyledRect {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Styling.radius(-2)
                variant: "primary"
                Text {
                    anchors.centerIn: parent
                    text: Icons[root.routine.icon] || Icons.lightning
                    font.family: Icons.font
                    font.pixelSize: 18
                    color: parent.item
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.routine.name || I18n.t("routines.untitled")
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.DemiBold
                    color: Colors.overSurface
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("routines.launcher.steps", (root.routine.steps || []).length) + (root.dirty ? " · " + I18n.t("routines.unsaved") : "")
                    elide: Text.ElideRight
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: root.dirty ? Colors.primary : Colors.outline
                }
            }
            Spinner {
                visible: root.busy
            }
            IconButton {
                objectName: "runRoutine"
                visible: !root.isNew && !root.dirty
                glyph: Icons.play
                size: 28
                tooltip: I18n.t("routines.run")
                onClicked: root.runRequested()
            }
            IconButton {
                objectName: "toggleRoutine"
                glyph: root.expanded ? Icons.caretUp : Icons.caretDown
                size: 28
                tooltip: I18n.t(root.expanded ? "routines.collapse" : "routines.edit")
                onClicked: root.toggleRequested()
            }
        }

        ColumnLayout {
            visible: root.expanded
            Layout.fillWidth: true
            spacing: 10

            AiTextRow {
                objectName: "routineName"
                label: I18n.t("routines.name")
                value: root.routine.name || ""
                placeholder: I18n.t("routines.name_placeholder")
                onEdited: t => root.patch({
                        "name": t
                    })
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: RoutineModel.ICONS
                    delegate: IconButton {
                        required property string modelData
                        glyph: Icons[modelData] || ""
                        size: 30
                        active: root.routine.icon === modelData
                        onClicked: root.patch({
                            "icon": modelData
                        })
                    }
                }
            }
            AiTextRow {
                label: I18n.t("routines.keywords")
                value: root.routine.keywords || ""
                placeholder: I18n.t("routines.keywords_placeholder")
                onEdited: t => root.patch({
                        "keywords": t
                    })
            }
            AiToggleRow {
                label: I18n.t("routines.continue_on_error")
                checked: !!root.routine.continueOnError
                onToggled: v => root.patch({
                        "continueOnError": v
                    })
            }

            Repeater {
                model: root.routine.steps || []
                delegate: RoutineStepRow {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    step: modelData
                    stepIndex: index
                    count: (root.routine.steps || []).length
                    problem: root.stepProblems[index] || ""
                    status: root.dirty ? "" : (root.stepStatus[index] || "")
                    onPatched: p => root.edited(RoutineModel.withStepPatch(root.routine, index, p))
                    onRemoved: root.edited(RoutineModel.withoutStep(root.routine, index))
                    onMoved: d => root.edited(RoutineModel.withMovedStep(root.routine, index, d))
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [["action", "keyboard"], ["tool", "wrench"], ["delay", "hourglass"]]
                    delegate: Chip {
                        required property var modelData
                        objectName: "addStep:" + modelData[0]
                        glyph: Icons[modelData[1]]
                        label: I18n.t("routines.add_" + modelData[0])
                        onClicked: root.edited(RoutineModel.withStep(root.routine, RoutineModel.newStep(modelData[0])))
                    }
                }
            }

            RoutineReport {
                Layout.fillWidth: true
                report: root.report
            }
            Text {
                Layout.fillWidth: true
                visible: root.error !== ""
                text: root.error
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.error
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Chip {
                    objectName: "saveRoutine"
                    active: root.dirty && root.problems.length === 0
                    enabled: root.problems.length === 0 && (root.dirty || root.isNew) && !root.busy
                    opacity: enabled ? 1 : 0.45
                    glyph: Icons.accept
                    label: I18n.t("routines.save")
                    onClicked: root.saveRequested()
                }
                Chip {
                    objectName: "testRoutine"
                    enabled: root.problems.length === 0 && (root.routine.steps || []).length > 0 && !root.busy
                    opacity: enabled ? 1 : 0.45
                    glyph: Icons.play
                    label: I18n.t("routines.test")
                    onClicked: root.testRequested()
                }
                Chip {
                    visible: root.dirty && !root.isNew
                    glyph: Icons.arrowCounterClockwise
                    label: I18n.t("routines.discard")
                    onClicked: root.discardRequested()
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.armed
                    text: I18n.t("routines.delete_confirm")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.error
                }
                IconButton {
                    objectName: "deleteRoutine"
                    glyph: Icons.trash
                    danger: true
                    active: root.armed
                    size: 28
                    tooltip: I18n.t(root.isNew ? "routines.discard" : "routines.delete")
                    // Saved routines need a second click (binds may run them).
                    onClicked: {
                        if (root.isNew || root.armed) {
                            root.armed = false;
                            root.removeRequested();
                        } else {
                            root.armed = true;
                            disarm.restart();
                        }
                    }
                }
            }
        }
    }
}
