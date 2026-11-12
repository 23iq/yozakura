.pragma library

.import "JsonUtil.js" as JsonUtil

// Three-way merge of one config domain (ConfigFile.qml). Two processes may
// edit the same <domain>.json (the main shell and a separate Settings /
// wizard window, or the `config set` CLI): a process that writes its whole
// adapter would drop what another one wrote since it last read the file.
// Instead, what this process changed since it last read or wrote the file
// (local vs base) is laid over the file as it is now. Paths go down plain
// objects (nested JsonObjects, free-form maps); arrays are values.
// Tested in tests/config-merge.test.cjs.

function isQObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v) && v.objectName !== undefined;
}

function isMap(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// The adapter as plain JSON, shaped by the domain defaults (the adapter
// has exactly the keys of its defaults; nested JsonObjects are recursed).
function serialize(adapter, defaults) {
    var out = {};
    if (!adapter || !defaults)
        return out;
    var keys = Object.keys(defaults);
    for (var i = 0; i < keys.length; i++) {
        var v = adapter[keys[i]];
        if (isQObject(v))
            out[keys[i]] = serialize(v, isMap(defaults[keys[i]]) ? defaults[keys[i]] : {});
        else
            out[keys[i]] = JsonUtil.clone(v);
    }
    return out;
}

// What local changed against base: [{path, value}] (value undefined: the
// key was removed). Only local's own top-level keys are compared (keys the
// file has and the adapter does not are not this process's to drop).
function changes(base, local) {
    var out = [];
    walk(isMap(base) ? base : {}, isMap(local) ? local : {}, [], out, true);
    return out;
}

function walk(base, local, path, out, top) {
    var keys = Object.keys(local);
    if (!top) {
        var bk = Object.keys(base);
        for (var j = 0; j < bk.length; j++)
            if (keys.indexOf(bk[j]) === -1)
                keys.push(bk[j]);
    }
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var b = base[k], l = local[k];
        if (JsonUtil.deepEqual(b, l))
            continue;
        if (isMap(b) && isMap(l))
            walk(b, l, path.concat([k]), out, false);
        else
            out.push({
                "path": path.concat([k]),
                "value": l
            });
    }
}

// A deep copy of obj with path set to value (undefined: removed).
function withPath(obj, path, value) {
    if (path.length === 0)
        return JsonUtil.clone(value);
    var copy = isMap(obj) ? JsonUtil.clone(obj) : {};
    var cur = copy;
    for (var i = 0; i < path.length - 1; i++) {
        if (!isMap(cur[path[i]]))
            cur[path[i]] = {};
        cur = cur[path[i]];
    }
    var last = path[path.length - 1];
    if (value === undefined)
        delete cur[last];
    else
        cur[last] = JsonUtil.clone(value);
    return copy;
}

// Sets path on a live adapter: nested JsonObjects are assigned in place, a
// plain value on the way (a free-form map) is replaced by an updated copy.
// A removed property of a JsonObject itself is left alone.
function assign(adapter, path, value) {
    var target = adapter;
    var i = 0;
    while (i < path.length - 1 && isQObject(target[path[i]])) {
        target = target[path[i]];
        i++;
    }
    if (!target)
        return;
    if (i === path.length - 1) {
        if (value !== undefined)
            target[path[i]] = JsonUtil.clone(value);
        return;
    }
    target[path[i]] = withPath(target[path[i]], path.slice(i + 1), value);
}
