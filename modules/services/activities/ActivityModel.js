.pragma library

// Pure helpers behind ActivityService: config normalisation and the merge of
// every provider's activities into one sorted, de-duplicated list. No QML
// here so it is unit tested in tests/activities.test.cjs.
//
// An activity is a plain object:
//   id          unique, stable while the activity lives ("recording", "mic:firefox")
//   source      provider id ("recording", "privacy", "timers", ...)
//   category    "privacy" (sits right of the notch) | "task" (left)
//   priority    higher first (see PRIORITY)
//   icon        Phosphor glyph (Icons.*) shown when there is no image
//   image       optional icon/image URL (app icon)
//   indicator   "glyph" | "dot" (pulsing dot) | "ring" (progress ring)
//   label       short primary text (time, percent, app name)
//   detail      secondary text (tooltip, wide islands)
//   progress    0..1, or -1 when there is none
//   color       Colors role used for the accent ("error", "primary", ...)
//   startedAt   ms epoch, tie-breaker (older first)
//   action      descriptor handed back to the provider on click
//   dedupKey    optional; activities sharing it collapse to the best one

var PRIORITY = {
    recording: 100,
    screenShare: 90,
    camera: 80,
    microphone: 70,
    timer: 50,
    downloads: 40,
    progress: 30
};

var CATEGORIES = ["privacy", "task"];

var PRESENTATIONS = ["notch", "islands", "off"];

var DEFAULT_CONFIG = {
    enabled: true,
    presentation: "notch",
    maxVisible: 4,
    sources: {
        recording: true,
        privacy: true,
        timers: true,
        notificationProgress: true,
        jobView: true,
        browserDownloads: true,
        steam: true,
        terminal: true,
        fileOps: true,
        packages: true,
        torrents: true,
        aria2: true,
        syncthing: true,
        launchers: true
    },
    downloads: {
        aggregate: true,
        showSpeed: true,
        endpoints: {
            qbittorrent: "http://127.0.0.1:8080",
            transmission: "http://127.0.0.1:9091/transmission/rpc",
            deluge: "http://127.0.0.1:8112/json",
            aria2: "http://127.0.0.1:6800/jsonrpc",
            syncthing: ""
        },
        secrets: {
            qbittorrent: "",
            transmission: "",
            deluge: "deluge",
            aria2: ""
        }
    }
};

// JsonAdapter hands objects as QVariantMap and arrays as list wrappers;
// accept any array-like.
function toArray(value) {
    if (Array.isArray(value))
        return value;
    if (value && typeof value === "object" && typeof value.length === "number") {
        var out = [];
        for (var i = 0; i < value.length; i++)
            out.push(value[i]);
        return out;
    }
    return [];
}

function clampInt(value, min, max, fallback) {
    var n = Number(value);
    if (!isFinite(n))
        return fallback;
    return Math.max(min, Math.min(max, Math.round(n)));
}

function stringMap(src, defaults) {
    var out = {};
    var obj = src && typeof src === "object" ? src : {};
    for (var key in defaults)
        out[key] = obj[key] === undefined || obj[key] === null ? defaults[key] : String(obj[key]);
    for (var extra in obj)
        if (out[extra] === undefined && obj[extra] !== undefined && obj[extra] !== null)
            out[extra] = String(obj[extra]);
    return out;
}

function normalizeConfig(raw) {
    var src = raw && typeof raw === "object" ? raw : {};
    var sources = src.sources && typeof src.sources === "object" ? src.sources : {};
    var dl = src.downloads && typeof src.downloads === "object" ? src.downloads : {};
    var dd = DEFAULT_CONFIG.downloads;
    var out = {
        enabled: src.enabled === undefined ? DEFAULT_CONFIG.enabled : src.enabled === true,
        presentation: PRESENTATIONS.indexOf(src.presentation) !== -1 ? src.presentation : DEFAULT_CONFIG.presentation,
        maxVisible: clampInt(src.maxVisible, 1, 8, DEFAULT_CONFIG.maxVisible),
        sources: {},
        downloads: {
            aggregate: dl.aggregate === undefined ? dd.aggregate : dl.aggregate === true,
            showSpeed: dl.showSpeed === undefined ? dd.showSpeed : dl.showSpeed === true,
            endpoints: stringMap(dl.endpoints, dd.endpoints),
            secrets: stringMap(dl.secrets, dd.secrets)
        }
    };
    for (var key in DEFAULT_CONFIG.sources)
        out.sources[key] = sources[key] === undefined ? DEFAULT_CONFIG.sources[key] : sources[key] === true;
    return out;
}

// A provider is live when activities are on and its config source is on.
// Unknown source keys (third-party providers) default to enabled.
function sourceEnabled(raw, key) {
    var cfg = normalizeConfig(raw);
    if (!cfg.enabled || cfg.presentation === "off")
        return false;
    if (!key)
        return true;
    var sources = raw && raw.sources && typeof raw.sources === "object" ? raw.sources : {};
    if (cfg.sources[key] !== undefined)
        return cfg.sources[key];
    return sources[key] === undefined ? true : sources[key] === true;
}

function normalizeActivity(a, source) {
    if (!a || typeof a !== "object" || a.id === undefined || a.id === null || a.id === "")
        return null;
    var progress = Number(a.progress);
    return {
        id: String(a.id),
        source: String(a.source || source || ""),
        category: CATEGORIES.indexOf(a.category) !== -1 ? a.category : "task",
        priority: isFinite(Number(a.priority)) ? Number(a.priority) : 0,
        icon: a.icon || "",
        image: a.image || "",
        indicator: a.indicator === "dot" || a.indicator === "ring" ? a.indicator : "glyph",
        label: a.label === undefined || a.label === null ? "" : String(a.label),
        detail: a.detail === undefined || a.detail === null ? "" : String(a.detail),
        progress: isFinite(progress) && progress >= 0 ? Math.min(1, progress) : -1,
        color: a.color || "primary",
        startedAt: isFinite(Number(a.startedAt)) ? Number(a.startedAt) : 0,
        action: a.action === undefined ? "" : a.action,
        dedupKey: a.dedupKey ? String(a.dedupKey) : ""
    };
}

function compare(a, b) {
    if (b.priority !== a.priority)
        return b.priority - a.priority;
    if (a.startedAt !== b.startedAt)
        return a.startedAt - b.startedAt;
    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0);
}

// lists: [{ source, activities: [...] }, ...] or plain arrays of activities.
// Returns activities sorted by priority (then oldest first), unique by id
// and by dedupKey (the higher ranked one wins).
function aggregate(lists) {
    var all = [];
    var groups = toArray(lists);
    for (var g = 0; g < groups.length; g++) {
        var group = groups[g];
        var source = group && !Array.isArray(group) && group.source ? group.source : "";
        var items = toArray(group && group.activities !== undefined ? group.activities : group);
        for (var i = 0; i < items.length; i++) {
            var n = normalizeActivity(items[i], source);
            if (n)
                all.push(n);
        }
    }
    all.sort(compare);
    var seenIds = {};
    var seenKeys = {};
    var out = [];
    for (var j = 0; j < all.length; j++) {
        var a = all[j];
        if (seenIds[a.id])
            continue;
        if (a.dedupKey && seenKeys[a.dedupKey])
            continue;
        seenIds[a.id] = true;
        if (a.dedupKey)
            seenKeys[a.dedupKey] = true;
        out.push(a);
    }
    return out;
}

// Cheap identity of a list, used to skip re-layouts when nothing changed.
function signature(list) {
    var parts = [];
    var items = toArray(list);
    for (var i = 0; i < items.length; i++) {
        var a = items[i];
        parts.push([a.id, a.label, a.detail, Math.round((a.progress || 0) * 1000), a.color, a.icon, a.image].join("\u0001"));
    }
    return parts.join("\u0002");
}

// "mm:ss" or "h:mm:ss"
function formatDuration(totalSeconds) {
    var s = Math.max(0, Math.floor(Number(totalSeconds) || 0));
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var pad = function (n) {
        return n < 10 ? "0" + n : "" + n;
    };
    return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : pad(m) + ":" + pad(sec);
}
