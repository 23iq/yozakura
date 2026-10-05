.pragma library

// Pure helpers of the preset studio (gallery filters, mixer composition,
// editor formatting). Data comes from `<app> preset list|aspects|show
// --json` (backend/pkg/presets); nothing here knows a preset by name.
// Node-tested in tests/preset-studio.test.cjs.

// Bump when the thumbnail drawing changes: cached PNGs are re-rendered.
var THUMB_VERSION = 1;

var FILTERS = ["all", "builtin", "user", "dark", "light"];

function isLight(p) {
    return !!(p && p.look && p.look["theme.lightMode"]);
}

function matchesFilter(p, filter) {
    switch (filter) {
    case "builtin":
        return p.official;
    case "user":
        return !p.official;
    case "light":
        return isLight(p);
    case "dark":
        return !isLight(p);
    }
    return true;
}

// Presets matching a search query (name, author, description, tags) and a
// filter id of FILTERS. Order is kept (built-ins first, by name).
function filter(list, query, kind) {
    var q = (query || "").trim().toLowerCase();
    return (list || []).filter(function (p) {
        if (!matchesFilter(p, kind || "all"))
            return false;
        if (!q)
            return true;
        var hay = [p.name, p.author, p.description].concat(p.tags || []).join(" ").toLowerCase();
        return q.split(/\s+/).every(function (w) {
            return hay.indexOf(w) !== -1;
        });
    });
}

function byName(list, name) {
    for (var i = 0; list && i < list.length; i++) {
        if (list[i].name === name)
            return list[i];
    }
    return null;
}

// Tags come from presets.TagsOf (Go): bar style, mode, frame, bar edge.
var TAG_LABELS = {
    "classic": "prefs.presets.tag.classic",
    "islands": "prefs.presets.tag.islands",
    "light": "prefs.presets.tag.light",
    "dark": "prefs.presets.tag.dark",
    "oled": "prefs.presets.tag.oled",
    "frame": "prefs.presets.tag.frame",
    "bar-bottom": "prefs.presets.tag.bar-bottom",
    "bar-left": "prefs.presets.tag.bar-left",
    "bar-right": "prefs.presets.tag.bar-right"
};

// i18n key of a tag; an unknown tag shows as itself.
function tagLabel(tag) {
    return TAG_LABELS[tag] || tag;
}

// Aspect of a dotted key, mirroring presets.AspectOf in Go: an aspect's
// moved keys win over domain ownership; "other" when nothing matches.
function aspectOf(aspects, key) {
    var i, j;
    for (i = 0; i < (aspects || []).length; i++) {
        var keys = aspects[i].keys || [];
        for (j = 0; j < keys.length; j++) {
            if (key === keys[j] || key.indexOf(keys[j] + ".") === 0)
                return aspects[i].id;
        }
    }
    var domain = key.split(".")[0];
    for (i = 0; i < (aspects || []).length; i++) {
        if ((aspects[i].domains || []).indexOf(domain) !== -1)
            return aspects[i].id;
    }
    return "other";
}

// The look a mix would have: each look key from the preset chosen for its
// aspect (sources: {aspect: presetName}); "other" keys from `fallback`.
function composeLook(aspects, presets, sources, fallback) {
    var out = {};
    var base = byName(presets, fallback);
    var keys = {};
    (presets || []).forEach(function (p) {
        Object.keys(p.look || {}).forEach(function (k) {
            keys[k] = true;
        });
    });
    Object.keys(keys).forEach(function (k) {
        var src = byName(presets, sources[aspectOf(aspects, k)]) || base;
        if (src && src.look && k in src.look)
            out[k] = src.look[k];
    });
    return out;
}

// Mixer starting point: every aspect from the active preset (or the first).
function defaultSources(aspects, presets, active) {
    var name = byName(presets, active) ? active : ((presets && presets.length) ? presets[0].name : "");
    var out = {};
    (aspects || []).forEach(function (a) {
        out[a.id] = name;
    });
    return out;
}

// `base`, or `base 2`, `base 3`... not taken by a preset (case-insensitive).
function uniqueName(presets, base) {
    var taken = {};
    (presets || []).forEach(function (p) {
        taken[p.name.toLowerCase()] = true;
    });
    if (!taken[base.toLowerCase()])
        return base;
    for (var i = 2;; i++) {
        var n = base + " " + i;
        if (!taken[n.toLowerCase()])
            return n;
    }
}

// Name accepted by the backend (presets.validName); "" when fine, else an
// i18n key explaining why not.
function nameProblem(presets, name, except) {
    var n = name || "";
    if (!n.trim() || n !== n.trim() || n === "current" || n === "defaults" || n.charAt(0) === "." || /[\/\n]/.test(n))
        return "prefs.presets.name.invalid";
    for (var i = 0; presets && i < presets.length; i++) {
        var p = presets[i];
        if (p.name.toLowerCase() !== n.toLowerCase() || p.name === except)
            continue;
        return p.official ? "prefs.presets.name.builtin" : "prefs.presets.name.taken";
    }
    return "";
}

// Palette a look renders with: the matugen scheme palette of the current
// wallpaper in the look's mode ({scheme: {dark, light}} from `<app>
// schemes`), OLED blacking out the background roles. null when unknown.
function paletteFor(look, schemes) {
    if (!look || !schemes)
        return null;
    var s = schemes[look["wallpaper.matugenScheme"] || "scheme-tonal-spot"];
    var light = !!look["theme.lightMode"];
    var p = s ? s[light ? "light" : "dark"] : null;
    if (!p)
        return null;
    if (!light && look["theme.oledMode"]) {
        var o = {};
        Object.keys(p).forEach(function (k) {
            o[k] = p[k];
        });
        ["background", "surface", "surfaceDim", "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer"].forEach(function (k) {
            o[k] = "#000000";
        });
        return o;
    }
    return p;
}

// Thumbnail cache key material (hashed by the caller): the drawing
// version, the wallpaper, the look and the palette it is drawn with.
function thumbKey(look, wallpaper, palette, size) {
    var keys = Object.keys(look || {}).sort();
    var flat = keys.map(function (k) {
        return k + "=" + JSON.stringify(look[k]);
    }).join(";");
    var pal = palette ? Object.keys(palette).sort().map(function (k) {
        return palette[k];
    }).join(",") : "live";
    return [THUMB_VERSION, wallpaper || "", size || "", flat, pal].join("|");
}

// Compact display of a config value in the editor's change list.
function formatValue(v) {
    if (v === undefined || v === null)
        return "—";
    if (typeof v === "boolean")
        return v ? "on" : "off";
    if (typeof v === "number")
        return String(Math.round(v * 100) / 100);
    if (typeof v === "string")
        return v === "" ? "\"\"" : v;
    var s = JSON.stringify(v);
    return s.length > 40 ? s.slice(0, 39) + "…" : s;
}

// Settings page for a change ({category} from the catalog), falling back
// to the aspect's page; never a category the settings window lacks.
function jumpTarget(change, aspect, known) {
    var c = change && change.category;
    if (c && (!known || known(c)))
        return {
            "category": c,
            "section": change.section || "",
            "entry": change.entry || ""
        };
    return {
        "category": aspect ? aspect.category : "appearance",
        "section": "",
        "entry": ""
    };
}

// "12 s" countdown label.
function seconds(ms) {
    return Math.max(0, Math.ceil(ms / 1000));
}

var ASPECT_ICONS = {
    "layout": "squaresFour",
    "colors": "palette",
    "windows": "compositor",
    "desktop": "monitor",
    "lockscreen": "lock",
    "other": "stack"
};

function aspectIcon(id) {
    return ASPECT_ICONS[id] || "stack";
}

// A different random source per aspect (mixer "shuffle"); rand() in [0, 1).
function shuffle(aspects, presets, rand) {
    var out = {};
    var r = rand || Math.random;
    (aspects || []).forEach(function (a) {
        if (presets && presets.length)
            out[a.id] = presets[Math.floor(r() * presets.length) % presets.length].name;
    });
    return out;
}
