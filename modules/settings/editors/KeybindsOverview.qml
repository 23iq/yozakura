pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings
import "keybinds"
import qs.modules.components.kit

// Keybinds toolbar: search across all groups (names, actions, apps, keys
// like "super e": BindModel.filterRows), add a bind (KeybindAddDialog:
// keys, then the action; it lands in its action's group), reload from
// disk, the conflict chip (click: show only the conflicting binds), the
// cheatsheet shortcut and the empty state of a search.
ColumnLayout {
    id: root

    property var entry

    readonly property var cheatsheet: KeybindsStore.row("core:system.keybinds")

    spacing: Space.m

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.m

        SearchField {
            id: search
            objectName: "keybindsSearch"
            Layout.fillWidth: true
            boxed: true
            text: KeybindsStore.editorQuery
            placeholderText: I18n.t("binds.search_placeholder")
            trailing: clearComponent
            // Escape clears through the store: the field's own clear()
            // would assign the text and break the binding above.
            clearOnEscape: false
            onSearchTextChanged: t => KeybindsStore.editorQuery = t
            onEscapePressed: KeybindsStore.editorQuery = ""

            // Modal: lives in the window's overlay, not in this layout.
            KeybindAddDialog {
                id: addDialog
                onSaved: uid => KeybindsStore.expandedUid = ""
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Space.m

        PillButton {
            objectName: "keybindsAdd"
            icon: "plus"
            kind: "filled"
            text: I18n.t("binds.add_keybind")
            onClicked: addDialog.open()
        }

        IconButton {
            icon: Icons.arrowsClockwise
            size: "s"
            focusable: true
            tooltip: I18n.t("binds.reload_binds")
            onClicked: KeybindsStore.reload()
            Accessible.name: I18n.t("binds.reload_binds")
        }
    }

    // Clears the search (inside the field, while it has text).
    Component {
        id: clearComponent
        IconButton {
            visible: search.text !== ""
            icon: Icons.cancel
            size: "xs"
            onClicked: KeybindsStore.editorQuery = ""
        }
    }

    // Cheatsheet shortcut + conflicts
    Flow {
        Layout.fillWidth: true
        spacing: Space.m

        Row {
            spacing: Space.s
            visible: !!root.cheatsheet && root.cheatsheet.enabled
            KitText {
                role: "caption"
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("binds.cheatsheet.open_with")
            }
            KeyCombo {
                anchors.verticalCenter: parent.verticalCenter
                modifiers: root.cheatsheet ? root.cheatsheet.keys[0].modifiers : []
                key: root.cheatsheet ? root.cheatsheet.keys[0].key : ""
            }
        }

        // Conflicts: click to list only them (and back).
        Chip {
            objectName: "keybindsConflicts"
            visible: KeybindsStore.conflictCount > 0 || KeybindsStore.conflictFilter
            danger: true
            dense: true
            active: KeybindsStore.conflictFilter
            icon: KeybindsStore.conflictFilter ? Icons.xCircle : Icons.warning
            text: KeybindsStore.conflictFilter ? I18n.t("binds.conflicts_show_all") : I18n.t("binds.conflicts_count", KeybindsStore.conflictCount)
            onClicked: KeybindsStore.conflictFilter = !KeybindsStore.conflictFilter
        }
    }

    // Search results: how many, or nothing found.
    KitText {
        objectName: "keybindsMatchCount"
        role: "caption"
        Layout.fillWidth: true
        visible: KeybindsStore.filtering && KeybindsStore.visibleAll.length > 0
        text: I18n.t("binds.match_count", KeybindsStore.visibleAll.length)
    }

    ColumnLayout {
        objectName: "keybindsEmpty"
        Layout.fillWidth: true
        Layout.topMargin: Space.s
        Layout.bottomMargin: Space.s
        visible: KeybindsStore.filtering && KeybindsStore.visibleAll.length === 0
        spacing: Space.s

        Icon {
            role: "title"
            tone: "muted"
            Layout.alignment: Qt.AlignHCenter
            icon: Icons.magnifyingGlass
        }
        KitText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: KeybindsStore.editorQuery.trim() !== "" ? I18n.t("binds.no_matches_for", KeybindsStore.editorQuery.trim()) : I18n.t("binds.no_matches")
            font.weight: Font.DemiBold
        }
        KitText {
            role: "caption"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.t("binds.no_matches_hint")
        }
        PillButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Space.xs
            icon: "plus"
            text: I18n.t("binds.add_keybind")
            onClicked: addDialog.open()
        }
    }

    Component.onCompleted: KeybindsStore.refreshNative()

    // in a card taller than the toolbar: the toolbar stays at the top
    Item {
        Layout.fillHeight: true
    }
}
