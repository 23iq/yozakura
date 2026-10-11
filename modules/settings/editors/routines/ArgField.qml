pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.settings.controls
import "../../../routines/RoutineTools.js" as Tools

// One argument of a tool step, built from its JSON schema field
// ({key, kind, options, min, max, step, unit, required, def, hint}, see
// RoutineTools.fields): a label, the control that fits the kind (segmented
// choice, switch, slider, stepper, text), a hint and, when the value breaks
// the schema, the problem. `changed(value)`: undefined clears the argument.
ColumnLayout {
    id: root

    property string tool: ""
    property var field: ({})
    property var value
    property string problem: ""

    signal changed(var value)

    readonly property bool isSet: root.value !== undefined && root.value !== null && root.value !== ""
    readonly property string hint: Tools.fieldHint(root.tool, root.field.key, root.field.hint, root.tr)
    readonly property var tr: key => I18n.has(key) ? I18n.t(key) : ""

    // Choice tokens: enum values as they are, "unset" for a cleared argument.
    function token(v) {
        return v === undefined || v === null || v === "" ? "unset" : String(v);
    }

    function fromToken(t) {
        if (t === "unset")
            return undefined;
        if (t === "true" || t === "false")
            return t === "true";
        return t;
    }

    function choices(): var {
        const f = root.field;
        let values = [];
        if (f.kind === "enum")
            values = f.options.map(o => String(o));
        else if (f.kind === "triple")
            values = ["true", "false", "toggle"];
        else if (f.kind === "tristate")
            values = ["true", "false"];
        if (!f.required)
            values = ["unset"].concat(values);
        return values.map(v => ({
                    "value": v,
                    "label": v === "unset" ? root.unsetLabel() : Tools.valueLabel(root.tool, f.key, v, root.tr)
                }));
    }

    // What an omitted argument means: "toggle" for a switch-like tool,
    // otherwise the tool leaves the setting alone.
    function unsetLabel(): string {
        return Tools.trOr(root.tr, "routines.value." + root.tool + "." + root.field.key + ".unset", I18n.t(root.field.kind === "tristate" ? "routines.enum.toggle" : "routines.enum.unset"));
    }

    spacing: Space.xs

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.m

        KitText {
            Layout.preferredWidth: Space.px(150)
            Layout.alignment: Qt.AlignTop
            role: "secondary"
            text: Tools.fieldLabel(root.tool, root.field.key, root.tr) + (root.field.required ? " *" : "")
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: control.implicitHeight

            Loader {
                id: control
                width: parent.width
                sourceComponent: {
                    switch (root.field.kind) {
                    case "enum":
                    case "triple":
                    case "tristate":
                        return choice;
                    case "switch":
                        return toggle;
                    case "slider":
                        return slider;
                    case "number":
                        return stepper;
                    }
                    return text;
                }
            }
        }
    }

    KitText {
        Layout.fillWidth: true
        visible: root.problem !== "" || root.hint !== ""
        role: "caption"
        elide: Text.ElideNone
        wrapMode: Text.WordWrap
        text: root.problem !== "" ? root.problem : root.hint
        color: root.problem !== "" ? Colors.error : Type.muted
    }

    Component {
        id: choice
        SelectorControl {
            translate: false
            options: root.choices()
            value: root.token(root.value)
            onSelected: v => root.changed(root.fromToken(v))
        }
    }

    Component {
        id: toggle
        Item {
            implicitHeight: sw.implicitHeight
            ToggleControl {
                id: sw
                checked: root.isSet ? root.value === true : root.field.def === true
                onToggled: v => root.changed(v)
            }
        }
    }

    Component {
        id: slider
        RowLayout {
            spacing: Space.s
            SliderControl {
                Layout.fillWidth: true
                from: root.field.min
                to: root.field.max
                stepSize: root.field.step
                unit: root.field.unit
                value: root.isSet ? root.value : root.field.min
                opacity: root.isSet || root.field.required ? 1 : 0.5
                onMoved: v => root.changed(v)
            }
            IconButton {
                visible: root.isSet && !root.field.required
                icon: Icons.cancel
                size: "s"
                onClicked: root.changed(undefined)
            }
        }
    }

    Component {
        id: stepper
        RowLayout {
            spacing: Space.s
            NumberControl {
                from: root.field.min !== undefined ? root.field.min : 0
                to: root.field.max !== undefined ? root.field.max : 100000
                stepSize: root.field.step || 1
                unit: root.field.unit
                value: root.isSet ? root.value : (root.field.min !== undefined ? root.field.min : 0)
                opacity: root.isSet || root.field.required ? 1 : 0.5
                onChanged: v => root.changed(v)
            }
            IconButton {
                visible: root.isSet && !root.field.required
                icon: Icons.cancel
                size: "s"
                onClicked: root.changed(undefined)
            }
        }
    }

    Component {
        id: text
        TextControl {
            text: root.isSet ? (typeof root.value === "string" ? root.value : JSON.stringify(root.value)) : ""
            monospace: root.field.kind === "json"
            invalid: root.problem !== ""
            onEdited: t => {
                if (root.field.kind !== "json")
                    return root.changed(t.trim() === "" ? undefined : t);
                try {
                    root.changed(t.trim() === "" ? undefined : JSON.parse(t));
                } catch (e) {
                    root.changed(t);
                }
            }
        }
    }
}
