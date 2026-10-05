pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common

// Selection actions (popup near the cursor) and the prompt library.
ColumnLayout {
    id: root

    property var entry

    spacing: 10

    function edit(listName, index, fields) {
        const src = listName === "actions" ? Config.ai.selection.actions : Config.ai.prompts;
        const list = JSON.parse(JSON.stringify(src || []));
        if (index < 0)
            list.push(fields);
        else if (fields === null)
            list.splice(index, 1);
        else
            list[index] = Object.assign(list[index], fields);
        if (listName === "actions")
            Config.ai.selection.actions = list;
        else
            Config.ai.prompts = list;
    }

    Repeater {
        model: [
            {
                list: "actions",
                title: I18n.t("ai.selection_actions")
            },
            {
                list: "prompts",
                title: I18n.t("ai.prompt_library")
            }
        ]
        delegate: ColumnLayout {
            id: group
            required property var modelData
            readonly property var entries: group.modelData.list === "actions" ? (Config.ai.selection.actions || []) : (Config.ai.prompts || [])
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.topMargin: 6
                text: group.modelData.title
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                color: Colors.outline
            }

            Repeater {
                model: group.entries
                delegate: StyledRect {
                    id: item
                    required property var modelData
                    required property int index
                    property bool open: false
                    Layout.fillWidth: true
                    variant: "common"
                    radius: Styling.radius(-4)
                    implicitHeight: itemCol.implicitHeight + 12

                    ColumnLayout {
                        id: itemCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            IconButton {
                                glyph: item.open ? Icons.caretUp : Icons.caretDown
                                size: 24
                                onClicked: item.open = !item.open
                            }
                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.label || item.modelData.name || I18n.t("ai.action_" + item.modelData.id)
                                elide: Text.ElideRight
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overSurface
                            }
                            Text {
                                text: I18n.t("ai.output_" + (item.modelData.output || "default"))
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.outline
                            }
                            IconButton {
                                glyph: Icons.trash
                                danger: true
                                size: 24
                                onClicked: root.edit(group.modelData.list, item.index, null)
                            }
                        }
                        AiTextRow {
                            visible: item.open
                            label: I18n.t("ai.name")
                            value: item.modelData.label || item.modelData.name || ""
                            onEdited: t => root.edit(group.modelData.list, item.index, group.modelData.list === "actions" ? {
                                    label: t
                                } : {
                                    name: t
                                })
                        }
                        AiTextRow {
                            visible: item.open
                            label: I18n.t("ai.prompt") + " — {selection} {clipboard} {language} {date}"
                            value: item.modelData.prompt
                            multiline: true
                            onEdited: t => root.edit(group.modelData.list, item.index, {
                                    prompt: t
                                })
                        }
                        AiSelectRow {
                            visible: item.open
                            label: I18n.t("ai.output")
                            value: item.modelData.output || ""
                            options: (group.modelData.list === "actions" ? ["", "replace", "clipboard", "sidebar", "quickask"] : ["notify", "sidebar", "quickask", "clipboard"]).map(o => ({
                                        label: "ai.output_" + (o || "default"),
                                        value: o
                                    }))
                            onSelected: v => root.edit(group.modelData.list, item.index, {
                                    output: v
                                })
                        }
                    }
                }
            }

            Chip {
                glyph: Icons.plus
                label: group.modelData.list === "actions" ? I18n.t("ai.add_action") : I18n.t("ai.add_prompt")
                onClicked: root.edit(group.modelData.list, -1, group.modelData.list === "actions" ? {
                    id: "custom-" + Date.now(),
                    label: I18n.t("ai.new_action"),
                    icon: "sparkle",
                    output: "",
                    prompt: "{selection}"
                } : {
                    id: "p-" + Date.now(),
                    name: I18n.t("ai.new_prompt"),
                    prompt: "",
                    output: "sidebar"
                })
            }
        }
    }
}
