pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config
import qs.modules.aicenter.common
import qs.modules.settings.editors.keybinds
import "../../services/ai/Cron.js" as Cron
import "../../services/ai/Automations.js" as Logic

// Prompt automations: schedule (cron), login briefing, finished transfers,
// copied text matching a regex, new screenshots. The "routine" output runs
// a saved routine instead of a prompt.
ColumnLayout {
    id: root

    property var entry

    spacing: 10

    readonly property var items: (Config.ai.automations || []).map(a => Logic.normalize(a))

    function patch(index, fields) {
        const list = JSON.parse(JSON.stringify(Config.ai.automations || []));
        const cur = Logic.normalize(list[index]);
        if (fields.trigger)
            fields.trigger = Object.assign({}, cur.trigger, fields.trigger);
        list[index] = Object.assign(cur, fields);
        Config.ai.automations = list;
    }

    function add() {
        const list = JSON.parse(JSON.stringify(Config.ai.automations || []));
        list.push({
            id: "auto-" + Date.now(),
            name: I18n.t("ai.new_automation"),
            enabled: false,
            trigger: {
                type: "schedule",
                cron: "0 9 * * 1-5",
                pattern: "",
                kinds: []
            },
            prompt: "",
            model: "",
            output: "notify",
            offer: false
        });
        Config.ai.automations = list;
    }

    function remove(index) {
        const list = JSON.parse(JSON.stringify(Config.ai.automations || []));
        list.splice(index, 1);
        Config.ai.automations = list;
    }

    Repeater {
        model: root.items
        delegate: StyledRect {
            id: card
            required property var modelData
            required property int index
            property bool open: false
            Layout.fillWidth: true
            variant: "common"
            radius: Styling.radius(-2)
            implicitHeight: autoCol.implicitHeight + 16

            ColumnLayout {
                id: autoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    IconButton {
                        glyph: card.open ? Icons.caretUp : Icons.caretDown
                        size: 24
                        onClicked: card.open = !card.open
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: card.modelData.name || card.modelData.id
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.DemiBold
                            color: Colors.overSurface
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: I18n.t("ai.trigger_" + card.modelData.trigger.type) + (card.modelData.trigger.type === "schedule" ? " · " + card.modelData.trigger.cron : "") + " → " + I18n.t("ai.output_" + card.modelData.output)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            color: Colors.outline
                        }
                    }
                    IconButton {
                        glyph: Icons.trash
                        danger: true
                        size: 24
                        tooltip: I18n.t("ai.delete")
                        onClicked: root.remove(card.index)
                    }
                    AiToggleRow {
                        Layout.fillWidth: false
                        checked: card.modelData.enabled
                        onToggled: v => root.patch(card.index, {
                                enabled: v
                            })
                    }
                }

                ColumnLayout {
                    visible: card.open
                    Layout.fillWidth: true
                    spacing: 8
                    AiTextRow {
                        label: I18n.t("ai.name")
                        value: card.modelData.name
                        onEdited: t => root.patch(card.index, {
                                name: t
                            })
                    }
                    AiSelectRow {
                        label: I18n.t("ai.trigger")
                        value: card.modelData.trigger.type
                        options: ["schedule", "login", "transfer", "clipboard", "screenshot"].map(t => ({
                                    label: "ai.trigger_" + t,
                                    value: t
                                }))
                        onSelected: v => root.patch(card.index, {
                                trigger: {
                                    type: v
                                }
                            })
                    }
                    AiTextRow {
                        visible: card.modelData.trigger.type === "schedule"
                        label: I18n.t("ai.cron") + (Cron.valid(card.modelData.trigger.cron) ? "" : " · " + I18n.t("ai.invalid"))
                        value: card.modelData.trigger.cron
                        placeholder: "0 9 * * 1-5"
                        mono: true
                        onEdited: t => root.patch(card.index, {
                                trigger: {
                                    cron: t.trim()
                                }
                            })
                    }
                    AiTextRow {
                        visible: card.modelData.trigger.type === "clipboard"
                        label: I18n.t("ai.regex") + (Logic.validPattern(card.modelData.trigger.pattern) ? "" : " · " + I18n.t("ai.invalid"))
                        value: card.modelData.trigger.pattern
                        mono: true
                        onEdited: t => root.patch(card.index, {
                                trigger: {
                                    pattern: t
                                }
                            })
                    }
                    AiTextRow {
                        visible: card.modelData.output !== "routine"
                        label: I18n.t("ai.prompt") + " — {selection} {clipboard} {date} {time} {file} {input}"
                        value: card.modelData.prompt
                        multiline: true
                        onEdited: t => root.patch(card.index, {
                                prompt: t
                            })
                    }
                    AiSelectRow {
                        label: I18n.t("ai.output")
                        value: card.modelData.output
                        options: ["notify", "quickask", "sidebar", "clipboard", "routine"].map(o => ({
                                    label: "ai.output_" + (o),
                                    value: o
                                }))
                        onSelected: v => root.patch(card.index, {
                                output: v
                            })
                    }
                    Text {
                        visible: card.modelData.output === "routine"
                        text: I18n.t("routines.automation_pick")
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    RoutinePickerField {
                        objectName: "automationRoutine"
                        visible: card.modelData.output === "routine"
                        Layout.fillWidth: true
                        routineId: card.modelData.routine
                        onPicked: id => root.patch(card.index, {
                                routine: id
                            })
                    }
                    AiToggleRow {
                        label: I18n.t("ai.offer_first")
                        checked: card.modelData.offer
                        onToggled: v => root.patch(card.index, {
                                offer: v
                            })
                    }
                }
            }
        }
    }

    Chip {
        glyph: Icons.plus
        label: I18n.t("ai.add_automation")
        onClicked: root.add()
    }
}
