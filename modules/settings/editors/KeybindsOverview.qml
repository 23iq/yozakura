pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.config
import qs.modules.settings
import "../Ui.js" as Ui

// Keybinds toolbar: search across all groups, add a custom bind, the
// cheatsheet shortcut, the conflict summary and a reload from disk.
ColumnLayout {
    id: root

    property var entry

    readonly property var cheatsheet: KeybindsStore.row("core:system.keybinds")

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Item {
            Layout.fillWidth: true
            implicitHeight: 38

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Ui.alpha(Colors.overBackground, search.activeFocus ? 0.1 : 0.06)
                border.width: search.activeFocus ? 2 : 0
                border.color: Colors.primary
            }
            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.search
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
            TextInput {
                id: search
                objectName: "keybindsSearch"
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: KeybindsStore.editorQuery
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overBackground
                selectionColor: Ui.alpha(Colors.primary, 0.4)
                clip: true
                onTextEdited: KeybindsStore.editorQuery = text
                Keys.onEscapePressed: KeybindsStore.editorQuery = ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text === ""
                    text: I18n.t("binds.search_placeholder")
                    font: parent.font
                    color: Colors.outline
                }
            }
        }

        PillButton {
            objectName: "keybindsAdd"
            icon: "plus"
            kind: "filled"
            text: I18n.t("binds.add_keybind")
            onClicked: KeybindsStore.expandedUid = KeybindsStore.addCustom("command.run")
        }

        PillButton {
            icon: "arrowsClockwise"
            kind: "ghost"
            text: I18n.t("binds.reload_binds")
            onClicked: KeybindsStore.reload()
        }
    }

    // Cheatsheet shortcut + conflicts
    Flow {
        Layout.fillWidth: true
        spacing: 10

        Row {
            spacing: 8
            visible: !!root.cheatsheet && root.cheatsheet.enabled
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("binds.cheatsheet.open_with")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }
            KeyCombo {
                anchors.verticalCenter: parent.verticalCenter
                modifiers: root.cheatsheet ? root.cheatsheet.keys[0].modifiers : []
                key: root.cheatsheet ? root.cheatsheet.keys[0].key : ""
            }
        }

        Rectangle {
            visible: KeybindsStore.conflictCount > 0
            height: conflictRow.implicitHeight + 10
            width: conflictRow.implicitWidth + 20
            radius: height / 2
            color: Ui.alpha(Colors.error, 0.14)

            Row {
                id: conflictRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.warning
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.error
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("binds.conflicts_count", KeybindsStore.conflictCount)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.DemiBold
                    color: Colors.error
                }
            }
        }
    }

    Component.onCompleted: KeybindsStore.refreshNative()
}
