.pragma library

// Pure helpers for live activities inside the notch: what each collapsed
// segment shows, fixed-width label templates (no jitter while a timer
// ticks) and the rows of the expanded list. Unit tested in
// tests/notch-activities.test.cjs.

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

// Privacy glyphs (screen, camera, mic) show without text; recording and
// tasks (rings) carry a short label.
function hasLabel(activity) {
    return !!activity && activity.indicator !== "glyph" && String(activity.label || "") !== "";
}

// Collapsed segment of one side.
//   list: ActivityService.tasks (leading) or .privacy (trailing), sorted
//   maxGlyphs: privacy glyphs shown next to the top item (trailing only)
// Returns null, or { item, extras: [activity], badge: hidden count }.
function segment(list, side, maxGlyphs) {
    var items = toArray(list);
    if (items.length === 0)
        return null;
    var extras = [];
    if (side === "trailing") {
        var room = Math.max(0, (maxGlyphs || 3) - 1);
        for (var i = 1; i < items.length && extras.length < room; i++)
            if (items[i].indicator === "glyph")
                extras.push(items[i]);
    }
    return {
        item: items[0],
        extras: extras,
        badge: items.length - 1 - extras.length
    };
}

// Widest text a label of this shape can take: digits become "0" (tabular
// figures make every digit equally wide), percentages always reserve three
// digits ("5%" -> "47%" -> "100%") and sizes/speeds reserve "0000 MB" so
// "980 KB" -> "1.2 MB" -> "38 MB/s" never changes the width.
function widthTemplate(label) {
    var s = String(label || "");
    s = s.replace(/\d+(?:\.\d+)?\s?(?:B|KB|MB|GB|TB)(?=\/s|\b|$)/g, "0000 MB");
    s = s.replace(/\d+(?=%)/g, "000");
    return s.replace(/\d/g, "0");
}

// The part of a "Kind · details" string before / after the first " · "
function splitDetail(detail) {
    var s = String(detail || "");
    var i = s.indexOf(" · ");
    if (i === -1)
        return {
            head: s,
            tail: ""
        };
    return {
        head: s.slice(0, i),
        tail: s.slice(i + 3)
    };
}

// Primary/secondary text of a non-download activity row.
//   labels: { recording: "Screen recording" }
function activityText(activity, labels) {
    var a = activity || {};
    var l = labels || {};
    if (a.source === "recording")
        return {
            primary: l.recording || a.detail || "",
            secondary: a.label || ""
        };
    if (a.source === "timers")
        return {
            primary: a.detail || a.label || "",
            secondary: a.label || ""
        };
    var d = splitDetail(a.detail);
    if (d.tail)
        return {
            primary: d.head,
            secondary: d.tail
        };
    return {
        primary: a.label || d.head,
        secondary: a.label ? d.head : ""
    };
}

// Rows of the expanded list, in display order:
//   { kind: "activity", key, ref: activity }   recording, timers, privacy
//   { kind: "header", key, label, count }      one per transfer source
//   { kind: "transfer", key, ref: transfer }
// Transfers are grouped by source in order of first appearance; a group
// header is labelled with the app names of its transfers.
function rows(activities, transfers) {
    var out = [];
    var acts = toArray(activities);
    for (var i = 0; i < acts.length; i++) {
        var a = acts[i];
        if (a && a.source !== "downloads")
            out.push({
                kind: "activity",
                key: "a:" + a.id,
                ref: a
            });
    }
    var groups = [];
    var bySource = {};
    var list = toArray(transfers);
    for (var j = 0; j < list.length; j++) {
        var t = list[j];
        if (!t)
            continue;
        var src = t.source || "";
        if (bySource[src] === undefined) {
            bySource[src] = groups.length;
            groups.push({
                source: src,
                apps: [],
                items: []
            });
        }
        var g = groups[bySource[src]];
        g.items.push(t);
        if (t.app && g.apps.indexOf(t.app) === -1)
            g.apps.push(t.app);
    }
    for (var k = 0; k < groups.length; k++) {
        var grp = groups[k];
        out.push({
            kind: "header",
            key: "h:" + grp.source,
            label: grp.apps.length ? grp.apps.join(" · ") : grp.source,
            count: grp.items.length
        });
        for (var m = 0; m < grp.items.length; m++)
            out.push({
                kind: "transfer",
                key: "t:" + grp.items[m].id,
                ref: grp.items[m]
            });
    }
    return out;
}

function keys(rowList) {
    return toArray(rowList).map(function (r) {
        return r.key;
    }).join("\n");
}

// Status line of a transfer row: "340 MB / 720 MB · 2.5 MB/s" (left) and
// "1m 15s left" / state text (right). `fmt` is TransferModel, `labels`
// translated words { left, paused, queued, failed, done }.
function transferStatus(t, fmt, showSpeed, labels) {
    var l = labels || {};
    var parts = [];
    var sizes = fmt.formatTransferSizes(t);
    if (sizes)
        parts.push(sizes);
    if (showSpeed && t.state === "running" && t.rate > 0)
        parts.push(fmt.formatRate(t.rate));
    if (!sizes && t.units === "percent") {
        var p = fmt.progress(t);
        if (p >= 0)
            parts.unshift(fmt.formatPercent(p));
    }
    if (parts.length === 0 && t.detail)
        parts.push(t.detail);
    var right = "";
    var tone = "normal";
    if (t.state === "paused") {
        right = l.paused || "paused";
    } else if (t.state === "queued") {
        right = l.queued || "queued";
    } else if (t.state === "failed") {
        right = l.failed || "failed";
        tone = "error";
    } else if (t.state === "done") {
        right = l.done || "done";
        tone = "done";
    } else {
        var e = fmt.eta(t);
        if (e >= 0)
            right = fmt.formatEta(e) + (l.left ? " " + l.left : "");
    }
    return {
        left: parts.join(" · "),
        right: right,
        tone: tone
    };
}
