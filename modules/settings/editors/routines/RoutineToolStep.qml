pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import "../../../routines/RoutineTools.js" as Tools

// Body of a "tool" step: what it does (title + one line), a grouped,
// searchable tool picker behind "Change", the tool's arguments as a form,
// and under "Advanced" the raw JSON arguments and the tool id (typed ids
// of tools outside the catalog). Emits step patches like RoutineStepRow.
ColumnLayout {
    id: root

    property var step: ({})
    readonly property var catalog: RoutinesService.tools
    readonly property var tool: Tools.byName(root.catalog)[root.step.tool || ""] || null
    readonly property var tr: key => I18n.has(key) ? I18n.t(key) : ""
    property bool picking: (root.step.tool || "") === ""
    property bool advanced: false

    signal patched(var patch)

    Component.onCompleted: {
        RoutinesService.ensureTools();
        // A tool the catalog does not know can only be edited as JSON.
        root.advanced = root.step.tool !== undefined && root.step.tool !== "" && !root.tool && RoutinesService.toolsLoaded;
    }

    function pick(tool: var) {
        root.picking = false;
        if (tool.name !== root.step.tool)
            root.patched(Tools.newStep(tool));
    }

    spacing: Space.s

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.m

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            KitText {
                Layout.fillWidth: true
                role: "body"
                text: root.tool ? Tools.title(root.tool, root.tr) : Tools.toolTitle(root.step.tool || "", root.catalog, root.tr) || I18n.t("routines.tool_choose")
            }
            KitText {
                Layout.fillWidth: true
                visible: text !== ""
                role: "caption"
                text: root.tool ? Tools.description(root.tool, root.tr) : (root.step.tool ? I18n.t("routines.tool_unknown") : "")
            }
        }
        Chip {
            objectName: "changeTool"
            icon: root.picking ? Icons.caretUp : Icons.caretDown
            text: I18n.t("routines.tool_change")
            active: root.picking
            onClicked: root.picking = !root.picking
        }
    }

    ToolPicker {
        Layout.fillWidth: true
        visible: root.picking
        catalog: root.catalog
        categories: RoutinesService.toolCategories
        current: root.step.tool || ""
        onPicked: tool => root.pick(tool)
    }

    ToolArgsForm {
        objectName: "toolForm"
        Layout.fillWidth: true
        visible: !root.picking
        tool: root.tool
        args: root.step.args || {}
        asJson: root.advanced || !root.tool
        onEdited: a => root.patched({
                "args": a
            })
    }

    Chip {
        objectName: "toolAdvanced"
        visible: !root.picking
        icon: Icons.wrench
        text: I18n.t("routines.tool_advanced")
        active: root.advanced
        onClicked: root.advanced = !root.advanced
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.advanced && !root.picking
        spacing: Space.xs

        KitText {
            Layout.fillWidth: true
            role: "caption"
            text: I18n.t("routines.tool_id_hint")
            elide: Text.ElideNone
            wrapMode: Text.WordWrap
        }
        TextControl {
            objectName: "toolName"
            Layout.fillWidth: true
            monospace: true
            text: root.step.tool || ""
            placeholder: I18n.t("routines.tool_id_placeholder")
            onEdited: t => root.patched({
                    "tool": t.trim()
                })
        }
    }
}
