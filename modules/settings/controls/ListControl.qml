pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.components.kit
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
        spacing: Space.s

        Repeater {
            id: repeater
            model: root.items ? root.items.length : 0

            delegate: Item {
                id: card
                required property int index
                readonly property var item: root.items[card.index]
                width: column.width
                height: cardBody.implicitHeight + (root.objects ? Space.m * 2 : 0)
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Motion.enter.easing
                    }
                }

                // An object item sits in the language's control box (a
                // hairline above it where controls are ghosts: ink).
                ControlBox {
                    shown: root.objects
                    radius: Look.chipRadius(Space.chip)
                }
                Divider {
                    width: parent.width
                    visible: root.objects && card.index > 0 && Look.controlFill(false).a === 0 && Look.dividers
                }

                Column {
                    id: cardBody
                    x: root.objects ? Space.m : 0
                    y: root.objects ? Space.m : 0
                    width: parent.width - (root.objects ? Space.m * 2 : 0)
                    spacing: Space.s

                    // Title + reorder/remove (object items)
                    Item {
                        width: parent.width
                        height: Space.controlS
                        visible: root.objects

                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.entry.itemLabel ? I18n.t(root.entry.itemLabel, card.index + 1) : "#" + (card.index + 1)
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            ListIconButton {
                                iconName: "caretUp"
                                enabled: card.index > 0
                                label: I18n.t("prefs.common.move_up")
                                onClicked: root.changed(SchemaUtil.listMove(root.items, card.index, card.index - 1))
                            }
                            ListIconButton {
                                iconName: "caretDown"
                                enabled: card.index < root.items.length - 1
                                label: I18n.t("prefs.common.move_down")
                                onClicked: root.changed(SchemaUtil.listMove(root.items, card.index, card.index + 1))
                            }
                            ListIconButton {
                                iconName: "trash"
                                label: I18n.t("prefs.common.remove")
                                onClicked: root.changed(SchemaUtil.listRemove(root.items, card.index))
                            }
                        }
                    }

                    // Fields of an object item
                    Flow {
                        width: parent.width
                        spacing: Space.m
                        visible: root.objects

                        Repeater {
                            model: root.objects ? root.fields : []
                            delegate: Column {
                                id: fieldBox
                                required property var modelData
                                readonly property var value: card.item ? card.item[fieldBox.modelData.key] : undefined
                                readonly property bool wide: fieldBox.modelData.type === "text" || fieldBox.modelData.type === "path"
                                width: fieldBox.wide ? Math.max(200, (cardBody.width + Space.m) * (fieldBox.modelData.flex ?? 1) - Space.m) : implicitWidth
                                spacing: Space.xs

                                KitText {
                                    role: "caption"
                                    text: I18n.t(fieldBox.modelData.label)
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
                        spacing: Space.xs
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
                            iconName: "trash"
                            label: I18n.t("prefs.common.remove")
                            onClicked: root.changed(SchemaUtil.listRemove(root.items, card.index))
                        }
                    }
                }
            }
        }

        KitText {
            width: parent.width
            visible: (root.items ? root.items.length : 0) === 0 && !!root.entry.emptyLabel
            role: "caption"
            text: root.entry.emptyLabel ? I18n.t(root.entry.emptyLabel) : ""
            wrapMode: Text.WordWrap
        }

        PillButton {
            objectName: "listAdd"
            icon: "plus"
            text: I18n.t(root.entry.addLabel || "common.add")
            onClicked: root.changed(SchemaUtil.listInsert(root.items, SchemaUtil.newListItem(root.entry)))
        }
    }

    // A quiet kit IconButton (Icons name) for move / remove.
    component ListIconButton: IconButton {
        property string iconName: ""
        property string label: ""
        size: "s"
        icon: Icons[iconName] ?? ""
        highlighted: activeFocus
        activeFocusOnTab: true
        Keys.onSpacePressed: clicked()
        Accessible.name: label
    }
}
