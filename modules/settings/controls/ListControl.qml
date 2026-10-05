pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import "../Ui.js" as Ui
import "../SchemaUtil.js" as SchemaUtil

// Array editor for `type: "list"` entries.
//   * `fields` [{key, type: text|number|selector|path|toggle, label,
//     placeholder, min, max, step, unit, options, pattern, pathKind, filter,
//     flex}]: one card per object item, fields laid out in a wrapping row;
//   * `itemType` "text" | "path": a list of strings, one row each.
// Items can be added (`newItem`, `addLabel`), removed and reordered.
// `changed(list)` carries the whole new array.
Item {
    id: root

    property var entry: ({})
    property var items: []
    signal changed(var items)

    readonly property var fields: entry.fields || []
    readonly property bool objects: fields.length > 0
    readonly property string itemType: entry.itemType || "text"

    implicitWidth: 480
    implicitHeight: column.implicitHeight

    function edit(index, field, value) {
        root.changed(SchemaUtil.listSet(root.items, index, field, value));
    }

    Column {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            id: repeater
            model: root.items ? root.items.length : 0

            delegate: Item {
                id: card
                required property int index
                readonly property var item: root.items[card.index]
                width: column.width
                height: cardBody.implicitHeight + (root.objects ? 24 : 0)
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.objects
                    radius: Math.min(Styling.radius(2), 18)
                    color: Ui.alpha(Colors.overBackground, 0.045)
                    border.width: 1
                    border.color: Ui.alpha(Colors.outlineVariant, 0.6)
                }

                Column {
                    id: cardBody
                    x: root.objects ? 14 : 0
                    y: root.objects ? 12 : 0
                    width: parent.width - (root.objects ? 28 : 0)
                    spacing: 10

                    // Title + reorder/remove (object items)
                    Item {
                        width: parent.width
                        height: 28
                        visible: root.objects

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.entry.itemLabel ? I18n.t(root.entry.itemLabel, card.index + 1) : "#" + (card.index + 1)
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.DemiBold
                            color: Colors.primary
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            ListIconButton {
                                icon: "caretUp"
                                enabled: card.index > 0
                                label: I18n.t("prefs.common.move_up")
                                onClicked: root.changed(SchemaUtil.listMove(root.items, card.index, card.index - 1))
                            }
                            ListIconButton {
                                icon: "caretDown"
                                enabled: card.index < root.items.length - 1
                                label: I18n.t("prefs.common.move_down")
                                onClicked: root.changed(SchemaUtil.listMove(root.items, card.index, card.index + 1))
                            }
                            ListIconButton {
                                icon: "trash"
                                danger: true
                                label: I18n.t("prefs.common.remove")
                                onClicked: root.changed(SchemaUtil.listRemove(root.items, card.index))
                            }
                        }
                    }

                    // Fields of an object item
                    Flow {
                        width: parent.width
                        spacing: 12
                        visible: root.objects

                        Repeater {
                            model: root.objects ? root.fields : []
                            delegate: Column {
                                id: fieldBox
                                required property var modelData
                                readonly property var value: card.item ? card.item[fieldBox.modelData.key] : undefined
                                readonly property bool wide: fieldBox.modelData.type === "text" || fieldBox.modelData.type === "path"
                                width: fieldBox.wide ? Math.max(200, (cardBody.width + 12) * (fieldBox.modelData.flex ?? 1) - 12) : implicitWidth
                                spacing: 4

                                Text {
                                    text: I18n.t(fieldBox.modelData.label)
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    color: Colors.overSurfaceVariant
                                }
                                Loader {
                                    width: fieldBox.wide ? fieldBox.width : implicitWidth
                                    sourceComponent: {
                                        switch (fieldBox.modelData.type) {
                                        case "number":
                                            return numberField;
                                        case "selector":
                                            return selectorField;
                                        case "toggle":
                                            return toggleField;
                                        case "path":
                                            return pathField;
                                        }
                                        return textField;
                                    }

                                    Component {
                                        id: textField
                                        TextControl {
                                            text: fieldBox.value ?? ""
                                            monospace: !!fieldBox.modelData.monospace
                                            placeholder: fieldBox.modelData.placeholder ? I18n.t(fieldBox.modelData.placeholder) : ""
                                            invalid: !SchemaUtil.matchesPattern(fieldBox.modelData, input.text)
                                            onEdited: t => {
                                                if (SchemaUtil.matchesPattern(fieldBox.modelData, t))
                                                    root.edit(card.index, fieldBox.modelData.key, t);
                                            }
                                        }
                                    }
                                    Component {
                                        id: numberField
                                        NumberControl {
                                            value: Number(fieldBox.value ?? fieldBox.modelData.min ?? 0)
                                            from: fieldBox.modelData.min
                                            to: fieldBox.modelData.max
                                            stepSize: fieldBox.modelData.step ?? 1
                                            unit: fieldBox.modelData.unit ?? ""
                                            implicitWidth: 150
                                            onChanged: v => root.edit(card.index, fieldBox.modelData.key, v)
                                        }
                                    }
                                    Component {
                                        id: selectorField
                                        SelectorControl {
                                            options: fieldBox.modelData.options
                                            value: fieldBox.value
                                            onSelected: v => root.edit(card.index, fieldBox.modelData.key, v)
                                        }
                                    }
                                    Component {
                                        id: toggleField
                                        ToggleControl {
                                            checked: !!fieldBox.value
                                            onToggled: v => root.edit(card.index, fieldBox.modelData.key, v)
                                        }
                                    }
                                    Component {
                                        id: pathField
                                        PathControl {
                                            path: fieldBox.value ?? ""
                                            pathKind: fieldBox.modelData.pathKind ?? "file"
                                            filter: fieldBox.modelData.filter ?? ""
                                            placeholder: fieldBox.modelData.placeholder ? I18n.t(fieldBox.modelData.placeholder) : ""
                                            onEdited: p => root.edit(card.index, fieldBox.modelData.key, p)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // A string item (itemType text/path)
                    Row {
                        width: parent.width
                        spacing: 6
                        visible: !root.objects

                        Loader {
                            width: parent.width - stringRemove.width - parent.spacing
                            active: !root.objects
                            sourceComponent: root.itemType === "path" ? stringPath : stringText
                            Component {
                                id: stringText
                                TextControl {
                                    text: card.item ?? ""
                                    monospace: !!root.entry.monospace
                                    placeholder: root.entry.placeholder ? I18n.t(root.entry.placeholder) : ""
                                    onEdited: t => root.edit(card.index, "", t)
                                }
                            }
                            Component {
                                id: stringPath
                                PathControl {
                                    path: card.item ?? ""
                                    pathKind: root.entry.pathKind ?? "dir"
                                    clearable: false
                                    placeholder: root.entry.placeholder ? I18n.t(root.entry.placeholder) : ""
                                    onEdited: p => root.edit(card.index, "", p)
                                }
                            }
                        }
                        ListIconButton {
                            id: stringRemove
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "trash"
                            danger: true
                            label: I18n.t("prefs.common.remove")
                            onClicked: root.changed(SchemaUtil.listRemove(root.items, card.index))
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: (root.items ? root.items.length : 0) === 0 && !!root.entry.emptyLabel
            text: root.entry.emptyLabel ? I18n.t(root.entry.emptyLabel) : ""
            wrapMode: Text.WordWrap
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.italic: true
            color: Colors.overSurfaceVariant
        }

        PillButton {
            objectName: "listAdd"
            icon: "plus"
            text: I18n.t(root.entry.addLabel || "common.add")
            onClicked: root.changed(SchemaUtil.listInsert(root.items, SchemaUtil.newListItem(root.entry)))
        }
    }

    component ListIconButton: Item {
        id: btn
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked
        width: 30
        height: 30
        opacity: enabled ? 1 : 0.3
        activeFocusOnTab: true
        Keys.onSpacePressed: btn.clicked()
        Accessible.role: Accessible.Button
        Accessible.name: btn.label

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btnArea.containsMouse ? Ui.alpha(btn.danger ? Colors.error : Colors.overBackground, 0.14) : "transparent"
            border.width: btn.activeFocus ? 2 : 0
            border.color: Colors.primary
        }
        Text {
            anchors.centerIn: parent
            text: Icons[btn.icon] ?? ""
            font.family: Icons.font
            font.pixelSize: 15
            color: btn.danger && btnArea.containsMouse ? Colors.error : Colors.overSurfaceVariant
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
