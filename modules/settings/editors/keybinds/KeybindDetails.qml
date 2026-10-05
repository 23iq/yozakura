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

// Expanded editor of a bind: its key combos (recorder each), its actions
// (picker + arguments + layouts), the description and delete/reset.
// Core binds have one combo and one action; custom binds any number.
ColumnLayout {
    id: root

    required property var bind
    readonly property bool custom: bind.kind === "custom"
    // Special workspace binds: only the combo is edited here; the rest
    // lives on the special workspaces page.
    readonly property bool special: bind.kind === "special"

    spacing: 12

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
        implicitHeight: 2
    }

    SectionLabel {
        text: I18n.t("binds.key_combination")
    }

    Repeater {
        model: root.bind.keys
        delegate: KeyRecorder {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            combo: modelData
            exceptUid: root.bind.uid
            removable: root.custom && root.bind.keys.length > 1
            autoStart: modelData.key === ""
            onCommitted: k => root.setKey(index, k)
            onRemoved: root.removeKey(index)
        }
    }

    AddLink {
        visible: root.custom
        Layout.leftMargin: 6
        text: I18n.t("binds.add_key")
        onClicked: KeybindsStore.setKeys(root.bind.uid, root.bind.keys.concat([
            {
                "modifiers": ["SUPER"],
                "key": ""
            }
        ]))
    }

    SectionLabel {
        visible: !root.special
        text: I18n.t("binds.action")
    }

    Repeater {
        model: root.special ? [] : root.bind.actions
        delegate: ActionEditor {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            action: modelData
            showLayouts: root.custom
            removable: root.custom && root.bind.actions.length > 1
            onEdited: a => root.setAction(index, a)
            onRemoved: root.removeAction(index)
        }
    }

    AddLink {
        visible: root.custom
        Layout.leftMargin: 6
        text: I18n.t("binds.add_action")
        onClicked: KeybindsStore.setActions(root.bind.uid, root.bind.actions.concat([
            {
                "id": "command.run",
                "args": {
                    "command": ""
                },
                "layouts": []
            }
        ]))
    }

    SectionLabel {
        visible: root.custom
        text: I18n.t("binds.description")
    }

    TextControl {
        visible: root.custom
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        text: root.bind.name
        placeholder: I18n.t("binds.keybind_name_placeholder")
        onEdited: t => KeybindsStore.setName(root.bind.uid, t.trim())
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12

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

    component SectionLabel: Text {
        Layout.leftMargin: 12
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-3)
        font.weight: Font.Bold
        font.letterSpacing: 1
        font.capitalization: Font.AllUppercase
        color: Colors.overSurfaceVariant
    }
}
