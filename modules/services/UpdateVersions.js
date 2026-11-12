.pragma library

// Version rules of the update notice, per update channel
// (system.updateChannel): stable = X.Y.Z tags, beta = X.Y.Z-beta.N tags plus
// any newer stable tag, git = the tip of main. The same rules as the
// backend (backend/pkg/updatechannel) and install.sh (pick_tag), checked
// against the shared cases of tests/fixtures/update-channels.json in
// tests/update-versions.test.cjs.

var CHANNELS = ["stable", "beta", "git"];

// The last release without update channels: only newer releases are a tag
// channel's target (backend LastWithoutChannels, install.sh
// LAST_RELEASE_WITHOUT_CHANNELS).
var LAST_WITHOUT_CHANNELS = "0.3.1";

// Each number: 0 or up to nine digits without a leading zero.
var VERSION_RE = /^v?(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-beta\.(0|[1-9][0-9]{0,8}))?$/;

function channel(name) {
    return CHANNELS.indexOf(name) >= 0 ? name : "stable";
}

// "v0.3.2-beta.1" -> {major: 0, minor: 3, patch: 2, beta: 1}; beta is -1 for
// a release. null for anything else (rc tags, two-part versions, metadata,
// leading zeros, numbers of ten digits or more).
function parse(text) {
    var m = VERSION_RE.exec(String(text === undefined || text === null ? "" : text).trim());
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

// Whether a parsed version is newer than LAST_WITHOUT_CHANNELS.
function hasChannels(v) {
    return !!v && compareParsed(v, parse(LAST_WITHOUT_CHANNELS)) > 0;
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
// beta, "" for git or when none matches. Releases up to LAST_WITHOUT_CHANNELS
// never match. Of two spellings of one version the one without "v" wins.
function select(tags, channelName) {
    if (channelName !== "stable" && channelName !== "beta")
        return "";
    var best = null, bestTag = "";
    (Array.isArray(tags) ? tags : []).forEach(function (t) {
        var name = tagName(t);
        var v = parse(name);
        if (!v || (v.beta >= 0 && channelName !== "beta") || !hasChannels(v))
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

// Whether the git channel's notice applies to a checkout on this branch
// (`git rev-parse --abbrev-ref HEAD`): it compares with the tip of main, so
// a checkout on main or detached (a release, which an update returns to
// main) gets it, one following another branch (install.sh --branch, a
// branch of the user's) does not.
function gitFollowsMain(branch) {
    var b = String(branch || "").trim();
    return b === "" || b === "HEAD" || b === "main";
}

// "main @ 1a2b3c4": how the git channel names its target.
function gitLabel(tip) {
    return "main @ " + String(tip || "").substring(0, 7);
}

// The most pages of 100 tags an update check reads.
var MAX_TAG_PAGES = 10;

// The rel="next" URL of a GitHub Link header, "" when there is none or it
// does not start with base (the API the check reads).
function nextPage(link, base) {
    var parts = String(link || "").split(",");
    for (var i = 0; i < parts.length; i++) {
        var m = /^\s*<([^>]*)>\s*;\s*rel="next"\s*$/.exec(parts[i]);
        if (m && base && m[1].indexOf(base + "/") === 0)
            return m[1];
    }
    return "";
}
