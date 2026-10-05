pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.services
import qs.modules.keybinds
import qs.config
import "keybinds"
import "../Ui.js" as Ui

// The binds of one group (`entry.group`, a BindModel.GROUPS id): one
// compact KeybindRow each, filtered by the toolbar (search, conflicts).
// A group without (matching) binds hides its whole card; the toolbar shows
// the empty state. A bind just added or moved here is scrolled into view.
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

    // The SettingsSection card around this editor.
    function sectionItem() {
        for (let p = root.parent; p; p = p.parent) {
            if (String(p.objectName).indexOf("settingsSection:") === 0)
                return p;
        }
        return null;
    }

    function rowItem(uid) {
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (Ui.prop(it, "uid") === uid)
                return it;
        }
        return null;
    }

    // Scroll the page to the row (SettingsPage.revealItem).
    function revealRow(uid) {
        const item = root.rowItem(uid);
        if (!item)
            return false;
        for (let p = root.parent; p; p = p.parent) {
            if (typeof Ui.prop(p, "revealItem") === "function") {
                Ui.invoke(p, "revealItem", [item]);
                return true;
            }
        }
        return false;
    }

    function openPending() {
        const uid = KeybindsStore.pendingEdit;
        const r = uid ? KeybindsStore.row(uid) : null;
        if (!r || r.group !== root.groupId)
            return;
        KeybindsStore.pendingEdit = "";
        KeybindsStore.expandedUid = uid;
        KeybindsStore.reveal(uid);
    }

    Component.onCompleted: {
        const s = root.sectionItem();
        if (s)
            s.visible = Qt.binding(() => root.rows.length > 0);
        Qt.callLater(openPending);
    }

    Connections {
        target: KeybindsStore
        function onEditRequested() {
            root.openPending();
        }
        function onRevealRequested(uid) {
            const r = KeybindsStore.row(uid);
            if (r && r.group === root.groupId) {
                revealTimer.pass = 0;
                revealTimer.interval = 120;
                revealTimer.restart();
            }
        }
    }

    // After the row list laid out, and once more after an opened editor
    // finished growing.
    Timer {
        id: revealTimer
        property int pass: 0
        interval: 120
        onTriggered: {
            if (KeybindsStore.highlightUid !== "")
                root.revealRow(KeybindsStore.highlightUid);
            if (++pass < 2) {
                interval = Math.max(120, Config.animDuration + 60);
                start();
            } else {
                interval = 120;
            }
        }
    }

    Repeater {
        id: repeater
        model: rowModel
        delegate: KeybindRow {
            required property string uid
            Layout.fillWidth: true
            bind: KeybindsStore.row(uid) || KeybindsStore.emptyRow
        }
    }
}
