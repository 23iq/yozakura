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
// (workspace, direction, command...) and, for custom binds, the layouts it
// is limited to.
ColumnLayout {
    id: root

    // {id, args, layouts}
    property var action: ({
            "id": "command.run",
            "args": {},
            "layouts": []
        })
    property bool showLayouts: false
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionPicker {
            Layout.fillWidth: true
            actionId: root.action.id
            onPicked: id => root.emit({
                    "id": id,
                    "args": KeybindActions.defaultArgs(id)
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
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 110
                text: I18n.t(KeybindActions.fieldLabelKey(fieldRow.modelData.key))
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
            TextControl {
                Layout.fillWidth: true
                text: String((root.action.args || {})[fieldRow.modelData.key] ?? "")
                placeholder: fieldRow.modelData.placeholder
                monospace: fieldRow.modelData.key === "command" || root.action.id === "legacy.dispatcher"
                onEdited: t => {
                    const args = Object.assign({}, root.action.args || {});
                    args[fieldRow.modelData.key] = t;
                    root.emit({
                        "args": args
                    });
                }
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
