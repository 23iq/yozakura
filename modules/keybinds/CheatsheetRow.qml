pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.keybinds
import "KeyNames.js" as KeyNames

// One bind in the cheatsheet: a kit ListRow with what it does and its
// combos as KeyHints (merged rows stack them), a conflict marker and an
// "edit in settings" button on hover / keyboard selection. Double-click
// edits too.
ListRow {
    id: root

    required property var bind
    readonly property bool conflicted: (bind.uids || [bind.uid]).some(u => KeybindsStore.conflictsOf(u).length > 0)

    signal editRequested(string uid)

    title: KeybindsStore.title(root.bind)
    implicitHeight: Math.max(Space.controlS, root.bind.keys.length * (Space.keyHint + Space.xs) + Space.s)
    opacity: root.bind.enabled ? 1 : 0.45

    onDoubleClicked: root.editRequested(root.bind.uid)

    trailing: Component {
        Row {
            spacing: Space.s

            Text {
                visible: root.conflicted
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.warning
                font.family: Icons.font
                font.pixelSize: Type.iconSize("caption")
                color: Colors.error
            }

            IconButton {
                id: edit
                anchors.verticalCenter: parent.verticalCenter
                size: "s"
                icon: Icons.pencil
                width: Space.keyHint + Space.xs * 2
                height: width
                opacity: root.hovered || root.highlighted || edit.hovered ? 1 : 0
                onClicked: root.editRequested(root.bind.uid)

                StyledToolTip {
                    show: edit.hovered
                    tooltipText: I18n.t("binds.edit_in_settings")
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs

                Repeater {
                    model: root.bind.keys
                    delegate: Row {
                        id: combo
                        required property var modelData
                        x: parent ? parent.width - width : 0
                        spacing: Space.xs

                        Repeater {
                            model: KeyNames.hints(combo.modelData.modifiers, combo.modelData.key)
                            delegate: KeyHint {
                                required property var modelData
                                text: modelData.text
                                icon: modelData.icon !== "" ? (Icons[modelData.icon] ?? "") : ""
                            }
                        }

                        KitText {
                            visible: combo.modelData.key === ""
                            role: "caption"
                            font.italic: true
                            text: I18n.t("binds.not_set")
                        }
                    }
                }
            }
        }
    }
}
