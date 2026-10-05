import QtQuick

// ListModel of {uid} kept in sync with a list of ids by minimal
// insert/move/remove, so views keep their delegates (and their state:
// expanded rows, focus, animations) across edits instead of rebuilding.
ListModel {
    id: root

    function sync(uids) {
        for (let i = root.count - 1; i >= 0; i--) {
            if (uids.indexOf(root.get(i).uid) === -1)
                root.remove(i);
        }
        for (let i = 0; i < uids.length; i++) {
            if (i < root.count && root.get(i).uid === uids[i])
                continue;
            let from = -1;
            for (let k = i + 1; k < root.count; k++) {
                if (root.get(k).uid === uids[i]) {
                    from = k;
                    break;
                }
            }
            if (from >= 0)
                root.move(from, i, 1);
            else
                root.insert(i, {
                    "uid": uids[i]
                });
        }
    }
}
