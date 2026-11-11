import QtQuick
import "../../components/kit/KeyedSync.js" as KeyedSync

// One row per window, keyed by its address, for the Repeater that draws the
// window previews. The compositor pushes the whole window list on every
// event (a title change; a terminal spinner sends several per second), and a
// Repeater over that array rebuilds every preview each time: a preview
// destroyed between press and release loses the click, one destroyed while
// dragged drops the drag. Here a row lives as long as its window (rows
// follow the list by KeyedSync edits, as the kit's KeyedListModel does).
//
// Roles: `key` (the address) and `rows` (this model), so a delegate reads its
// window as `rows.byKey[key]` from required properties alone, without an
// outer id (not every file here is ComponentBehavior: Bound).
ListModel {
    id: root

    // What to show, rebuilt on every event.
    property var items: []
    // The window address of an item.
    property var keyOf: item => item.address
    // key -> item
    property var byKey: ({})

    function rebuild() {
        const map = {};
        const order = [];
        for (const item of root.items || []) {
            const key = String(root.keyOf(item) ?? "");
            if (key === "" || map[key] !== undefined)
                continue;
            map[key] = item;
            order.push(key);
        }
        const now = [];
        for (let i = 0; i < root.count; i++)
            now.push(root.get(i).key);
        // Rows of closed windows go before their data does, new rows come
        // once theirs is there: a delegate never sees a missing item.
        const edits = KeyedSync.ops(now, order);
        for (const e of edits) {
            if (e.op === "remove")
                root.remove(e.at, 1);
        }
        root.byKey = map;
        for (const e of edits) {
            if (e.op === "move")
                root.move(e.from, e.to, 1);
            else if (e.op === "insert")
                root.insert(e.at, {
                    "key": e.key,
                    "rows": root
                });
        }
    }

    onItemsChanged: root.rebuild()
    Component.onCompleted: root.rebuild()
}
