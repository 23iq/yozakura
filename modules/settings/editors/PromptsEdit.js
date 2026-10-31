.pragma library

// Pure edits of the AI selection-action / prompt lists. Items are addressed
// by their stable `id` (a Repeater index goes stale as soon as another item
// is deleted); an item without an id falls back to its index. An edit or
// delete aimed at an item that no longer exists is a no-op, never a write to
// whichever item moved into its slot.

function indexOf(list, ref) {
    if (ref && ref.id) {
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].id === ref.id)
                return i;
        return -1;
    }
    const i = ref ? ref.index : -1;
    return i >= 0 && i < list.length ? i : -1;
}

// ref === null appends `fields`; fields === null removes; otherwise merges.
function apply(src, ref, fields) {
    const list = JSON.parse(JSON.stringify(src || []));
    if (ref === null) {
        list.push(fields);
        return list;
    }
    const i = indexOf(list, ref);
    if (i < 0)
        return list;
    if (fields === null)
        list.splice(i, 1);
    else
        list[i] = Object.assign(list[i], fields);
    return list;
}
