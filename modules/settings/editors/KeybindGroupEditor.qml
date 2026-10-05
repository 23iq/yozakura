pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.keybinds
import qs.modules.settings.store
import qs.config
import "keybinds"
import "../../keybinds/BindModel.js" as BindModel
import "../../../config/KeybindActions.js" as KeybindActions

// The binds of one group (`entry.group`, a BindModel.GROUPS id): one
// KeybindRow each, filtered by the toolbar search, plus "add" with the
// group's first action.
ColumnLayout {
    id: root

    property var entry
    readonly property string groupId: entry ? entry.group : ""
    readonly property var rows: BindModel.filterRows(KeybindsStore.rows.filter(r => r.group === root.groupId), KeybindsStore.editorQuery, KeybindsStore.tr)
    readonly property var firstAction: KeybindActions.getActionOptions().find(o => o.group === root.groupId)

    spacing: 6

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
        text: KeybindsStore.editorQuery !== "" ? I18n.t("binds.no_matches") : I18n.t("binds.group_empty")
        font.family: Config.theme.font
        font.pixelSize: Styling.fontSize(-2)
        font.italic: true
        color: Colors.outline
    }

    AddLink {
        visible: !!root.firstAction
        text: I18n.t("binds.add_to_group")
        onClicked: KeybindsStore.expandedUid = KeybindsStore.addCustom(root.firstAction.id)
    }
}
