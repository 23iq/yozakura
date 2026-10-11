pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.settings.controls
import qs.modules.settings.editors.keybinds
import "../../../../config/KeybindActions.js" as KeybindActions
import "../../../routines/RoutineModel.js" as RoutineModel

// One step of a routine in the editor: a bind action (the keybind
// editor's action picker and argument fields), a built-in tool
// (RoutineToolStep: tool picker + argument form) or a delay. The header
// reads the step as a sentence. Emits patches.
StyledRect {
    id: root

    property var step: ({})
    property int stepIndex: 0
    property int count: 1
    property string problem: ""        // translation key, "" = fine
    property string status: ""         // last test run: ok | failed | skipped
    signal patched(var patch)
    signal removed
    signal moved(int delta)

    readonly property string kind: step.kind || "action"
    // The step as one sentence ("Turn on Do Not Disturb", "Switch Workspace · 3").
    readonly property string summary: RoutineModel.stepSummary(step, RoutinesService.tools, key => I18n.has(key) ? I18n.t(key) : "", id => I18n.t(KeybindActions.labelKey(id)))
    // Only the sentence shows; click it to fold or unfold the step.
    property bool folded: false

    objectName: "routineStep:" + stepIndex
    variant: "internalbg"
    radius: Styling.radius(-3)
    implicitHeight: body.implicitHeight + 20

    ColumnLayout {
        id: body
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledRect {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                variant: root.status === "failed" || root.problem !== "" ? "error" : (root.status === "ok" ? "primary" : "common")
                Text {
                    anchors.centerIn: parent
                    text: root.status === "ok" ? Icons.accept : (root.status === "failed" ? Icons.cancel : String(root.stepIndex + 1))
                    font.family: root.status === "ok" || root.status === "failed" ? Icons.font : Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.DemiBold
                    color: parent.item
                }
            }
            Text {
                objectName: "stepSummary"
                Layout.fillWidth: true
                text: root.summary !== "" ? root.summary : I18n.t("routines.kind." + root.kind)
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: Colors.overSurface
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.folded = !root.folded
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.problem !== ""
                text: root.problem !== "" ? I18n.t(root.problem) : ""
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.error
            }
            IconButton {
                glyph: Icons.arrowUp
                size: 24
                enabled: root.stepIndex > 0
                opacity: enabled ? 1 : 0.35
                tooltip: I18n.t("routines.move_up")
                onClicked: root.moved(-1)
            }
            IconButton {
                glyph: Icons.arrowDown
                size: 24
                enabled: root.stepIndex < root.count - 1
                opacity: enabled ? 1 : 0.35
                tooltip: I18n.t("routines.move_down")
                onClicked: root.moved(1)
            }
            IconButton {
                objectName: "removeStep"
                glyph: Icons.trash
                danger: true
                size: 24
                tooltip: I18n.t("routines.remove_step")
                onClicked: root.removed()
            }
        }

        ActionEditor {
            visible: root.kind === "action" && !root.folded
            Layout.fillWidth: true
            action: ({
                    "id": root.step.action || "",
                    "args": root.step.args || {},
                    "layouts": []
                })
            onEdited: a => root.patched({
                    "action": a.id,
                    "args": a.args || {}
                })
        }

        RoutineToolStep {
            visible: root.kind === "tool" && !root.folded
            Layout.fillWidth: true
            step: root.step
            onPatched: p => root.patched(p)
        }

        RowLayout {
            visible: root.kind === "delay" && !root.folded
            Layout.fillWidth: true
            spacing: 10
            NumberControl {
                objectName: "delaySeconds"
                value: (root.step.ms || 0) / 1000
                from: 0.5
                to: 600
                stepSize: 0.5
                unit: "s"
                onChanged: v => root.patched({
                        "ms": Math.round(v * 1000)
                    })
            }
            Text {
                Layout.fillWidth: true
                text: I18n.t("routines.delay_hint")
                wrapMode: Text.WordWrap
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.outline
            }
        }
    }
}
