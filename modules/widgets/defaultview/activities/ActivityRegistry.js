.pragma library

// The notch's activity registry: which live activities the island shows,
// on which side and in which order (notch.activities). Pure, unit tested in
// tests/activity-registry.test.cjs.
//
// A descriptor:
//   id          registry id, the key users order in settings
//   side        default side: "leading" | "trailing" ("center" is fixed)
//   priority    default order (higher first)
//   sources     ActivityService `source` values it owns
//   trigger     panel the segment opens (panels/NotchPanels.js), "" = none
//   ephemeralMs how long an ephemeral activity stays, 0 = while it lasts
// notch.activities entries are { id, side, enabled } (or a bare id).

var SIDES = ["leading", "trailing"];

var DESCRIPTORS = [
    { id: "media", side: "center", priority: 110, sources: [], trigger: "media", ephemeralMs: 0 },
    { id: "privacy", side: "trailing", priority: 100, sources: ["recording", "privacy"], trigger: "privacy", ephemeralMs: 0 },
    { id: "osd", side: "trailing", priority: 90, sources: ["osd"], trigger: "", ephemeralMs: 1200 },
    { id: "battery", side: "trailing", priority: 60, sources: ["battery"], trigger: "", ephemeralMs: 5000 },
    { id: "bluetooth", side: "trailing", priority: 55, sources: ["bluetooth"], trigger: "", ephemeralMs: 4000 },
    { id: "timers", side: "leading", priority: 50, sources: ["timers"], trigger: "timers", ephemeralMs: 0 },
    { id: "tasks", side: "leading", priority: 40, sources: ["tasks", "downloads"], trigger: "tasks", ephemeralMs: 0 },
    { id: "extras", side: "leading", priority: 35, sources: ["extras"], trigger: "tasks", ephemeralMs: 0 }
];

function _array(v) {
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

function descriptor(id) {
    for (var i = 0; i < DESCRIPTORS.length; i++)
        if (DESCRIPTORS[i].id === id)
            return DESCRIPTORS[i];
    return null;
}

function _entry(d, raw) {
    var r = raw && typeof raw === "object" ? raw : {};
    var side = d.side === "center" || SIDES.indexOf(r.side) === -1 ? d.side : r.side;
    return {
        id: d.id,
        side: side,
        enabled: r.enabled === undefined ? true : r.enabled === true,
        priority: d.priority,
        sources: d.sources.slice(),
        trigger: d.trigger,
        ephemeralMs: d.ephemeralMs
    };
}

// The full ordered list: the user's entries first (unknown and repeated
// ids dropped), then every missing descriptor in default priority order.
function resolve(config) {
    var out = [];
    var seen = {};
    var list = _array(config);
    for (var i = 0; i < list.length; i++) {
        var raw = typeof list[i] === "string" ? { id: list[i] } : list[i];
        var d = raw ? descriptor(raw.id) : null;
        if (!d || seen[d.id])
            continue;
        seen[d.id] = true;
        out.push(_entry(d, raw));
    }
    var rest = DESCRIPTORS.filter(function (x) {
        return !seen[x.id];
    }).sort(function (a, b) {
        return b.priority - a.priority;
    });
    for (var j = 0; j < rest.length; j++)
        out.push(_entry(rest[j], null));
    return out;
}

function isEnabled(config, id) {
    var list = resolve(config);
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id)
            return list[i].enabled;
    return false;
}

function _index(resolved, source) {
    for (var i = 0; i < resolved.length; i++)
        if (resolved[i].sources.indexOf(source) !== -1)
            return i;
    return -1;
}

// Activities (ActivityService.activities) split by side in the resolved
// order; within one entry the service's priority order is kept. Sources
// the registry does not know stay on their category's side, after the
// known ones.
function sides(activities, resolved) {
    var r = _array(resolved);
    var acts = _array(activities);
    var tagged = [];
    for (var i = 0; i < acts.length; i++) {
        var a = acts[i];
        if (!a)
            continue;
        var idx = _index(r, a.source);
        if (idx !== -1 && !r[idx].enabled)
            continue;
        var side = idx === -1 ? (a.category === "task" ? "leading" : "trailing") : r[idx].side;
        tagged.push({ a: a, rank: idx === -1 ? r.length : idx, pos: i, side: side });
    }
    tagged.sort(function (x, y) {
        return x.rank - y.rank || x.pos - y.pos;
    });
    var out = { leading: [], trailing: [] };
    for (var k = 0; k < tagged.length; k++)
        if (out[tagged[k].side])
            out[tagged[k].side].push(tagged[k].a);
    return out;
}

// Panel trigger of an activity's entry; unknown sources open their
// category's panel.
function triggerOf(activity, resolved) {
    if (!activity)
        return "";
    var r = _array(resolved);
    var idx = _index(r, activity.source);
    if (idx === -1)
        return activity.category === "task" ? "tasks" : "privacy";
    return r[idx].trigger;
}
