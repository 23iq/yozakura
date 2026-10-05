pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import qs.config
import "../../../keybinds/BindModel.js" as BindModel

// Expanded editor of a bind. The usual case is one step: record the keys,
// pick what they do (an app, a shell panel, a window action...). Custom
// binds keep the rest behind "Advanced": a name, more combos and actions,
// layout limits and the raw dispatcher. A combo another bind uses is
// marked but saved as is: both binds are kept.
ColumnLayout {
    id: root

    required property var bind
    readonly property bool custom: bind.kind === "custom"
    // Special workspace binds: only the combo is edited here; the rest
    // lives on the special workspaces page.
    readonly property bool special: bind.kind === "special"
    // Open by default when the bind already uses advanced features.
    property bool advanced: BindModel.isAdvanced(bind)

    spacing: 10

    function setKey(i, k) {
        const keys = root.bind.keys.slice();
        keys[i] = k;
        KeybindsStore.setKeys(root.bind.uid, keys);
    }

    function removeKey(i) {
        const keys = root.bind.keys.slice();
        keys.splice(i, 1);
        KeybindsStore.setKeys(root.bind.uid, keys);
    }

    function setAction(j, a) {
        const actions = root.bind.actions.slice();
        actions[j] = a;
        KeybindsStore.setActions(root.bind.uid, actions);
    }

    function removeAction(j) {
        const actions = root.bind.actions.slice();
        actions.splice(j, 1);
        KeybindsStore.setActions(root.bind.uid, actions);
    }

    Item {
        implicitHeight: 0
    }

    // Keys
    FormRow {
        label: I18n.t("binds.key_combination")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.bind.keys
                delegate: KeyRecorder {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    combo: modelData
                    exceptUid: root.bind.uid
                    removable: root.custom && root.bind.keys.length > 1
                    autoStart: modelData.key === ""
                    onCommitted: k => root.setKey(index, k)
                    onRemoved: root.removeKey(index)
                }
            }

            AddLink {
                visible: root.custom && root.advanced
                text: I18n.t("binds.add_key")
                onClicked: KeybindsStore.setKeys(root.bind.uid, root.bind.keys.concat([
                    {
                        "modifiers": ["SUPER"],
                        "key": ""
                    }
                ]))
            }
        }
    }

    // What it does
    FormRow {
        visible: !root.special
        label: I18n.t("binds.action")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: root.special ? [] : root.bind.actions
                delegate: ActionEditor {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    action: modelData
                    showLayouts: root.custom && root.advanced
                    withHidden: root.custom && root.advanced
                    removable: root.custom && root.bind.actions.length > 1
                    onEdited: a => root.setAction(index, a)
                    onRemoved: root.removeAction(index)
                }
            }

            AddLink {
                visible: root.custom && root.advanced
                text: I18n.t("binds.add_action")
                onClicked: KeybindsStore.setActions(root.bind.uid, root.bind.actions.concat([
                    {
                        "id": "apps.launch",
                        "args": {
                            "app": ""
                        },
                        "layouts": []
                    }
                ]))
            }
        }
    }

    // Name shown instead of the action (custom binds, "Advanced").
    FormRow {
        visible: root.custom && root.advanced
        label: I18n.t("binds.description")

        TextControl {
            Layout.fillWidth: true
            text: root.bind.name
            placeholder: I18n.t("binds.keybind_name_placeholder")
            onEdited: t => KeybindsStore.setName(root.bind.uid, t.trim())
        }
    }

    // Footer: on/off, Advanced, reset or delete
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 10
        spacing: 10

        ToggleControl {
            objectName: "keybindEnabled"
            checked: root.bind.enabled
            onToggled: v => KeybindsStore.setEnabled(root.bind.uid, v)
        }
        Text {
            text: I18n.t("binds.enabled")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }

        AddLink {
            objectName: "keybindAdvanced"
            visible: root.custom
            Layout.leftMargin: 6
            icon: root.advanced ? "caretUp" : "caretDown"
            text: I18n.t("binds.advanced")
            onClicked: root.advanced = !root.advanced
        }

        Item {
            Layout.fillWidth: true
        }
        PillButton {
            visible: root.special
            kind: "ghost"
            icon: "arrowSquareOut"
            text: I18n.t("specials.edit_in_settings")
            onClicked: SettingsStore.navigate("specials", "", "")
        }
        PillButton {
            visible: !root.custom && !root.special
            enabled: KeybindsStore.isModified(root.bind)
            kind: "ghost"
            icon: "arrowCounterClockwise"
            text: I18n.t("common.reset_default")
            onClicked: KeybindsStore.reset(root.bind.uid)
        }
        PillButton {
            visible: root.custom
            kind: "ghost"
            icon: "trash"
            text: I18n.t("binds.delete_keybind")
            onClicked: KeybindsStore.remove(root.bind.uid)
        }
    }

    // A labelled line of the form: label on the left, controls on the right.
    component FormRow: RowLayout {
        id: form
        property string label: ""
        default property alias content: slot.data

        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        spacing: 12

        Text {
            Layout.preferredWidth: 72
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 10
            text: form.label
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
        ColumnLayout {
            id: slot
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
