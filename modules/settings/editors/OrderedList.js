.pragma library

// Pure edits of an ordered pick list (OrderedListEditor.qml): an array of
// choice values, in order. Tested by tests/ordered-list.test.cjs.

function _known(list, values) {
    var out = [];
    (Array.isArray(list) ? list : []).forEach(function (v) {
        if (values.indexOf(v) !== -1 && out.indexOf(v) === -1)
            out.push(v);
    });
    return out;
}

// Rows to show: [{value, on}] - the chosen ones in their order, then the
// rest of `values` (off when `subset`, appended on when the list must
// rank every value).
function rows(list, values, subset) {
    var on = _known(list, values);
    var out = on.map(function (v) {
        return {
            "value": v,
            "on": true
        };
    });
    values.forEach(function (v) {
        if (on.indexOf(v) === -1)
            out.push({
                "value": v,
                "on": !subset
            });
    });
    return out;
}

// The list with `value` moved by `delta` among the chosen ones.
function move(list, values, subset, value, delta) {
    var cur = rows(list, values, subset).filter(function (r) {
        return r.on;
    }).map(function (r) {
        return r.value;
    });
    var from = cur.indexOf(value);
    var to = from + delta;
    if (from === -1 || to < 0 || to >= cur.length)
        return cur;
    cur.splice(from, 1);
    cur.splice(to, 0, value);
    return cur;
}

// The list with `value` switched on (appended) or off (removed).
function toggle(list, values, value, on) {
    var cur = _known(list, values).filter(function (v) {
        return v !== value;
    });
    if (on && values.indexOf(value) !== -1)
        cur.push(value);
    return cur;
}
