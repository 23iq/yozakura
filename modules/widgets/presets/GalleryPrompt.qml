import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "../../settings/presets/PresetModel.js" as PresetModel

// The gallery's inline prompt: a set name for "Save as…" and rename
// (validated like the backend, PresetModel.nameProblem) or the delete
// confirmation. ask(mode, target, initial); submitted(mode, target, value)
// on Enter / confirm, closed() either way.
FocusScope {
    id: root

    property string mode: "" // "" | "save" | "rename" | "delete"
    property string target: ""
    property var presets: []
    readonly property bool open: root.mode !== ""
    readonly property bool naming: root.open && root.mode !== "delete"
    readonly property string problem: root.naming ? PresetModel.nameProblem(root.presets, field.text, root.mode === "rename" ? root.target : "") : ""

    signal submitted(string mode, string target, string value)
    signal closed

    function ask(m, t, initial) {
        root.mode = m;
        root.target = t || "";
        field.text = initial || "";
        if (root.naming)
            field.focusInput();
        else
            root.forceActiveFocus();
    }

    function cancel() {
        root.mode = "";
        root.closed();
    }

    function submit() {
        if (!root.open || root.problem !== "")
            return;
        const m = root.mode;
        const t = root.target;
        const v = field.text.trim();
        root.mode = "";
        root.submitted(m, t, v);
        root.closed();
    }

    objectName: "galleryPrompt"
    visible: root.open
    implicitHeight: root.open ? body.implicitHeight : 0

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.submit();
        else if (event.key === Qt.Key_Escape)
            root.cancel();
        else
            return;
        event.accepted = true;
    }

    Column {
        id: body
        width: parent.width
        spacing: Space.s

        KitText {
            width: parent.width
            role: "secondary"
            text: root.mode === "save" ? I18n.t("presets.prompt.save") : I18n.t("presets.prompt." + root.mode, root.target)
        }

        SearchField {
            id: field
            objectName: "promptName"
            width: parent.width
            visible: root.naming
            glyph: Icons.pencil
            clearOnEscape: false
            onAccepted: root.submit()
            onEscapePressed: root.cancel()
        }

        KitText {
            width: parent.width
            visible: root.problem !== "" && field.text !== ""
            role: "caption"
            text: root.problem !== "" ? I18n.t(root.problem) : ""
        }

        Row {
            spacing: Space.s

            Chip {
                objectName: "promptConfirm"
                active: true
                enabled: root.problem === ""
                icon: root.mode === "delete" ? Icons.trash : Icons.check
                text: I18n.t(root.mode === "delete" ? "common.delete" : (root.mode === "rename" ? "common.rename" : "common.save"))
                onClicked: root.submit()
            }

            Chip {
                objectName: "promptCancel"
                text: I18n.t("common.cancel")
                onClicked: root.cancel()
            }
        }
    }
}
