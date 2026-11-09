pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.components.kit
import "PromptsEdit.js" as PromptsEdit

// Selection actions (popup near the cursor) and the prompt library.
ColumnLayout {
    id: root

    property var entry

    spacing: Space.m

    // ref: {id, index} of the item (null = append)
    function edit(listName, ref, fields) {
        const src = listName === "actions" ? Config.ai.selection.actions : Config.ai.prompts;
        const list = PromptsEdit.apply(src, ref, fields);
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
            spacing: Space.s

            KitText {
                role: "caption"
                Layout.topMargin: Space.s
                text: group.modelData.title
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }

            Repeater {
                model: group.entries
                delegate: StyledRect {
                    id: item
                    required property var modelData
                    required property int index
                    property bool open: false
                    readonly property var ref: ({
                            id: item.modelData.id || "",
                            index: item.index
                        })
                    Layout.fillWidth: true
                    variant: "common"
                    radius: Look.radius("control")
                    implicitHeight: itemCol.implicitHeight + 12

                    ColumnLayout {
                        id: itemCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Space.s
                        spacing: Space.s
                        RowLayout {
                            Layout.fillWidth: true
                            IconButton {
                                icon: item.open ? Icons.caretUp : Icons.caretDown
                                size: "xs"
                                onClicked: item.open = !item.open
                            }
                            KitText {
                                role: "secondary"
                                Layout.fillWidth: true
                                text: item.modelData.label || item.modelData.name || I18n.t("ai.action_" + item.modelData.id)
                                elide: Text.ElideRight
                                color: Colors.overSurface
                            }
                            KitText {
                                role: "caption"
                                text: I18n.t("ai.output_" + (item.modelData.output || "default"))
                            }
                            IconButton {
                                icon: Icons.trash
                                danger: true
                                size: "xs"
                                onClicked: root.edit(group.modelData.list, item.ref, null)
                            }
                        }
                        AiTextRow {
                            visible: item.open
                            label: I18n.t("ai.name")
                            value: item.modelData.label || item.modelData.name || ""
                            onEdited: t => root.edit(group.modelData.list, item.ref, group.modelData.list === "actions" ? {
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
                            onEdited: t => root.edit(group.modelData.list, item.ref, {
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
                            onSelected: v => root.edit(group.modelData.list, item.ref, {
                                    output: v
                                })
                        }
                    }
                }
            }

            Chip {
                icon: Icons.plus
                text: group.modelData.list === "actions" ? I18n.t("ai.add_action") : I18n.t("ai.add_prompt")
                onClicked: root.edit(group.modelData.list, null, group.modelData.list === "actions" ? {
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
