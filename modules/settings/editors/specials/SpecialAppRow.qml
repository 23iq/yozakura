pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import "../../Ui.js" as Ui
import qs.modules.components.kit

// One app of a special: window class (match), launch command, what to do
// when it already runs elsewhere, the "always open here" window rule and
// remove. `edited(patch)` carries the changed fields.
Rectangle {
    id: root

    property var app: ({})
    signal edited(var patch)
    signal removeRequested

    implicitHeight: column.implicitHeight + 20
    radius: Look.radius("control")
    color: Ui.alpha(Colors.overBackground, 0.04)
    border.width: 1
    border.color: Ui.alpha(Colors.outlineVariant, 0.6)

    ColumnLayout {
        id: column
        x: 10
        y: 10
        width: parent.width - 20
        spacing: Space.s

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.m
            IconImage {
                implicitSize: 24
                source: Quickshell.iconPath(root.app.icon || root.app.id || "", "application-x-executable")
                asynchronous: true
            }
            KitText {
                Layout.fillWidth: true
                text: root.app.name || root.app.match || ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PillButton {
                kind: "ghost"
                icon: "trash"
                text: ""
                implicitWidth: 34
                Accessible.name: I18n.t("specials.app_remove")
                onClicked: root.removeRequested()
            }
        }

        FieldRow {
            label: I18n.t("specials.app_match")
            TextControl {
                objectName: "appMatch"
                Layout.fillWidth: true
                monospace: true
                text: root.app.match || ""
                placeholder: "org.telegram.desktop"
                onEdited: t => root.edited({
                        "match": t.trim()
                    })
            }
        }
        FieldRow {
            label: I18n.t("specials.app_command")
            TextControl {
                objectName: "appCommand"
                Layout.fillWidth: true
                monospace: true
                text: root.app.command || ""
                placeholder: I18n.t("specials.app_command_none")
                onEdited: t => root.edited({
                        "command": t.trim()
                    })
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Space.m
            KitText {
                role: "caption"
                text: I18n.t("specials.if_running")
                color: Colors.overSurfaceVariant
            }
            SelectorControl {
                objectName: "appIfRunning"
                options: [
                    {
                        "value": "nothing",
                        "label": "specials.if_running.nothing"
                    },
                    {
                        "value": "move",
                        "label": "specials.if_running.move"
                    }
                ]
                value: root.app.ifRunning || "nothing"
                onSelected: v => root.edited({
                        "ifRunning": v
                    })
            }
            Item {
                Layout.fillWidth: true
            }
            KitText {
                role: "caption"
                text: I18n.t("specials.app_rule")
                color: Colors.overSurfaceVariant
            }
            ToggleControl {
                objectName: "appRule"
                checked: root.app.rule === true
                Accessible.name: I18n.t("specials.app_rule")
                onToggled: v => root.edited({
                        "rule": v
                    })
            }
        }
    }

    component FieldRow: RowLayout {
        id: fieldRow
        property string label: ""
        Layout.fillWidth: true
        spacing: Space.m
        KitText {
            role: "caption"
            Layout.preferredWidth: 130
            text: fieldRow.label
            color: Colors.overSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
