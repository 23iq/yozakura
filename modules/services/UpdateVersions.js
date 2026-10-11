.pragma library

// Version comparison for the update check (semver subset: 1.2.3 and
// 1.2.3-rc1; a leading "v" and build metadata are ignored). Tested in
// tests/update-versions.test.cjs.

// "v0.1.2-rc1+7" -> {nums: [0, 1, 2], pre: "rc1"}, or null when not a version.
function parse(text) {
    var m = /^v?(\d+(?:\.\d+)*)(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$/.exec(String(text || "").trim());
    if (!m)
        return null;
    return { "nums": m[1].split(".").map(Number), "pre": m[2] || "" };
}

function comparePre(a, b) {
    var pa = a.split("."), pb = b.split(".");
    for (var i = 0; i < Math.max(pa.length, pb.length); i++) {
        if (pa[i] === undefined)
            return -1;
        if (pb[i] === undefined)
            return 1;
        var na = /^\d+$/.test(pa[i]), nb = /^\d+$/.test(pb[i]);
        if (na && nb) {
            var d = Number(pa[i]) - Number(pb[i]);
            if (d !== 0)
                return d < 0 ? -1 : 1;
        } else if (na !== nb) {
            return na ? -1 : 1;
        } else if (pa[i] !== pb[i]) {
            return pa[i] < pb[i] ? -1 : 1;
        }
    }
    return 0;
}

// -1 / 0 / 1; unparsable versions compare as equal to anything (never newer).
function compare(a, b) {
    var x = parse(a), y = parse(b);
    if (!x || !y)
        return 0;
    for (var i = 0; i < Math.max(x.nums.length, y.nums.length); i++) {
        var d = (x.nums[i] || 0) - (y.nums[i] || 0);
        if (d !== 0)
            return d < 0 ? -1 : 1;
    }
    if (x.pre === y.pre)
        return 0;
    // A release is newer than its pre-releases
    if (x.pre === "")
        return 1;
    if (y.pre === "")
        return -1;
    return comparePre(x.pre, y.pre);
}

function isNewer(latest, current) {
    return compare(latest, current) > 0;
}

// The highest version among GitHub tags ([{name}], in any order). Pre-releases
// count only when the installed version is one too.
function latest(tags, current) {
    var cur = parse(current);
    var allowPre = !!(cur && cur.pre);
    var best = "";
    (Array.isArray(tags) ? tags : []).forEach(function (t) {
        var name = t && t.name ? String(t.name).replace(/^v/, "") : "";
        var p = parse(name);
        if (!p || (p.pre !== "" && !allowPre))
            return;
        if (best === "" || compare(name, best) > 0)
            best = name;
    });
    return best;
}
