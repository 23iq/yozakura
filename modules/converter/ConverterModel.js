.pragma library

// Pure logic of the converter window (tests/converter-model.test.cjs).
// Shapes come from the backend `convert` service (backend/pkg/svc/convert):
// a probe File {path, name, size, kind, format, formatLabel, targets:
// [{id, label, kind, available, needs, popular, lossy}], default, error}
// and a Job {id, path, from, to, state, progress, output, error}.
// A row is a File plus `target` (the chosen format id) and `job` (the
// latest Job of its conversion, or null).

// Kinds in the order the picker groups them, with their icon names
// (Icons.<name>) and label keys.
var KINDS = [
    { "id": "image", "icon": "fileImage", "label": "converter.kind.image" },
    { "id": "audio", "icon": "fileAudio", "label": "converter.kind.audio" },
    { "id": "video", "icon": "fileVideo", "label": "converter.kind.video" },
    { "id": "document", "icon": "fileDoc", "label": "converter.kind.document" },
    { "id": "ebook", "icon": "bookOpen", "label": "converter.kind.ebook" },
    { "id": "data", "icon": "database", "label": "converter.kind.data" }
];

function kindInfo(id) {
    for (var i = 0; i < KINDS.length; i++) {
        if (KINDS[i].id === id)
            return KINDS[i];
    }
    return { "id": id || "", "icon": "file", "label": "converter.kind.other" };
}

// Rows after adding probed files: a path already listed is not added twice;
// each new row proposes the backend's default target.
function addFiles(rows, files) {
    var out = (rows || []).slice();
    var seen = {};
    out.forEach(function (r) {
        seen[r.path] = true;
    });
    (files || []).forEach(function (f) {
        if (!f || !f.path || seen[f.path])
            return;
        seen[f.path] = true;
        out.push(Object.assign({}, f, {
            "target": f.error ? "" : (f.default || ""),
            "job": null
        }));
    });
    return out;
}

function removeRow(rows, path) {
    return (rows || []).filter(function (r) {
        return r.path !== path;
    });
}

function targetOf(row, id) {
    var t = (row && row.targets) || [];
    for (var i = 0; i < t.length; i++) {
        if (t[i].id === id)
            return t[i];
    }
    return null;
}

// A row that may still change its target (not converting / converted).
function editable(row) {
    var s = row && row.job ? row.job.state : "";
    return s !== "queued" && s !== "running" && s !== "done";
}

// Rows with `path`'s target set to id (when it is one of its targets).
function setTarget(rows, path, id) {
    return (rows || []).map(function (r) {
        if (r.path !== path || !targetOf(r, id))
            return r;
        return Object.assign({}, r, {
            "target": id,
            "job": editable(r) ? null : r.job
        });
    });
}

// Every editable row of `kind` that offers id gets it.
function setKindTarget(rows, kind, id) {
    return (rows || []).map(function (r) {
        if (r.kind !== kind || !editable(r) || !targetOf(r, id))
            return r;
        return Object.assign({}, r, {
            "target": id,
            "job": null
        });
    });
}

// Kinds with two or more rows: [{kind, count, target}] where target is the
// shared target ("" when the rows differ). Order: KINDS.
function kindGroups(rows) {
    var by = {};
    (rows || []).forEach(function (r) {
        if (!r.kind || r.error)
            return;
        var g = by[r.kind] || (by[r.kind] = {
            "kind": r.kind,
            "count": 0,
            "target": r.target
        });
        g.count++;
        if (g.target !== r.target)
            g.target = "";
    });
    var out = [];
    KINDS.forEach(function (k) {
        if (by[k.id] && by[k.id].count > 1)
            out.push(by[k.id]);
    });
    return out;
}

// The list's keys: rows grouped by kind (KINDS order, unknown files last),
// a "h:<kind>" header before a kind with two or more rows, "r:<path>" per
// row. Keys only change when files come or go, so rows keep their items.
function entryKeys(rows) {
    var groups = {};
    kindGroups(rows).forEach(function (g) {
        groups[g.kind] = true;
    });
    var out = [];
    var order = KINDS.map(function (k) {
        return k.id;
    });
    order.forEach(function (kind) {
        var list = (rows || []).filter(function (r) {
            return r.kind === kind && !r.error;
        });
        if (list.length === 0)
            return;
        if (groups[kind])
            out.push("h:" + kind);
        list.forEach(function (r) {
            out.push("r:" + r.path);
        });
    });
    (rows || []).forEach(function (r) {
        if (r.error || order.indexOf(r.kind) === -1)
            out.push("r:" + r.path);
    });
    return out;
}

function rowByPath(rows, path) {
    var list = rows || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].path === path)
            return list[i];
    }
    return null;
}

// The targets every row of a kind offers (for the "all of this kind"
// picker): the first row's list, keeping only ids all rows have.
function commonTargets(rows, kind) {
    var list = (rows || []).filter(function (r) {
        return r.kind === kind && !r.error;
    });
    if (list.length === 0)
        return [];
    return list[0].targets.filter(function (t) {
        return list.every(function (r) {
            return targetOf(r, t.id) !== null;
        });
    });
}

// The picker's sections: popular targets first (big chips), then the rest
// grouped by kind. [{kind: "" | <kind>, popular: bool, items}]
function pickerSections(targets) {
    var popular = [];
    var rest = {};
    (targets || []).forEach(function (t) {
        if (t.popular)
            popular.push(t);
        else
            (rest[t.kind] = rest[t.kind] || []).push(t);
    });
    var out = [];
    if (popular.length > 0)
        out.push({
            "kind": "",
            "popular": true,
            "items": popular
        });
    KINDS.forEach(function (k) {
        if (rest[k.id])
            out.push({
                "kind": k.id,
                "popular": false,
                "items": rest[k.id]
            });
    });
    return out;
}

// What a row shows: "ready" | "unavailable" (target needs a tool) |
// "invalid" (probe error) | "queued" | "running" | "done" | "failed" |
// "cancelled".
function rowState(row) {
    if (!row)
        return "invalid";
    if (row.error)
        return "invalid";
    if (row.job)
        return row.job.state;
    var t = targetOf(row, row.target);
    if (!t)
        return "invalid";
    return t.available ? "ready" : "unavailable";
}

// Rows the Convert action starts: ready ones, and failed / cancelled ones
// again.
function startable(rows) {
    return (rows || []).filter(function (r) {
        var s = rowState(r);
        return s === "ready" || s === "failed" || s === "cancelled";
    });
}

function startItems(rows) {
    return startable(rows).map(function (r) {
        return {
            "path": r.path,
            "target": r.target
        };
    });
}

// Attach a job event to its row (by job id, else to the row of its path
// that has no job yet, the reply of start). Returns the new rows.
function applyJob(rows, job) {
    if (!job || !job.id)
        return rows;
    var hit = -1;
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].job && rows[i].job.id === job.id) {
            hit = i;
            break;
        }
    }
    if (hit < 0) {
        for (var j = 0; j < rows.length; j++) {
            var s = rows[j].job ? rows[j].job.state : "";
            if (rows[j].path === job.path && rows[j].target === job.to && (s === "" || s === "pending")) {
                hit = j;
                break;
            }
        }
    }
    if (hit < 0)
        return rows;
    var out = rows.slice();
    out[hit] = Object.assign({}, rows[hit], {
        "job": job
    });
    return out;
}

// Mark the rows a start request covers as pending until the jobs arrive.
function markPending(rows, items) {
    var paths = {};
    (items || []).forEach(function (it) {
        paths[it.path] = true;
    });
    return (rows || []).map(function (r) {
        return paths[r.path] ? Object.assign({}, r, {
            "job": {
                "id": "",
                "state": "pending",
                "progress": -1,
                "path": r.path,
                "to": r.target
            }
        }) : r;
    });
}

function busy(rows) {
    return (rows || []).some(function (r) {
        var s = rowState(r);
        return s === "queued" || s === "running" || s === "pending";
    });
}

// The quality control matters when a row will convert to a lossy target.
function needsQuality(rows) {
    return startable(rows).some(function (r) {
        var t = targetOf(r, r.target);
        return t !== null && t.lossy;
    });
}

// 1536 -> "1.5 KB"; one decimal below 10, none above.
function formatSize(bytes) {
    if (!(bytes > 0))
        return "0 B";
    var units = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    var v = bytes;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    var r = i === 0 || v >= 10 ? Math.round(v) : Math.round(v * 10) / 10;
    return r + " " + units[i];
}

// Thumbnails: formats Qt's image reader shows directly.
var THUMBS = ["png", "jpg", "gif", "bmp", "webp", "svg", "tiff", "ico"];

function hasThumb(row) {
    return !!row && THUMBS.indexOf(row.format) !== -1;
}

function dirOf(path) {
    var s = String(path || "");
    var i = s.lastIndexOf("/");
    return i > 0 ? s.substring(0, i) : "/";
}

function baseName(path) {
    var s = String(path || "");
    return s.substring(s.lastIndexOf("/") + 1);
}

// Local paths of dropped URLs ("file:///a%20b.png" -> "/a b.png").
function localPaths(urls) {
    var out = [];
    (urls || []).forEach(function (u) {
        var s = String(u);
        if (s.indexOf("file://") !== 0)
            return;
        var p = s.substring(7);
        var slash = p.indexOf("/");
        if (slash > 0)
            p = p.substring(slash);
        try {
            p = decodeURIComponent(p);
        } catch (e) {}
        out.push(p);
    });
    return out;
}

// Chooser output (one path per line) -> paths.
function chooserPaths(text) {
    return String(text || "").split("\n").map(function (l) {
        return l.trim();
    }).filter(function (l) {
        return l.indexOf("/") === 0;
    });
}
