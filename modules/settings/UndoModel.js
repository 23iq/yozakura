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

function keysOf(changes) {
    return changes.map(function (c) {
        return c.key;
    });
}

// Every key of `a` is in `b`.
function within(a, b) {
    var keys = keysOf(b);
    return keysOf(a).every(function (k) {
        return keys.indexOf(k) !== -1;
    });
}

// Two steps edit the same thing: one's keys hold the other's (the same
// setting again; a macro slider whose points move one key more or less).
function sameKeys(a, b) {
    return within(a, b) || within(b, a);
}

// Adds a finished step to `stack`. A step right after a step with the same
// label and the same keys (sameKeys: one setting dragged, a macro slider
// moved over several points) merges into it; a step (or a merge) that changes nothing
// in the end is not kept. `step.id` names a new step; a merge keeps the id
// of the step it merged into.
// Returns {stack (a new array), outcome, step}: outcome "added" (step: the
// new step), "merged" (step: the merged step), "cancelled" (a merge that
// ended where it began removed the step `id`: step = {id}) or "none"
// (nothing to record; stack unchanged).
function pushResult(stack, step, now, equal) {
    var out = (stack || []).slice();
    var changes = (step.changes || []).slice();
    if (changes.length === 0)
        return {
            "stack": out,
            "outcome": "none",
            "step": null
        };
    var top = out.length > 0 ? out[out.length - 1] : null;
    if (top && top.label === step.label && sameKeys(top.changes, changes) && now - top.time < COALESCE_MS) {
        var merged = top.changes;
        for (var i = 0; i < changes.length; i++)
            merged = addChange(merged, changes[i].key, changes[i].before, changes[i].after);
        out.pop();
        merged = effective(merged, equal);
        if (merged.length === 0)
            return {
                "stack": out,
                "outcome": "cancelled",
                "step": {
                    "id": top.id
                }
            };
        var m = {
            "id": top.id,
            "label": top.label,
            "changes": merged,
            "time": now
        };
        out.push(m);
        return {
            "stack": out,
            "outcome": "merged",
            "step": m
        };
    }
    changes = effective(changes, equal);
    if (changes.length === 0)
        return {
            "stack": out,
            "outcome": "none",
            "step": null
        };
    var added = {
        "id": step.id,
        "label": step.label,
        "changes": changes,
        "time": now
    };
    out.push(added);
    while (out.length > LIMIT)
        out.shift();
    return {
        "stack": out,
        "outcome": "added",
        "step": added
    };
}

// pushResult's stack alone.
function push(stack, step, now, equal) {
    return pushResult(stack, step, now, equal).stack;
}

// Every change of `step` still holds `field` ("after": the step can be
// undone; "before": it can be redone) by `get(key)`. A key `skip(key)`
// says to trust (its value is not known synchronously) is not checked.
function holds(step, field, get, equal, skip) {
    return step.changes.every(function (c) {
        return (skip && skip(c.key)) || equal(get(c.key), c[field]);
    });
}

// The history still matches the config (an external reload changed none
// of its keys): for every key the newest undo step that touches it ends at
// the current value, and the next redo step that touches it starts there.
// `only(key)` limits the check (the keys of one reloaded domain).
function consistent(undoStack, redoStack, get, equal, only) {
    var seen = {};
    var ok = true;
    function check(list, field) {
        for (var i = list.length - 1; i >= 0 && ok; i--) {
            list[i].changes.forEach(function (c) {
                if (!ok || seen[field + c.key] || (only && !only(c.key)))
                    return;
                seen[field + c.key] = true;
                if (!equal(get(c.key), c[field]))
                    ok = false;
            });
        }
    }
    check(undoStack || [], "after");
    check(redoStack || [], "before");
    return ok;
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
