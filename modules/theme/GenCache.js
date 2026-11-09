.pragma library

// Skip app theme generators whose inputs did not change (Colors.qml,
// GeneratorCache.qml). Every start used to rewrite all of them (~0.6 s of
// processes) although the palette and settings were the same as last time.
// The record (cache dir, theme-generators.json) maps a generator to the
// fingerprint of the inputs it last ran with and when.
//
// Inputs are what the generators read: the colors.json text, the theme /
// terminal / kitty / lock screen keys they use, the glass terminal opacity,
// the wallpaper, the shell dir (a new install path on Nix updates) and
// VERSION. Bump VERSION when a generator's output changes, so existing
// installs rewrite once. A record older than MAX_AGE_MS runs anyway (an app
// installed later, a deleted output file); "regenerate now" forces a run.

var VERSION = 1;
var MAX_AGE_MS = 24 * 3600 * 1000;

// Deterministic JSON: object keys sorted at every level.
function stableStringify(v) {
    if (v === undefined || typeof v === "function")
        return "null";
    if (v === null || typeof v !== "object")
        return JSON.stringify(v);
    if (Array.isArray(v))
        return "[" + v.map(stableStringify).join(",") + "]";
    const keys = Object.keys(v).sort();
    return "{" + keys.map(k => JSON.stringify(k) + ":" + stableStringify(v[k])).join(",") + "}";
}

// Two FNV-1a 32-bit passes with different offsets: 16 hex chars.
function hash(str) {
    const s = String(str);
    let a = 0x811c9dc5;
    let b = 0x01000193 ^ 0x5bd1e995;
    for (let i = 0; i < s.length; i++) {
        const c = s.charCodeAt(i);
        a = Math.imul(a ^ c, 0x01000193) >>> 0;
        b = Math.imul(b ^ c, 0x01000193) >>> 0;
        b = (b ^ (b >>> 15)) >>> 0;
    }
    return ("00000000" + a.toString(16)).slice(-8) + ("00000000" + b.toString(16)).slice(-8);
}

function fingerprint(inputs) {
    return hash("v" + VERSION + ":" + stableStringify(inputs));
}

function parse(text) {
    try {
        const data = JSON.parse(String(text || ""));
        if (data && data.version === VERSION && data.generators && typeof data.generators === "object")
            return {
                "version": VERSION,
                "generators": data.generators
            };
    } catch (e) {}
    return {
        "version": VERSION,
        "generators": {}
    };
}

function serialize(stored) {
    return JSON.stringify(stored || parse(""), null, 2) + "\n";
}

// Which of `names` must run for inputs `fp` at time `now` (ms).
function plan(stored, names, fp, force, now) {
    const gens = stored && stored.generators ? stored.generators : {};
    const t = Number(now) || 0;
    const out = {
        "run": [],
        "skip": []
    };
    (names || []).forEach(name => {
        const rec = gens[name];
        const fresh = rec && rec.fp === fp && t - Number(rec.at || 0) < MAX_AGE_MS && t >= Number(rec.at || 0);
        (force || !fresh ? out.run : out.skip).push(name);
    });
    return out;
}

// The record after `names` ran with `fp` at `now`.
function record(stored, names, fp, now) {
    const gens = Object.assign({}, stored && stored.generators ? stored.generators : {});
    (names || []).forEach(name => {
        gens[name] = {
            "fp": fp,
            "at": Number(now) || 0
        };
    });
    return {
        "version": VERSION,
        "generators": gens
    };
}
