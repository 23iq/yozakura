pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.displays
import "../Ui.js" as Ui
import "../../services/KeyboardModel.js" as KeyboardModel

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
            width: root.width
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
        height: 68
        Rectangle {
            x: 20
            width: parent.width - 40
            height: 1
            color: Ui.alpha(Colors.outlineVariant, 0.45)
        }
        PillButton {
            objectName: "allOptionsButton"
            x: 20
            y: 17
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

        Text {
            x: 20
            visible: root.groups.length === 0
            text: I18n.t("prefs.keyboard.loading")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overSurfaceVariant
            bottomPadding: 20
        }

        Repeater {
            model: root.groups
            delegate: Column {
                id: group
                required property var modelData
                readonly property bool open: root.openGroup === group.modelData.name
                readonly property int on: root.enabledIn(group.modelData)
                width: allList.width

                Item {
                    width: parent.width
                    height: 46
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        radius: Styling.radius(1)
                        color: headArea.containsMouse ? Ui.alpha(Colors.overBackground, 0.06) : "transparent"
                    }
                    Text {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 150
                        text: group.modelData.description
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.DemiBold
                        color: Colors.overBackground
                    }
                    Rectangle {
                        visible: group.on > 0
                        anchors.right: caret.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: countLabel.implicitWidth + 14
                        height: 20
                        radius: 10
                        color: Ui.alpha(Colors.primary, 0.22)
                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: I18n.tn("prefs.keyboard.n_on", group.on)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-3)
                            font.weight: Font.DemiBold
                            color: Colors.primary
                        }
                    }
                    Text {
                        id: caret
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.open ? Icons.caretUp : Icons.caretDown
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(0)
                        color: Colors.overSurfaceVariant
                    }
                    MouseArea {
                        id: headArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openGroup = group.open ? "" : group.modelData.name
                    }
                }

                Repeater {
                    model: group.open ? group.modelData.options : []
                    delegate: Item {
                        id: opt
                        required property var modelData
                        width: group.width
                        height: 44
                        Text {
                            x: 40
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 130
                            text: opt.modelData.description
                            elide: Text.ElideRight
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                        }
                        Text {
                            anchors.right: optToggle.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: opt.modelData.name
                            visible: parent.width > 600
                            font.family: "monospace"
                            font.pixelSize: Styling.fontSize(-3)
                            color: Ui.alpha(Colors.overSurfaceVariant, 0.7)
                        }
                        ToggleControl {
                            id: optToggle
                            objectName: "opt:" + opt.modelData.name
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            checked: KeyboardModel.hasOption(root.options, opt.modelData.name)
                            onToggled: v => root.optionToggled(opt.modelData.name, v)
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 12
        }
    }
}
