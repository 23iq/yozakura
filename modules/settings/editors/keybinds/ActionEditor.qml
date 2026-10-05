pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.controls
import qs.config
import "../../../../config/KeybindActions.js" as KeybindActions
import "../../../keybinds/BindModel.js" as BindModel

// One action of a bind: the searchable picker, the action's arguments
// (workspace, direction, command, the app to open...) and, in the
// editor's "Advanced" part, the layouts it is limited to.
ColumnLayout {
    id: root

    // {id, args, layouts}
    property var action: ({
            "id": "command.run",
            "args": {},
            "layouts": []
        })
    property bool showLayouts: false
    // Offer the raw dispatcher in the picker.
    property bool withHidden: false
    property bool removable: false
    signal edited(var action)
    signal removed

    readonly property var fields: KeybindActions.getActionFields(action.id)

    spacing: 8

    function emit(patch) {
        edited(Object.assign({
            "id": action.id,
            "args": action.args || {},
            "layouts": action.layouts || []
        }, patch));
    }

    // Opens the action list, ready to type (the add dialog's step 2).
    function openPicker() {
        picker.openList();
    }

    function setArg(key, value) {
        const args = Object.assign({}, root.action.args || {});
        args[key] = value;
        root.emit({
            "args": args
        });
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionPicker {
            id: picker
            Layout.fillWidth: true
            actionId: root.action.id
            withHidden: root.withHidden
            onPicked: (id, args) => root.emit({
                    "id": id,
                    "args": args || KeybindActions.defaultArgs(id)
                })
        }
        PillButton {
            visible: root.removable
            kind: "ghost"
            icon: "trash"
            text: ""
            implicitWidth: implicitHeight
            onClicked: root.removed()
            Accessible.name: I18n.t("binds.remove_action")
        }
    }

    Repeater {
        model: root.fields
        delegate: RowLayout {
            id: fieldRow
            required property var modelData
            readonly property bool isApp: modelData.kind === "app"
            Layout.fillWidth: true
            spacing: 12

            Text {
                // The app picker speaks for itself.
                visible: !fieldRow.isApp
                Layout.preferredWidth: 110
                text: I18n.t(KeybindActions.fieldLabelKey(fieldRow.modelData.key))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
            AppPickerField {
                visible: fieldRow.isApp
                Layout.fillWidth: true
                appId: String((root.action.args || {})[fieldRow.modelData.key] ?? "")
                onPicked: id => root.setArg(fieldRow.modelData.key, id)
            }
            TextControl {
                visible: !fieldRow.isApp
                Layout.fillWidth: true
                text: String((root.action.args || {})[fieldRow.modelData.key] ?? "")
                placeholder: fieldRow.modelData.placeholder
                monospace: fieldRow.modelData.key === "command" || root.action.id === "legacy.dispatcher"
                onEdited: t => root.setArg(fieldRow.modelData.key, t)
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.showLayouts
        spacing: 6

        Text {
            height: 30
            verticalAlignment: Text.AlignVCenter
            rightPadding: 6
            text: I18n.t("binds.layouts_only")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
        Repeater {
            model: BindModel.LAYOUTS
            delegate: ChipToggle {
                required property string modelData
                text: modelData
                checked: (root.action.layouts || []).indexOf(modelData) !== -1
                onToggled: v => {
                    const rest = (root.action.layouts || []).filter(l => l !== modelData);
                    root.emit({
                        "layouts": v ? rest.concat([modelData]) : rest
                    });
                }
            }
        }
    }
}
