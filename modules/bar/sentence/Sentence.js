.pragma library
.import "../../services/Plural.js" as Plural

// The sentence bar module (modules/bar/modules/Sentence.qml): the bar read
// as one line, "Saturday, 18:20 — Firefox on desk 2 — battery 82%".
// Pure helpers: which fragments, their translated templates, the merge of
// window + workspace, plural forms, dropping by priority, word-safe trims.
// Tested by tests/bar-sentence.test.cjs.
//
// Templates live in translations (bar.sentence.<fragment>.<variant>) with
// named placeholders ({time}, {app}, {n}...). Code never glues translated
// words together; it only joins whole fragments with the separator.

var FRAGMENTS = ["clock", "window", "workspace", "battery", "network", "volume", "media", "notifications", "weather"];
var DEFAULT_ORDER = ["clock", "window", "workspace", "battery", "media", "notifications"];
// Highest first: the last ones drop first on a narrow bar
var DEFAULT_PRIORITY = ["clock", "media", "window", "battery", "notifications", "workspace", "volume", "weather", "network"];
var SEPARATORS = ["dash", "dot", "comma", "none"];
var VERBOSITIES = ["short", "full"];

// Click on a fragment = the action of the matching module
var ACTIONS = {
    "clock": "clock",
    "weather": "clock",
    "window": "overview",
    "workspace": "overview",
    "battery": "battery",
    "network": "network",
    "volume": "controls",
    "media": "media",
    "notifications": "notifications"
};

// Longest window / track text before a word-safe trim
var MAX_CHARS = 36;

function isFragment(id) {
    return FRAGMENTS.indexOf(id) !== -1;
}

// Known ids, once each, in the given order; not an array -> the fallback.
function normalizeList(list, fallback) {
    if (!Array.isArray(list))
        return fallback.slice();
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var id = String(list[i]);
        if (isFragment(id) && out.indexOf(id) === -1)
            out.push(id);
    }
    return out;
}

// Every fragment ranked: the configured ones first, the rest in the default
// priority after them.
function normalizePriority(list) {
    var out = normalizeList(list, DEFAULT_PRIORITY);
    for (var i = 0; i < DEFAULT_PRIORITY.length; i++)
        if (out.indexOf(DEFAULT_PRIORITY[i]) === -1)
            out.push(DEFAULT_PRIORITY[i]);
    return out;
}

function separator(style) {
    return SEPARATORS.indexOf(style) === -1 ? "dash" : style;
}

// The separator glyph between two fragments and whether it hugs the
// fragment before it (a comma does, a dash or dot stands free; none is a
// plain gap).
function separatorGlyph(style) {
    switch (separator(style)) {
    case "dot":
        return "·";
    case "comma":
        return ",";
    case "none":
        return "";
    default:
        return "—";
    }
}

function separatorHugs(style) {
    return separator(style) === "comma";
}

function verbosity(v) {
    return VERBOSITIES.indexOf(v) === -1 ? "full" : v;
}

function action(id) {
    return ACTIONS[id] || "";
}

// "Aruarian Dance from the Samurai Champloo soundtrack" -> whole words up to
// `max` characters + "…"; a single word longer than max stays whole.
function trimWords(s, max) {
    var text = String(s === undefined || s === null ? "" : s).replace(/\s+/g, " ").trim();
    var limit = max > 0 ? max : MAX_CHARS;
    if (text.length <= limit)
        return text;
    var cut = text.lastIndexOf(" ", limit);
    if (cut <= 0)
        return text.split(" ")[0];
    return text.slice(0, cut).replace(/[\s,.;:—–-]+$/, "") + "…";
}

function capitalizeFirst(s) {
    var t = String(s || "");
    return t === "" ? t : t.charAt(0).toUpperCase() + t.slice(1);
}

// `<base>.<CLDR category>` if translated, else `<base>.other`, else base.
function pluralKey(base, lang, n, has) {
    var exact = base + "." + Plural.category(lang, n);
    if (has(exact))
        return exact;
    return has(base + ".other") ? base + ".other" : base;
}

// A template with {name} placeholders as segments: [{text, value}], value
// true for filled-in data (drawn in full ink), false for the template's
// own words. Any placeholder without a value -> [] (the fragment hides).
function segments(template, vars) {
    var tpl = String(template || "");
    if (tpl === "")
        return [];
    var out = [];
    var re = /\{(\w+)\}/g;
    var last = 0;
    var m;
    while ((m = re.exec(tpl)) !== null) {
        var v = vars ? vars[m[1]] : undefined;
        if (v === undefined || v === null || String(v) === "")
            return [];
        if (m.index > last)
            out.push({ "text": tpl.slice(last, m.index), "value": false });
        out.push({ "text": String(v), "value": true });
        last = re.lastIndex;
    }
    if (last < tpl.length)
        out.push({ "text": tpl.slice(last), "value": false });
    return out;
}

function fill(template, vars) {
    return segments(template, vars).map(function (s) {
        return s.text;
    }).join("");
}

// Translation key of one fragment for its current state, or "" (hidden).
// Count fragments return their plural base; `n` in the vars picks the form.
function templateKey(id, v, verb) {
    if (!v)
        return "";
    var full = verbosity(verb) === "full";
    switch (id) {
    case "clock":
        return full ? "bar.sentence.clock.full" : "bar.sentence.clock.short";
    case "window":
        return "bar.sentence.window";
    case "workspace":
        return "bar.sentence.workspace";
    case "battery":
        if (!(v.pct >= 0))
            return "";
        if (v.charging && full)
            return "bar.sentence.battery.charging";
        return full ? "bar.sentence.battery.full" : "bar.sentence.battery.short";
    case "network":
        if (v.kind === "offline")
            return "bar.sentence.network.offline";
        if (v.kind === "wired")
            return full ? "bar.sentence.network.wired.full" : "bar.sentence.network.wired.short";
        return v.name ? (full ? "bar.sentence.network.wifi.full" : "bar.sentence.network.wifi.short") : "";
    case "volume":
        if (v.muted)
            return "bar.sentence.volume.muted";
        return full ? "bar.sentence.volume.full" : "bar.sentence.volume.short";
    case "media":
        if (!v.playing || !v.title)
            return "";
        if (!full)
            return "bar.sentence.media.short";
        return v.artist ? "bar.sentence.media.full" : "bar.sentence.media.title";
    case "notifications":
        return v.n > 0 ? (full ? "bar.sentence.notifications.full" : "bar.sentence.notifications.short") : "";
    case "weather":
        return full && v.desc ? "bar.sentence.weather.full" : "bar.sentence.weather.short";
    }
    return "";
}

function isCount(id) {
    return id === "notifications";
}

// The fragments of the sentence, in order: [{id, ids, action, segments,
// text}]. values: {<fragment>: vars or null}, opts: {order, verbosity},
// tr(key) -> template ("" when untranslated), has(key) -> bool, lang for
// plural forms. A window followed directly by its workspace reads as one
// fragment ("Firefox on desk 2").
function build(values, opts, tr, has, lang) {
    var o = opts || {};
    var order = normalizeList(o.order, DEFAULT_ORDER);
    var verb = verbosity(o.verbosity);
    var vals = values || {};
    var out = [];
    var shown = order.filter(function (id) {
        return templateKey(id, vals[id], verb) !== "";
    });
    for (var i = 0; i < shown.length; i++) {
        var id = shown[i];
        var vars = vals[id];
        var key = templateKey(id, vars, verb);
        var ids = [id];
        if (id === "window" && shown[i + 1] === "workspace") {
            key = "bar.sentence.window_desk";
            vars = { "app": vals.window.app, "ws": vals.workspace.ws };
            ids.push("workspace");
            i++;
        }
        if (isCount(id))
            key = pluralKey(key, lang, vars.n, has);
        var segs = segments(tr(key), vars);
        if (segs.length === 0)
            continue;
        out.push({
            "id": id,
            "ids": ids,
            "action": action(id),
            "segments": segs,
            "text": segs.map(function (s) {
                return s.text;
            }).join("")
        });
    }
    return out;
}

// Which fragments stay on a bar `budget` px long: fragments in sentence
// order with their widths, `gap` px per separator. The lowest priority
// fragment drops first until the line fits; a fragment never shrinks.
// Returns one bool per fragment.
function fit(ids, widths, priority, budget, gap) {
    var keep = ids.map(function () {
        return true;
    });
    if (!(budget > 0) || budget === Infinity)
        return keep;
    var rank = normalizePriority(priority);
    var g = gap > 0 ? gap : 0;
    function total() {
        var sum = 0;
        var n = 0;
        for (var i = 0; i < ids.length; i++) {
            if (!keep[i])
                continue;
            sum += widths[i] || 0;
            n++;
        }
        return sum + Math.max(0, n - 1) * g;
    }
    // Indices from the lowest priority up
    var byRank = ids.map(function (id, i) {
        return i;
    }).sort(function (a, b) {
        var ra = rank.indexOf(ids[a]);
        var rb = rank.indexOf(ids[b]);
        return (rb === -1 ? 99 : rb) - (ra === -1 ? 99 : ra) || b - a;
    });
    for (var k = 0; k < byRank.length && total() > budget; k++)
        keep[byRank[k]] = false;
    return keep;
}

// Room for the line on a bar `length` px long whose middle holds a notch
// `notch` px wide: from the module's fixed edge (`along` px in, `size`
// long) to the notch, less `margin`. A module before the middle grows
// away from its start edge, one after it toward its end edge. No notch:
// Infinity.
function room(along, size, length, notch, margin) {
    if (!(notch > 0) || !(length > 0))
        return Infinity;
    var mid = length / 2;
    var half = notch / 2 + (margin > 0 ? margin : 0);
    if (along + size / 2 <= mid)
        return Math.max(0, mid - half - along);
    return Math.max(0, along + size - (mid + half));
}

// The line's budget: half the bar, or `max` px when set (never past the
// bar), then no further than the room by the notch.
function budget(length, max, roomPx) {
    var b = max > 0 ? (length > 0 ? Math.min(max, length) : max) : length * 0.5;
    return Math.min(b, roomPx);
}

// Index of the first kept fragment (it leads the sentence: capitalized), -1.
function leadIndex(keep) {
    for (var i = 0; i < keep.length; i++)
        if (keep[i])
            return i;
    return -1;
}
