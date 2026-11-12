.pragma library

.import "../../config/JsonUtil.js" as JsonUtil

// Writing one dotted key (`<domain>.<prop>[.<sub>...]`) into the Config
// singleton, the way the settings window does it (SettingsStore.set). The
// main shell runs the same function on the staged values a separate Settings
// window relays (PreviewSink.qml), so a preview is applied exactly as an
// in-process edit. SchemaUtil.js re-exports the path helpers.
// Tested in tests/config-write.test.cjs.

function splitKey(key) {
    var parts = String(key).split(".");
    return {
        "domain": parts[0],
        "prop": parts[1],
        "path": parts.slice(1)
    };
}

// JsonAdapter hands lists to JS as list wrappers; normalize to plain JSON.
function plain(value) {
    if (value === undefined || value === null)
        return value;
    if (typeof value !== "object")
        return value;
    try {
        return JSON.parse(JSON.stringify(value));
    } catch (e) {
        return value;
    }
}

function getPath(obj, path) {
    var cur = obj;
    for (var i = 0; i < path.length; i++) {
        if (cur === undefined || cur === null)
            return undefined;
        cur = cur[path[i]];
    }
    return cur;
}

// Returns a deep copy of `obj` with `path` set to `value` (used for nested
// keys inside `property var` objects such as bar.layout.style).
function withPath(obj, path, value) {
    if (path.length === 0)
        return plain(value);
    var copy = plain(obj);
    if (copy === undefined || copy === null || typeof copy !== "object")
        copy = {};
    var cur = copy;
    for (var i = 0; i < path.length - 1; i++) {
        if (cur[path[i]] === undefined || cur[path[i]] === null || typeof cur[path[i]] !== "object")
            cur[path[i]] = {};
        cur = cur[path[i]];
    }
    cur[path[path.length - 1]] = plain(value);
    return copy;
}

function equal(a, b) {
    return JsonUtil.deepEqual(plain(a), plain(b));
}

// Sets `key` on `config` (the Config singleton or a stand-in). Nested
// JsonObject children (e.g. ai.quickAsk.enabled) are assigned in place; a
// `property var` object on the way is replaced by an updated copy (e.g.
// bar.layout.style). `stage(domain)`, when given, runs before the write
// (the GlobalStates snapshot of a staged domain). Returns the domain name,
// or "" when the config has no such domain.
function assign(config, key, value, stage) {
    var k = splitKey(key);
    var domain = config ? config[k.domain] : null;
    if (!domain || k.path.length === 0)
        return "";
    var target = domain;
    var i = 0;
    while (i < k.path.length - 1) {
        var child = target[k.path[i]];
        if (!child || typeof child !== "object" || Array.isArray(child) || child.objectName === undefined)
            break;
        target = child;
        i++;
    }
    if (stage)
        stage(k.domain);
    if (i === k.path.length - 1)
        target[k.path[i]] = plain(value);
    else
        target[k.path[i]] = withPath(target[k.path[i]], k.path.slice(i + 1), value);
    return k.domain;
}
