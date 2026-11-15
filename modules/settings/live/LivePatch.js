.pragma library

// Patches for LivePanel (laid over your primary bar's spec): what a picture
// card shows of the real bar. Tests: tests/live-preview.test.cjs.

// only(ids) -> your bar holding just these modules, at its start (frame
// it with LivePanel `frame: "modules"`: one module on a piece of your bar)
function only(ids) {
    var list = typeof ids === "string" ? [ids] : (ids || []).slice();
    return {
        "groups": {
            "start": list,
            "center": [],
            "end": [],
            "drawer": [],
            "gapStart": [],
            "gapEnd": []
        }
    };
}

// sample(groups) -> a few of your bar's modules in their groups (the first
// two of the start, the first of the center, the last two of the end), so
// a small picture of a whole bar still shows its silhouette and its own
// modules
function sample(groups) {
    var g = groups || {};
    var pick = function (list, n, fromEnd) {
        var l = (list || []).filter(function (id) {
            return id !== "__sep__";
        });
        return fromEnd ? l.slice(Math.max(0, l.length - n)) : l.slice(0, n);
    };
    return {
        "groups": {
            "start": pick(g.start, 2, false),
            "center": pick(g.center, 1, false),
            "end": pick(g.end, 2, true),
            "drawer": [],
            "gapStart": [],
            "gapEnd": []
        }
    };
}

// style(id) -> your bar in another style (the Shape cards)
function style(id) {
    return {
        "style": id
    };
}
