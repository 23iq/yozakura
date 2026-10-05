pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.editors.keybinds
import "../../Ui.js" as Ui

// One special workspace in settings (and in the onboarding step): name
// (the Hyprland name follows, safely), icon, accent, its toggle and
// "send window here" binds (the keybinds recorder: clashes with every other
// bind are shown live), preload and its apps. Emits whole-item patches.
Item {
    id: root

    property var item: ({})
    property string hyprName: ""
    property int windows: 0
    property bool expanded: false
    property string problem: ""

    signal patched(var patch)
    signal appAdded(var app)
    signal appPatched(int index, var patch)
    signal appRemoved(int index)
    signal removeRequested

    readonly property color tint: Colors[item.accent] ?? Colors.primary

    objectName: "specialCard:" + (item.id || "")
    implicitHeight: body.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(4), 22)
        color: Ui.alpha(Colors.overBackground, 0.035)
        border.width: 1
        border.color: root.expanded ? Ui.alpha(root.tint, 0.55) : Ui.alpha(Colors.outlineVariant, 0.8)
    }

    ColumnLayout {
        id: body
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Math.min(Styling.radius(0), 14)
                color: Ui.alpha(root.tint, 0.2)
                Text {
                    anchors.centerIn: parent
                    text: Icons[root.item.icon] || Icons.stack
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: root.tint
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                TextControl {
                    objectName: "specialName"
                    Layout.fillWidth: true
                    text: root.item.name || ""
                    invalid: root.problem !== ""
                    placeholder: I18n.t("specials.name_placeholder")
                    onEdited: t => root.patched({
                            "name": t.trim()
                        })
                }
                Text {
                    Layout.fillWidth: true
                    text: root.problem !== "" ? root.problem : I18n.t("specials.summary", "special:" + root.hyprName, root.windows, (root.item.apps || []).length)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    color: root.problem !== "" ? Colors.error : Colors.overSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            PillButton {
                objectName: "specialExpand"
                kind: "ghost"
                icon: root.expanded ? "caretUp" : "caretDown"
                text: I18n.t(root.expanded ? "specials.less" : "specials.edit")
                onClicked: root.expanded = !root.expanded
            }
            PillButton {
                kind: "ghost"
                icon: "trash"
                text: ""
                implicitWidth: 34
                Accessible.name: I18n.t("specials.remove")
                onClicked: root.removeRequested()
            }
        }

        // Binds are always visible: they are what makes a special useful.
        BindRow {
            label: I18n.t("specials.toggle_bind")
            role: "toggle"
        }
        BindRow {
            label: I18n.t("specials.send_bind")
            role: "send"
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 12

            Labeled {
                label: I18n.t("specials.icon")
                GlyphPicker {
                    width: parent.width
                    value: root.item.icon || "stack"
                    accent: root.item.accent || "primary"
                    onPicked: icon => root.patched({
                            "icon": icon
                        })
                }
            }
            Labeled {
                label: I18n.t("specials.accent")
                AccentPicker {
                    value: root.item.accent || "primary"
                    onPicked: role => root.patched({
                            "accent": role
                        })
                }
            }
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: I18n.t("specials.preload")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overBackground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: I18n.t("specials.preload.desc")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.overSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
                ToggleControl {
                    objectName: "specialPreload"
                    checked: root.item.preload === true
                    Accessible.name: I18n.t("specials.preload")
                    onToggled: v => root.patched({
                            "preload": v
                        })
                }
            }

            Labeled {
                label: I18n.t("specials.apps")
                Column {
                    id: appsColumn
                    width: parent.width
                    spacing: 8
                    Text {
                        visible: (root.item.apps || []).length === 0
                        width: parent.width
                        text: I18n.t("specials.apps_empty")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: root.item.apps || []
                        delegate: SpecialAppRow {
                            required property var modelData
                            required property int index
                            width: appsColumn.width
                            app: modelData
                            onEdited: patch => root.appPatched(index, patch)
                            onRemoveRequested: root.appRemoved(index)
                        }
                    }
                    AppPicker {
                        width: parent.width
                        onPicked: app => root.appAdded(app)
                    }
                }
            }
        }
    }

    // One bind of the special (role "toggle" | "send"): the keybinds
    // recorder, so clashes with every other bind show while recording.
    component BindRow: RowLayout {
        id: bindRow
        property string label: ""
        property string role: ""
        readonly property var combo: root.item[role] || ({
                "modifiers": [],
                "key": ""
            })
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.preferredWidth: 150
            Layout.alignment: Qt.AlignTop
            topPadding: 8
            text: bindRow.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
            wrapMode: Text.WordWrap
        }
        KeyRecorder {
            objectName: bindRow.role + "Recorder"
            Layout.fillWidth: true
            combo: bindRow.combo
            exceptUid: "special:" + root.item.id + ":" + bindRow.role
            removable: !!bindRow.combo.key
            onCommitted: k => {
                const patch = {};
                patch[bindRow.role] = k;
                root.patched(patch);
            }
            onRemoved: {
                const patch = {};
                patch[bindRow.role] = {
                    "modifiers": [],
                    "key": ""
                };
                root.patched(patch);
            }
        }
    }

    component Labeled: Column {
        property string label: ""
        Layout.fillWidth: true
        spacing: 4
        Text {
            text: parent.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-3)
            font.weight: Font.Bold
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
            color: Colors.overSurfaceVariant
        }
    }
}
