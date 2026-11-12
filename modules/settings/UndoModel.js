.pragma library

// The session undo history of the settings window (SettingsStore). Every
// change applies at once; this keeps what it replaced so Ctrl+Z / the undo
// pill can bring it back. Pure, node-tested (tests/settings-undo.test.cjs).
//
// A step: {label, changes: [{key, before, after}], time}. `label` is an i18n
// key (the entry's label, or a transaction's own label such as Reset page).
// `equal(a, b)` is SchemaUtil.equal (values are plain JSON).

// Steps kept per session; the oldest fall off.
var LIMIT = 60;
// Changes of the same setting closer than this merge into one step: a
// slider drag, a text typed key by key, a stepper clicked five times.
var COALESCE_MS = 1500;

function copy(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
}

// `changes` with key changed from `before` to `after`: a key already in the
// list keeps its first `before` and takes the new `after`.
function addChange(changes, key, before, after) {
    var out = (changes || []).slice();
    for (var i = 0; i < out.length; i++) {
        if (out[i].key === key) {
            out[i] = {
                "key": key,
                "before": out[i].before,
                "after": copy(after)
            };
            return out;
        }
    }
    out.push({
        "key": key,
        "before": copy(before),
        "after": copy(after)
    });
    return out;
}

// Changes whose value ended where it started are dropped.
function effective(changes, equal) {
    return (changes || []).filter(function (c) {
        return !equal(c.before, c.after);
    });
}

function sameKeys(a, b) {
    if (a.length !== b.length)
        return false;
    for (var i = 0; i < a.length; i++) {
        if (a[i].key !== b[i].key)
            return false;
    }
    return true;
}

// Adds a finished step to `stack` (a new array). A single-setting step right
// after a step of the same setting and label merges into it; a step (or a
// merge) that changes nothing in the end is not kept.
function push(stack, step, now, equal) {
    var out = (stack || []).slice();
    var changes = effective(step.changes, function () {
        return false;
    });
    if (changes.length === 0)
        return out;
    var top = out.length > 0 ? out[out.length - 1] : null;
    if (top && top.label === step.label && changes.length === 1 && sameKeys(top.changes, changes) && now - top.time < COALESCE_MS) {
        var merged = addChange(top.changes, changes[0].key, changes[0].before, changes[0].after);
        out.pop();
        merged = effective(merged, equal);
        if (merged.length > 0)
            out.push({
                "label": top.label,
                "changes": merged,
                "time": now
            });
        return out;
    }
    changes = effective(changes, equal);
    if (changes.length === 0)
        return out;
    out.push({
        "label": step.label,
        "changes": changes,
        "time": now
    });
    while (out.length > LIMIT)
        out.shift();
    return out;
}

// What applying a step backwards writes: [{key, value}] in reverse order.
function reverted(step) {
    var out = [];
    for (var i = step.changes.length - 1; i >= 0; i--)
        out.push({
            "key": step.changes[i].key,
            "value": copy(step.changes[i].before)
        });
    return out;
}

// What applying it again writes.
function replayed(step) {
    return step.changes.map(function (c) {
        return {
            "key": c.key,
            "value": copy(c.after)
        };
    });
}

// key -> i18n label of the entry that edits it, from the schema: an entry's
// `key`, every key it lists in `keys`, first entry wins.
function labelIndex(categories) {
    var out = {};
    (categories || []).forEach(function (cat) {
        (cat.sections || []).forEach(function (sec) {
            (sec.entries || []).forEach(function (e) {
                if (!e.label)
                    return;
                var keys = (e.key ? [e.key] : []).concat(e.keys || []);
                keys.forEach(function (k) {
                    if (!out[k])
                        out[k] = e.label;
                });
            });
        });
    });
    return out;
}

// The label of `key`: its own entry's, else the nearest parent key's
// (bar.layout.left -> bar.layout), else "".
function labelFor(index, key) {
    var k = String(key || "");
    while (k !== "") {
        if (index[k])
            return index[k];
        var dot = k.lastIndexOf(".");
        k = dot > 0 ? k.substring(0, dot) : "";
    }
    return "";
}
