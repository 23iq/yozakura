pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.displays
import "../../services/KeyboardModel.js" as KeyboardModel
import qs.modules.components.kit

// How layouts switch and the common XKB options. "All options" folds out the
// whole catalog by group. `options` is the user list (without the switch bind).
KeyboardCard {
    id: root

    property string switchBind: "alt_shift"
    property var options: []
    property var catalog: null
    property bool showAll: false
    property string openGroup: ""

    signal bindPicked(string bind)
    signal optionToggled(string name, bool on)

    readonly property var groups: KeyboardModel.groupOptions(catalog)
    readonly property var bindChoices: ["alt_shift", "super_space", "caps", "ctrl_shift", "none"].map(b => ({
                "value": b,
                "label": I18n.t("prefs.keyboard.bind." + b)
            }))
    readonly property var quick: [
        {
            "name": "caps:escape",
            "key": "caps_escape"
        },
        {
            "name": "ctrl:nocaps",
            "key": "ctrl_nocaps"
        },
        {
            "name": "compose:ralt",
            "key": "compose_ralt"
        }
    ]

    function enabledIn(group) {
        return group.options.filter(o => KeyboardModel.hasOption(options, o.name)).length;
    }

    icon: "keyboard"
    title: I18n.t("prefs.keyboard.switching")
    subtitle: I18n.t("prefs.keyboard.switching.desc")

    DisplayRow {
        width: parent.width
        separator: false
        label: I18n.t("prefs.keyboard.switch")
        hint: I18n.t("prefs.keyboard.switch.desc")
        KeyChips {
            objectName: "bindChips"
            width: parent.width
            options: root.bindChoices
            value: root.switchBind
            onSelected: v => root.bindPicked(v)
        }
    }

    Repeater {
        model: root.quick
        delegate: DisplayRow {
            id: quickRow
            required property var modelData
            width: parent.width
            label: I18n.t("prefs.keyboard.opt." + quickRow.modelData.key)
            hint: I18n.t("prefs.keyboard.opt." + quickRow.modelData.key + ".desc")
            ToggleControl {
                objectName: "quick:" + quickRow.modelData.name
                anchors.right: parent.right
                checked: KeyboardModel.hasOption(root.options, quickRow.modelData.name)
                onToggled: v => root.optionToggled(quickRow.modelData.name, v)
            }
        }
    }

    // All options expander
    Item {
        width: parent.width
        height: Space.controlL
        Divider {
            x: Look.rowInset
            width: parent.width - Look.rowInset * 2
        }
        PillButton {
            objectName: "allOptionsButton"
            x: Look.rowInset
            anchors.verticalCenter: parent.verticalCenter
            kind: "ghost"
            icon: root.showAll ? "caretUp" : "caretDown"
            text: I18n.t("prefs.keyboard.all_options")
            onClicked: {
                root.showAll = !root.showAll;
                if (root.showAll)
                    KeyboardService.loadCatalog();
            }
        }
    }

    Column {
        id: allList
        objectName: "allOptions"
        width: parent.width
        visible: root.showAll

        KitText {
            role: "secondary"
            x: Look.rowInset
            visible: root.groups.length === 0
            text: I18n.t("prefs.keyboard.loading")
            bottomPadding: Space.xl
        }

        Repeater {
            model: root.groups
            delegate: Column {
                id: group
                required property var modelData
                readonly property bool open: root.openGroup === group.modelData.name
                readonly property int on: root.enabledIn(group.modelData)
                width: allList.width

                // Group header: name, how many of its options are on, caret.
                ListRow {
                    id: head
                    x: Look.rowInset
                    width: parent.width - Look.rowInset * 2
                    title: group.modelData.description
                    highlighted: group.open
                    trailing: Component {
                        Row {
                            spacing: Space.m
                            KitText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: group.on > 0
                                role: "caption"
                                text: I18n.tn("prefs.keyboard.n_on", group.on)
                                font.weight: Font.DemiBold
                                color: Type.accent
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                tone: "secondary"
                                icon: group.open ? Icons.caretUp : Icons.caretDown
                            }
                        }
                    }
                    onClicked: root.openGroup = group.open ? "" : group.modelData.name
                }

                Repeater {
                    model: group.open ? group.modelData.options : []
                    delegate: ListRow {
                        id: opt
                        required property var modelData
                        x: Look.rowInset + Space.l
                        width: group.width - x - Look.rowInset
                        title: opt.modelData.description
                        trailing: Component {
                            Row {
                                spacing: Space.m
                                KitText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: opt.width > 600
                                    role: "caption"
                                    text: opt.modelData.name
                                    font.family: Type.monoFont
                                    color: Type.muted
                                }
                                ToggleControl {
                                    objectName: "opt:" + opt.modelData.name
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: KeyboardModel.hasOption(root.options, opt.modelData.name)
                                    onToggled: v => root.optionToggled(opt.modelData.name, v)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: Space.m
        }
    }
}
