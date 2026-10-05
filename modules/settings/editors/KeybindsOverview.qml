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
import "keybinds"

// Keybinds toolbar: search across all groups (names, actions, apps, keys
// like "super e": BindModel.filterRows), add a bind (KeybindAddDialog:
// keys, then the action; it lands in its action's group), reload from
// disk, the conflict chip (click: show only the conflicting binds), the
// cheatsheet shortcut and the empty state of a search.
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
                anchors.rightMargin: 36
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

            // Clear the search
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text !== ""
                text: Icons.cancel
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: KeybindsStore.editorQuery = ""
                }
            }

            // Modal: lives in the window's overlay, not in this layout.
            KeybindAddDialog {
                id: addDialog
                onSaved: uid => KeybindsStore.expandedUid = ""
            }
        }

        PillButton {
            objectName: "keybindsAdd"
            icon: "plus"
            kind: "filled"
            text: I18n.t("binds.add_keybind")
            onClicked: addDialog.open()
        }

        PillButton {
            id: reloadButton
            icon: "arrowsClockwise"
            kind: "ghost"
            text: ""
            implicitWidth: implicitHeight
            onClicked: KeybindsStore.reload()
            Accessible.name: I18n.t("binds.reload_binds")
            HoverHandler {
                id: reloadHover
            }
            StyledToolTip {
                show: reloadHover.hovered
                tooltipText: I18n.t("binds.reload_binds")
            }
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

        // Conflicts: click to list only them (and back).
        Rectangle {
            objectName: "keybindsConflicts"
            visible: KeybindsStore.conflictCount > 0 || KeybindsStore.conflictFilter
            height: conflictRow.implicitHeight + 10
            width: conflictRow.implicitWidth + 20
            radius: height / 2
            color: Ui.alpha(Colors.error, KeybindsStore.conflictFilter ? 0.26 : (conflictArea.containsMouse ? 0.2 : 0.14))
            border.width: KeybindsStore.conflictFilter ? 1 : 0
            border.color: Colors.error

            Row {
                id: conflictRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: KeybindsStore.conflictFilter ? Icons.xCircle : Icons.warning
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(-1)
                    color: Colors.error
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: KeybindsStore.conflictFilter ? I18n.t("binds.conflicts_show_all") : I18n.t("binds.conflicts_count", KeybindsStore.conflictCount)
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    font.weight: Font.DemiBold
                    color: Colors.error
                }
            }
            MouseArea {
                id: conflictArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: KeybindsStore.conflictFilter = !KeybindsStore.conflictFilter
            }
        }
    }

    // Search results: how many, or nothing found.
    Text {
        objectName: "keybindsMatchCount"
        Layout.fillWidth: true
        visible: KeybindsStore.filtering && KeybindsStore.visibleAll.length > 0
        text: I18n.t("binds.match_count", KeybindsStore.visibleAll.length)
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        color: Colors.overSurfaceVariant
    }

    ColumnLayout {
        objectName: "keybindsEmpty"
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: KeybindsStore.filtering && KeybindsStore.visibleAll.length === 0
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Icons.magnifyingGlass
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(8)
            color: Colors.outline
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: KeybindsStore.editorQuery.trim() !== "" ? I18n.t("binds.no_matches_for", KeybindsStore.editorQuery.trim()) : I18n.t("binds.no_matches")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            font.weight: Font.DemiBold
            color: Colors.overBackground
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.t("binds.no_matches_hint")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            color: Colors.overSurfaceVariant
        }
        PillButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            icon: "plus"
            text: I18n.t("binds.add_keybind")
            onClicked: addDialog.open()
        }
    }

    Component.onCompleted: KeybindsStore.refreshNative()
}
