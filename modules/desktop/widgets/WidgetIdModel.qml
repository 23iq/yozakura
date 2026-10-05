import QtQuick

// Stable model of widget ids for Repeaters: sync() only appends new ids and
// removes gone ones, so editing one widget (drag, option, note text) never
// recreates the others (their state, histories and focus survive).
ListModel {
    id: root

    function sync(ids) {
        const want = {};
        ids.forEach(id => want[id] = true);
        for (let i = root.count - 1; i >= 0; i--) {
            if (!want[root.get(i).wid])
                root.remove(i);
        }
        const have = {};
        for (let j = 0; j < root.count; j++)
            have[root.get(j).wid] = true;
        ids.forEach(id => {
            if (!have[id])
                root.append({
                    wid: id
                });
        });
    }
}
