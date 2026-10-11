import QtQuick
import "KeyedSync.js" as KeyedSync

// A ListModel that follows a list of unique string `keys` by inserts,
// removals and moves (KeyedSync.ops), so a ListView over it animates rows in
// and out (its add / remove / displaced transitions) instead of rebuilding.
// Each row has one role, `key`; the view looks the data up by it.
ListModel {
    id: root

    property var keys: []

    function sync() {
        const now = [];
        for (let i = 0; i < root.count; i++)
            now.push(root.get(i).key);
        const edits = KeyedSync.ops(now, (root.keys || []).map(k => String(k)));
        for (const e of edits) {
            if (e.op === "remove")
                root.remove(e.at, 1);
            else if (e.op === "move")
                root.move(e.from, e.to, 1);
            else
                root.insert(e.at, {
                    "key": e.key
                });
        }
    }

    onKeysChanged: root.sync()
    Component.onCompleted: root.sync()
}
