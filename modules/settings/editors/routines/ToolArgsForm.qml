pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import "../../../routines/RoutineModel.js" as RoutineModel
import "../../../routines/RoutineTools.js" as Tools

// The arguments of a tool step: one ArgField per field of the tool's JSON
// schema (the form), or the raw JSON object behind "Edit as JSON". Schema
// problems (missing required value, out of range, wrong choice) show under
// the field. `edited(args)` carries the whole new object.
ColumnLayout {
    id: root

    property var tool: null
    property var args: ({})
    property bool asJson: false

    signal edited(var args)

    readonly property var fieldList: root.tool ? Tools.fields(root.tool) : []
    readonly property var issues: {
        const out = {};
        if (root.tool)
            Tools.validate(root.tool, root.args).forEach(p => out[p.key] = p);
        return out;
    }
    readonly property var jsonParse: RoutineModel.parseArgs(jsonField.input.text)

    function message(p: var): string {
        if (!p)
            return "";
        const n = p.code === "min" ? p.min : p.max;
        return I18n.t("routines.validate." + p.code, n);
    }

    spacing: Space.s

    Repeater {
        model: root.asJson || !root.tool ? [] : root.fieldList
        delegate: ArgField {
            id: arg
            required property var modelData
            Layout.fillWidth: true
            tool: root.tool.name
            field: arg.modelData
            value: (root.args || {})[arg.modelData.key]
            problem: root.message(root.issues[arg.modelData.key])
            onChanged: v => root.edited(Tools.withArg(root.args, arg.modelData.key, v))
        }
    }

    KitText {
        Layout.fillWidth: true
        visible: !root.asJson && root.tool && root.fieldList.length === 0
        role: "caption"
        text: I18n.t("routines.no_arguments")
    }

    TextControl {
        id: jsonField
        objectName: "toolArgs"
        Layout.fillWidth: true
        visible: root.asJson || !root.tool
        monospace: true
        text: RoutineModel.argsText(root.args)
        placeholder: I18n.t("routines.args_placeholder")
        invalid: !root.jsonParse.ok
        onEdited: t => {
            const p = RoutineModel.parseArgs(t);
            if (p.ok)
                root.edited(p.value);
        }
    }

    KitText {
        Layout.fillWidth: true
        visible: root.asJson && !root.jsonParse.ok
        role: "caption"
        color: Colors.error
        text: I18n.t("routines.validate.json")
    }

    Repeater {
        // Problems of a JSON edit that has no field to carry them.
        model: root.asJson ? Object.keys(root.issues).map(k => root.issues[k]) : []
        delegate: KitText {
            required property var modelData
            Layout.fillWidth: true
            role: "caption"
            color: Colors.error
            text: modelData.key + ": " + root.message(modelData)
        }
    }
}
