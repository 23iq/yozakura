.pragma library

// Pure logic for downloads/transfers: unit formatting, de-duplication across
// sources and the aggregated "downloads" summary. Unit tested in
// tests/transfers.test.cjs.
//
// A transfer (from the backend "transfers" service, or built in QML for
// notification progress) is a plain object:
//   id, source, app, appIcon, title, path, dir,
//   processed, total (bytes, -1 unknown), rate (bytes/s, -1 unknown),
//   state: running | paused | queued | done | failed
//   kind:  download | upload | copy | update | sync
//   detail, actions: ["cancel", "suspend", "resume"], startedAt (ms), openUrl
//   units: "bytes" (default) | "percent" (processed/total are 0..100)
//   ref: provider-specific reference (e.g. a notification id)

var STATES = ["running", "paused", "queued", "done", "failed"];

// Which source wins when two report the same file: the one with the most
// precise data first (real totals and actions), notifications last.
var SOURCE_RANK = {
    jobView: 10,
    steam: 9,
    torrents: 9,
    aria2: 9,
    syncthing: 8,
    launchers: 8,
    browserDownloads: 7,
    terminal: 6,
    fileOps: 5,
    packages: 4,
    notificationProgress: 1
};

// In-progress suffixes used by browsers and downloaders
var PARTIAL_SUFFIX = /\.(part|crdownload|opdownload|download|partial|tmp|ytdl|aria2)$/i;

function num(v) {
    var n = Number(v);
    return isFinite(n) ? n : -1;
}

function normalize(t) {
    if (!t || typeof t !== "object" || !t.id)
        return null;
    var state = STATES.indexOf(t.state) !== -1 ? t.state : "running";
    return {
        id: String(t.id),
        source: String(t.source || ""),
        app: t.app ? String(t.app) : "",
        appIcon: t.appIcon ? String(t.appIcon) : "",
        title: t.title ? String(t.title) : "",
        path: t.path ? String(t.path) : "",
        dir: t.dir ? String(t.dir) : "",
        processed: num(t.processed),
        total: num(t.total),
        rate: num(t.rate),
        state: state,
        kind: t.kind ? String(t.kind) : "download",
        detail: t.detail ? String(t.detail) : "",
        actions: toArray(t.actions).map(String),
        startedAt: Math.max(0, num(t.startedAt)),
        openUrl: t.openUrl ? String(t.openUrl) : "",
        units: t.units === "percent" ? "percent" : "bytes",
        ref: t.ref === undefined ? null : t.ref
    };
}

function toArray(v) {
    if (Array.isArray(v))
        return v;
    if (v && typeof v === "object" && typeof v.length === "number") {
        var out = [];
        for (var i = 0; i < v.length; i++)
            out.push(v[i]);
        return out;
    }
    return [];
}

// 0..1, or -1 when unknown
function progress(t) {
    if (!t)
        return -1;
    if (t.state === "done")
        return 1;
    if (t.total > 0 && t.processed >= 0)
        return Math.max(0, Math.min(1, t.processed / t.total));
    return -1;
}

// Seconds left, or -1
function eta(t) {
    if (!t || t.state !== "running" || !(t.rate > 0) || !(t.total > 0) || t.processed < 0)
        return -1;
    return Math.max(0, Math.round((t.total - t.processed) / t.rate));
}

// File name without the in-progress suffix, lower-cased, for matching
function fileKey(t) {
    var name = t.path ? t.path.split("/").pop() : t.title;
    name = String(name || "").trim().toLowerCase();
    while (PARTIAL_SUFFIX.test(name))
        name = name.replace(PARTIAL_SUFFIX, "");
    return name;
}

function rank(t) {
    var r = SOURCE_RANK[t.source];
    return r === undefined ? 5 : r;
}

// Better of two duplicates: higher source rank, then known total, then
// the most recently started
function better(a, b) {
    if (rank(a) !== rank(b))
        return rank(a) > rank(b) ? a : b;
    if ((a.total > 0) !== (b.total > 0))
        return a.total > 0 ? a : b;
    return a.startedAt >= b.startedAt ? a : b;
}

function mentions(note, other) {
    var needle = fileKey(other);
    if (needle.length < 4)
        return false;
    return (note.title + " " + note.detail).toLowerCase().indexOf(needle) !== -1;
}

// Same file seen by two sources
function sameFile(a, b) {
    var ka = fileKey(a);
    if (ka && ka === fileKey(b))
        return true;
    if (a.source === "notificationProgress" && b.source !== "notificationProgress")
        return mentions(a, b);
    if (b.source === "notificationProgress" && a.source !== "notificationProgress")
        return mentions(b, a);
    return false;
}

// Normalise, drop invalid entries and merge items that describe the same
// file (Firefox .part seen by the download-dir watcher and by a progress
// notification). Notifications rarely carry a path, so they also match a
// file whose name appears in their title/detail.
function dedupe(list) {
    var items = [];
    var src = toArray(list);
    for (var i = 0; i < src.length; i++) {
        var n = normalize(src[i]);
        if (n)
            items.push(n);
    }
    var byId = {};
    var out = [];
    for (var j = 0; j < items.length; j++) {
        var t = items[j];
        if (byId[t.id] !== undefined) {
            out[byId[t.id]] = better(out[byId[t.id]], t);
            continue;
        }
        var match = -1;
        for (var k = 0; k < out.length; k++) {
            if (sameFile(out[k], t)) {
                match = k;
                break;
            }
        }
        if (match !== -1) {
            out[match] = better(out[match], t);
            byId[t.id] = match;
        } else {
            byId[t.id] = out.length;
            out.push(t);
        }
    }
    out.sort(function (a, b) {
        if (a.startedAt !== b.startedAt)
            return a.startedAt - b.startedAt;
        return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0);
    });
    return out;
}

// Summary over several transfers:
//   count, active (running/queued/paused), progress (bytes weighted when
//   every active item has a total, else the mean of known ones, -1 none),
//   rate (sum of known rates, -1 none), eta (s, -1), state (worst of:
//   failed > running > paused > queued > done), indeterminate
function summarize(list) {
    var items = toArray(list);
    var res = {
        count: items.length,
        active: 0,
        progress: -1,
        rate: -1,
        eta: -1,
        processed: 0,
        total: 0,
        state: items.length ? "done" : "",
        indeterminate: false
    };
    var allTotals = true;
    var sumP = 0, sumT = 0, known = 0, meanAcc = 0, rate = 0, haveRate = false;
    var order = { done: 0, queued: 1, paused: 2, running: 3, failed: 4 };
    for (var i = 0; i < items.length; i++) {
        var t = items[i];
        if (order[t.state] > order[res.state])
            res.state = t.state;
        if (t.state === "done" || t.state === "failed")
            continue;
        res.active++;
        var p = progress(t);
        if (t.units !== "percent" && t.total > 0 && t.processed >= 0) {
            sumP += Math.min(t.processed, t.total);
            sumT += t.total;
        } else {
            allTotals = false;
        }
        if (p >= 0) {
            known++;
            meanAcc += p;
        }
        if (t.rate >= 0 && t.state === "running") {
            rate += t.rate;
            haveRate = true;
        }
    }
    res.processed = sumP;
    res.total = sumT;
    if (res.active === 0) {
        res.progress = res.count ? 1 : -1;
    } else if (allTotals && sumT > 0) {
        res.progress = sumP / sumT;
    } else if (known > 0) {
        res.progress = meanAcc / known;
    }
    res.indeterminate = res.active > 0 && known === 0;
    res.rate = haveRate ? rate : -1;
    if (allTotals && sumT > 0 && rate > 0)
        res.eta = Math.max(0, Math.round((sumT - sumP) / rate));
    return res;
}

// ── formatting ────────────────────────────────────────────────────────

var UNITS = ["B", "KB", "MB", "GB", "TB"];

// 1536 -> "1.5 KB" (binary multiples, the way file managers show sizes)
function formatBytes(bytes) {
    var b = Number(bytes);
    if (!isFinite(b) || b < 0)
        return "";
    var i = 0;
    while (b >= 1024 && i < UNITS.length - 1) {
        b /= 1024;
        i++;
    }
    var digits = i === 0 ? 0 : (b < 10 ? 1 : 0);
    return b.toFixed(digits) + " " + UNITS[i];
}

function formatRate(bytesPerSecond) {
    var s = formatBytes(bytesPerSecond);
    return s ? s + "/s" : "";
}

// 75 -> "1m 15s", 3725 -> "1h 2m", 9 -> "9s"
function formatEta(seconds) {
    var s = Math.round(Number(seconds));
    if (!isFinite(s) || s < 0)
        return "";
    if (s < 60)
        return s + "s";
    var m = Math.floor(s / 60);
    if (m < 60)
        return m + "m " + (s % 60) + "s";
    var h = Math.floor(m / 60);
    if (h < 48)
        return h + "h " + (m % 60) + "m";
    return Math.floor(h / 24) + "d " + (h % 24) + "h";
}

// "340 MB / 720 MB", "340 MB" when the total is unknown; "" for percent units
function formatTransferSizes(t) {
    return t && t.units !== "percent" ? formatSizes(t.processed, t.total) : "";
}

// "340 MB / 720 MB", "340 MB" when the total is unknown
function formatSizes(processed, total) {
    var p = formatBytes(processed);
    var t = total > 0 ? formatBytes(total) : "";
    if (p && t)
        return p + " / " + t;
    return p || t;
}

// Percentage label, "" when unknown
function formatPercent(p) {
    return p >= 0 ? Math.round(p * 100) + "%" : "";
}

// Middle elision keeping the extension: "very-long-name….iso"
function elideMiddle(text, max) {
    var s = String(text || "");
    if (s.length <= max || max < 5)
        return s;
    var keep = max - 1;
    var tail = Math.ceil(keep / 2);
    var head = keep - tail;
    return s.slice(0, head) + "…" + s.slice(s.length - tail);
}

// ── activities ───────────────────────────────────────────────────────

// Collapsed label of a download without a known total:
// "38 MB · 4.2 MB/s", "38 MB" without a rate, "" without bytes
function indeterminateLabel(processed, rate) {
    var b = processed >= 0 ? formatBytes(processed) : "";
    var r = rate > 0 ? formatRate(rate) : "";
    if (b && r)
        return b + " · " + r;
    return b || r;
}

// " · 47%" with a known progress, else " · 7.3 MB/s" (summed rate), else
// " · 76 MB" (summed bytes), else ""
function aggregateSuffix(s, items) {
    if (s.progress >= 0)
        return " · " + formatPercent(s.progress);
    if (s.rate > 0)
        return " · " + formatRate(s.rate);
    var bytes = 0;
    for (var i = 0; i < items.length; i++) {
        var t = items[i];
        if (t.units !== "percent" && t.processed > 0 && t.state !== "done" && t.state !== "failed")
            bytes += t.processed;
    }
    return bytes > 0 ? " · " + formatBytes(bytes) : "";
}

// Turn de-duplicated transfers into live activities (ActivityModel shape).
// aggregate: one "downloads" activity for all of them (label "N · 47%"),
// else one per transfer. opts: { aggregate, icon, priority, title }.
function toActivities(list, opts) {
    var o = opts || {};
    var items = toArray(list);
    if (items.length === 0)
        return [];
    function color(state) {
        return state === "failed" ? "error" : (state === "done" ? "green" : "primary");
    }
    function one(t) {
        var p = progress(t);
        var label = t.state === "done" ? "✓" : (p >= 0 ? formatPercent(p) : (indeterminateLabel(t.processed, t.state === "running" ? t.rate : -1) || elideMiddle(t.title || t.app, 14)));
        return {
            id: "transfer:" + t.id,
            source: "downloads",
            category: "task",
            priority: o.priority || 40,
            icon: o.icon || "",
            image: t.appIcon,
            indicator: "ring",
            label: label,
            detail: [t.app, t.title].filter(function (x) {
                return !!x;
            }).join(" · "),
            progress: p,
            color: color(t.state),
            startedAt: t.startedAt,
            action: t.id
        };
    }
    if (!o.aggregate || items.length === 1) {
        var single = items.map(one);
        if (o.aggregate)
            single[0].id = "downloads";
        return single;
    }
    var s = summarize(items);
    var first = items[0];
    return [
        {
            id: "downloads",
            source: "downloads",
            category: "task",
            priority: o.priority || 40,
            icon: o.icon || "",
            image: "",
            indicator: "ring",
            label: s.active === 0 ? "✓" : (s.active + aggregateSuffix(s, items)),
            detail: o.title || "",
            progress: s.progress,
            color: color(s.state),
            startedAt: first.startedAt,
            action: ""
        }
    ];
}
