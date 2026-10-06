.pragma library

// Renamed or moved config keys. Each alias copies the user's stored value
// from `from` to `to` ("<domain>.<path>", the domain is the config file)
// once, on the first load of the shell, then removes `from`:
//   {from: "bar.activities", to: "notch.activities"}
//   {from: "theme.terminalOpacity", to: "glass.surfaces.terminal.amount",
//    transform: function (v) { return v; }}
// An existing `to` value is never overwritten, unless it is one of the
// alias's `replaces` values (the target's untouched default); a transform
// that returns undefined writes nothing (the old key still goes). The `to`
// key must exist in
// config/defaults; the `from` key must not any more (the validator drops
// keys without a default). Run by ConfigValidator.migrateAliases through
// config/AliasGate.qml; tests in tests/key-aliases.test.cjs.

// A glass override (-1 = unset) becomes the compositor value it duplicated.
function setOr(round) {
    return function (v) {
        if (typeof v !== "number" || !isFinite(v) || v < 0)
            return undefined;
        return round ? Math.round(v) : v;
    };
}

var aliases = [
    // Live activity sources live with the island they show in.
    {
        "from": "bar.activities",
        "to": "notch.liveActivities"
    },
    // The island OSD switch is the OSD style "island".
    {
        "from": "notch.osd",
        "to": "layout.osd.style",
        "transform": function (v) {
            return v === true ? "island" : undefined;
        },
        "replaces": ["pill"]
    },
    // Glass blur/shadow overrides duplicated the compositor's own values.
    {
        "from": "theme.glass.advanced.blurSize",
        "to": "compositor.blurSize",
        "transform": setOr(true),
        "replaces": [4]
    },
    {
        "from": "theme.glass.advanced.blurPasses",
        "to": "compositor.blurPasses",
        "transform": setOr(true),
        "replaces": [2]
    },
    {
        "from": "theme.glass.advanced.vibrancy",
        "to": "compositor.blurVibrancy",
        "transform": setOr(false),
        "replaces": [0]
    },
    {
        "from": "theme.glass.advanced.noise",
        "to": "compositor.blurNoise",
        "transform": setOr(false),
        "replaces": [0]
    },
    {
        "from": "theme.glass.advanced.contrast",
        "to": "compositor.blurContrast",
        "transform": setOr(false),
        "replaces": [1]
    },
    {
        "from": "theme.glass.advanced.brightness",
        "to": "compositor.blurBrightness",
        "transform": setOr(false),
        "replaces": [1]
    },
    // Softness 0..1 scaled the window shadow range (8 px at 0).
    {
        "from": "theme.glass.advanced.shadowSoftness",
        "to": "compositor.shadowRange",
        "transform": function (v) {
            return typeof v === "number" && isFinite(v) && v >= 0 ? Math.round(8 * (1 + v)) : undefined;
        },
        "replaces": [8]
    }
];

// Config domains (file names) an alias reads or writes.
function domains(list) {
    var out = [];
    (list || aliases).forEach(function (a) {
        [a.from, a.to].forEach(function (key) {
            var d = String(key).split(".")[0];
            if (out.indexOf(d) === -1)
                out.push(d);
        });
    });
    return out;
}
