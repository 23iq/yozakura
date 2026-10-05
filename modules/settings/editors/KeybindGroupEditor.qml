pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings.store
import qs.config
import "keybinds"

// The binds of one group (`entry.group`, a BindModel.GROUPS id): one
// compact KeybindRow each, filtered by the toolbar (search, conflicts).
ColumnLayout {
    id: root

    property var entry
    readonly property string groupId: entry ? entry.group : ""
    readonly property var rows: {
        KeybindsStore.rows;
        KeybindsStore.conflicts;
        return KeybindsStore.visibleRows(root.groupId);
    }

    spacing: 2

    onRowsChanged: rowModel.sync(rows.map(r => r.uid))

    UidListModel {
        id: rowModel
        Component.onCompleted: sync(root.rows.map(r => r.uid))
    }

    function openPending() {
        const uid = KeybindsStore.pendingEdit;
        const r = uid ? KeybindsStore.row(uid) : null;
        if (!r || r.group !== root.groupId)
            return;
        KeybindsStore.pendingEdit = "";
        KeybindsStore.editorQuery = "";
        KeybindsStore.conflictFilter = false;
        KeybindsStore.expandedUid = uid;
        SettingsStore.navigate("input", root.groupId, "binds." + root.groupId);
    }

    Component.onCompleted: Qt.callLater(openPending)

    Connections {
        target: KeybindsStore
        function onEditRequested() {
            root.openPending();
        }
    }

    Repeater {
        model: rowModel
        delegate: KeybindRow {
            required property string uid
            Layout.fillWidth: true
            bind: KeybindsStore.row(uid) || KeybindsStore.emptyRow
        }
    }

    Text {
        visible: root.rows.length === 0
        Layout.fillWidth: true
        topPadding: 4
        bottomPadding: 4
        text: KeybindsStore.editorQuery !== "" || KeybindsStore.conflictFilter ? I18n.t("binds.no_matches") : I18n.t("binds.group_empty")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.italic: true
        color: Colors.outline
    }
}
