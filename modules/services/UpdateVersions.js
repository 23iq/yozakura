.pragma library

// Version rules of the update notice, per update channel
// (system.updateChannel): stable = X.Y.Z tags, beta = X.Y.Z-beta.N tags plus
// any newer stable tag, git = the tip of main. The same rules as the
// backend (backend/pkg/updatechannel) and install.sh (pick_tag), checked
// against the shared cases of tests/fixtures/update-channels.json in
// tests/update-versions.test.cjs.

var CHANNELS = ["stable", "beta", "git"];

function channel(name) {
    return CHANNELS.indexOf(name) >= 0 ? name : "stable";
}

// "v0.3.2-beta.1" -> {major: 0, minor: 3, patch: 2, beta: 1}; beta is -1 for
// a release. null for anything else (rc tags, two-part versions, metadata).
function parse(text) {
    var m = /^v?(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))?$/.exec(String(text === undefined || text === null ? "" : text).trim());
    if (!m)
        return null;
    return {
        "major": Number(m[1]),
        "minor": Number(m[2]),
        "patch": Number(m[3]),
        "beta": m[4] === undefined ? -1 : Number(m[4])
    };
}

function format(v) {
    return v.major + "." + v.minor + "." + v.patch + (v.beta >= 0 ? "-beta." + v.beta : "");
}

function sign(d) {
    return d < 0 ? -1 : (d > 0 ? 1 : 0);
}

function compareParsed(x, y) {
    var d = sign(x.major - y.major) || sign(x.minor - y.minor) || sign(x.patch - y.patch);
    if (d !== 0)
        return d;
    if ((x.beta >= 0) === (y.beta >= 0))
        return sign(x.beta - y.beta);
    // a release is above its own betas
    return x.beta >= 0 ? -1 : 1;
}

// -1 / 0 / 1; unparsable versions compare as equal to anything (never newer).
function compare(a, b) {
    var x = parse(a), y = parse(b);
    if (!x || !y)
        return 0;
    return compareParsed(x, y);
}

function isNewer(latest, current) {
    return compare(latest, current) > 0;
}

function tagName(t) {
    if (t && typeof t === "object")
        return t.name ? String(t.name) : "";
    return t === undefined || t === null ? "" : String(t);
}

// The tag a channel moves to among GitHub tags ([{name}] or names, any
// order): the highest release for stable, the highest release or beta for
// beta, "" for git or when none matches. Of two spellings of one version
// the one without "v" wins.
function select(tags, channelName) {
    if (channelName !== "stable" && channelName !== "beta")
        return "";
    var best = null, bestTag = "";
    (Array.isArray(tags) ? tags : []).forEach(function (t) {
        var name = tagName(t);
        var v = parse(name);
        if (!v || (v.beta >= 0 && channelName !== "beta"))
            return;
        if (best === null) {
            best = v;
            bestTag = name;
            return;
        }
        var d = compareParsed(v, best);
        if (d > 0 || (d === 0 && bestTag.charAt(0) === "v" && name.charAt(0) !== "v")) {
            best = v;
            bestTag = name;
        }
    });
    return bestTag;
}

// `git describe --tags --long --always --abbrev=40` -> {tag, distance,
// commit}; tag is "" when HEAD has no tag behind it (the output is then the
// bare commit) or the text is empty.
function describe(text) {
    var s = String(text || "").trim();
    var m = /^(.+)-(\d+)-g([0-9a-f]{7,40})$/.exec(s);
    if (m)
        return {
            "tag": m[1],
            "distance": Number(m[2]),
            "commit": m[3]
        };
    if (/^[0-9a-f]{7,40}$/.test(s))
        return {
            "tag": "",
            "distance": -1,
            "commit": s
        };
    return {
        "tag": "",
        "distance": -1,
        "commit": ""
    };
}

// The installed version for a tag channel: the version file, or the newest
// release tag the checkout contains when that is higher (a checkout past a
// release whose version file was not bumped is not behind it).
function installed(versionFile, described) {
    var tag = described && described.tag ? described.tag : "";
    var t = parse(tag), f = parse(versionFile);
    if (t && (!f || compareParsed(t, f) > 0))
        return format(t);
    return String(versionFile || "");
}

// The tag channels' verdict: the target when it is newer than the
// installed version, else "".
function tagUpdate(tags, channelName, installedVersion) {
    var target = select(tags, channelName);
    return target !== "" && isNewer(target, installedVersion) ? target : "";
}

// The git channel's verdict from the remote tip of main and the local
// state: "same" (HEAD is the tip), "check" (ask git whether the tip is an
// ancestor of HEAD), "unknown" (no commit to compare).
function gitCompare(remoteTip, localCommit) {
    var tip = String(remoteTip || "").trim().toLowerCase();
    var local = String(localCommit || "").trim().toLowerCase();
    if (!/^[0-9a-f]{40}$/.test(tip) || local === "")
        return "unknown";
    return tip.indexOf(local) === 0 ? "same" : "check";
}

// "main @ 1a2b3c4": how the git channel names its target.
function gitLabel(tip) {
    return "main @ " + String(tip || "").substring(0, 7);
}
