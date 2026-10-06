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
import "../../../routines/RoutineModel.js" as RoutineModel

// One step of a routine in the editor: a bind action (the keybind
// editor's action picker and argument fields), a built-in tool (name +
// JSON arguments, common tools as chips) or a delay. Emits patches.
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
    readonly property var argsParse: RoutineModel.parseArgs(argsField.input.text)

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
                text: I18n.t("routines.kind." + root.kind)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                color: Colors.overSurfaceVariant
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
            Item {
                Layout.fillWidth: root.problem === ""
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
            visible: root.kind === "action"
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

        ColumnLayout {
            visible: root.kind === "tool"
            Layout.fillWidth: true
            spacing: 6

            TextControl {
                objectName: "toolName"
                Layout.fillWidth: true
                monospace: true
                text: root.step.tool || ""
                placeholder: "dnd_set"
                onEdited: t => root.patched({
                        "tool": t.trim()
                    })
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: RoutineModel.SUGGESTED_TOOLS
                    delegate: ChipToggle {
                        required property string modelData
                        text: modelData
                        checked: root.step.tool === modelData
                        onToggled: v => {
                            if (v)
                                root.patched({
                                    "tool": modelData
                                });
                        }
                    }
                }
            }
            TextControl {
                id: argsField
                objectName: "toolArgs"
                Layout.fillWidth: true
                monospace: true
                text: RoutineModel.argsText(root.step.args)
                placeholder: I18n.t("routines.args_placeholder")
                invalid: !root.argsParse.ok
                onEdited: t => {
                    const p = RoutineModel.parseArgs(t);
                    if (p.ok)
                        root.patched({
                            "args": p.value
                        });
                }
            }
        }

        RowLayout {
            visible: root.kind === "delay"
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
