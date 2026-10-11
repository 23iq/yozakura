.pragma library

// Edit operations that turn the key list `from` into `to` (unique string
// keys): removals first (from the end), then moves and inserts in target
// order. Applied in sequence to a ListModel they give its views real
// add / remove / move transitions instead of a model reset.
// [{op: "remove", at}, {op: "move", from, to}, {op: "insert", at, key}]
// Unit tested in tests/keyed-sync.test.cjs.

function ops(from, to) {
    var cur = (from || []).slice();
    var want = to || [];
    var keep = {};
    var out = [];
    var i;
    for (i = 0; i < want.length; i++)
        keep[want[i]] = true;
    for (i = cur.length - 1; i >= 0; i--) {
        if (keep[cur[i]] !== true) {
            out.push({ op: "remove", at: i });
            cur.splice(i, 1);
        }
    }
    for (i = 0; i < want.length; i++) {
        if (cur[i] === want[i])
            continue;
        var idx = cur.indexOf(want[i], i + 1);
        if (idx >= 0) {
            out.push({ op: "move", from: idx, to: i });
            cur.splice(i, 0, cur.splice(idx, 1)[0]);
        } else {
            out.push({ op: "insert", at: i, key: want[i] });
            cur.splice(i, 0, want[i]);
        }
    }
    return out;
}

// `ops` applied to a plain array (the tests check ops against it).
function apply(list, edits) {
    var cur = (list || []).slice();
    for (var i = 0; i < edits.length; i++) {
        var e = edits[i];
        if (e.op === "remove")
            cur.splice(e.at, 1);
        else if (e.op === "move")
            cur.splice(e.to, 0, cur.splice(e.from, 1)[0]);
        else
            cur.splice(e.at, 0, e.key);
    }
    return cur;
}
