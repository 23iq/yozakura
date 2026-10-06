.pragma library

// Pure keyboard helpers (tests/keyboard-model.test.cjs).

// `us` shows as EN, anything else as its upper-cased layout code.
function shortName(layout) {
    var code = String(layout || "").toLowerCase();
    return code === "us" ? "EN" : code.toUpperCase();
}

// The XKB option each switch bind stands for (mirrors backend SwitchBindOption).
var SWITCH_OPTIONS = {
    "alt_shift": "grp:alt_shift_toggle",
    "super_space": "grp:win_space_toggle",
    "caps": "grp:caps_toggle",
    "ctrl_shift": "grp:ctrl_shift_toggle"
};

// Options the page offers as quick toggles.
var QUICK_OPTIONS = ["caps:escape", "ctrl:nocaps", "compose:ralt"];

function _list(value) {
    return Array.prototype.slice.call(value || []);
}

// Config keyboard domain -> compositor input {layouts: "us,ru", variants: ",",
// options: "grp:alt_shift_toggle,caps:escape"}: the switch-bind option first,
// then the user's, deduplicated. Entries without a layout are dropped.
function toSettings(cfg) {
    var layouts = _list(cfg && cfg.layouts).filter(function (l) {
        return l && l.layout;
    });
    var opts = [];
    var bind = SWITCH_OPTIONS[cfg && cfg.switchBind];
    if (bind)
        opts.push(bind);
    _list(cfg && cfg.options).forEach(function (o) {
        if (o && opts.indexOf(o) === -1)
            opts.push(o);
    });
    return {
        "layouts": layouts.map(function (l) {
            return l.layout;
        }).join(","),
        "variants": layouts.map(function (l) {
            return l.variant || "";
        }).join(","),
        "options": opts.join(",")
    };
}

function hasOption(options, name) {
    return _list(options).indexOf(name) !== -1;
}

// Options with `name` switched on or off.
function setOption(options, name, on) {
    var rest = _list(options).filter(function (o) {
        return o !== name;
    });
    if (on)
        rest.push(name);
    return rest;
}

// Layouts with `code` appended (once); the first variant stays default.
function addLayout(layouts, code, variant) {
    var list = _list(layouts).map(function (l) {
        return {
            "layout": l.layout,
            "variant": l.variant || ""
        };
    });
    if (code && !list.some(function (l) {
        return l.layout === code && l.variant === (variant || "");
    }))
        list.push({
            "layout": code,
            "variant": variant || ""
        });
    return list;
}

// Removes entry `index`; the last layout can never be removed.
function removeLayout(layouts, index) {
    var list = _list(layouts);
    if (list.length <= 1 || index < 0 || index >= list.length)
        return list;
    list.splice(index, 1);
    return list;
}

function moveLayout(layouts, from, to) {
    var list = _list(layouts);
    if (from < 0 || from >= list.length)
        return list;
    to = Math.max(0, Math.min(to, list.length - 1));
    var item = list.splice(from, 1)[0];
    list.splice(to, 0, item);
    return list;
}

function setVariant(layouts, index, variant) {
    return _list(layouts).map(function (l, i) {
        return {
            "layout": l.layout,
            "variant": i === index ? variant : (l.variant || "")
        };
    });
}

// Catalog layouts matching `query` (code or description), without `skip`
// codes already in use; prefix matches on the code come first.
function searchLayouts(catalog, query, skip) {
    var q = String(query || "").trim().toLowerCase();
    var used = _list(skip);
    var all = _list(catalog && catalog.layouts).filter(function (l) {
        return used.indexOf(l.name) === -1;
    });
    if (q === "")
        return all;
    var hits = all.filter(function (l) {
        return l.name.toLowerCase().indexOf(q) !== -1 || String(l.description || "").toLowerCase().indexOf(q) !== -1;
    });
    function rank(l) {
        return l.name.toLowerCase() === q ? 0 : (l.name.toLowerCase().indexOf(q) === 0 ? 1 : 2);
    }
    return hits.sort(function (a, b) {
        return rank(a) - rank(b);
    });
}

function layoutInfo(catalog, code) {
    return _list(catalog && catalog.layouts).filter(function (l) {
        return l.name === code;
    })[0] || null;
}

// [{value, label}] variant choices of a layout ("" = the default variant).
function variantOptions(catalog, code, defaultLabel) {
    var info = layoutInfo(catalog, code);
    var out = [
        {
            "value": "",
            "label": defaultLabel
        }
    ];
    _list(info && info.variants).forEach(function (v) {
        out.push({
            "value": v.name,
            "label": v.description || v.name
        });
    });
    return out;
}

// Catalog options grouped for the "All options" list: [{name, description,
// options: [{name, description}]}]. Switching options (grp:*) are handled by
// the switch-bind chips and skipped.
function groupOptions(catalog) {
    var groups = {};
    var order = [];
    _list(catalog && catalog.groups).forEach(function (g) {
        groups[g.name] = {
            "name": g.name,
            "description": g.description || g.name,
            "options": []
        };
        order.push(g.name);
    });
    _list(catalog && catalog.options).forEach(function (o) {
        if (!groups[o.group]) {
            groups[o.group] = {
                "name": o.group,
                "description": o.group,
                "options": []
            };
            order.push(o.group);
        }
        groups[o.group].options.push({
            "name": o.name,
            "description": o.description || o.name
        });
    });
    return order.filter(function (n) {
        return n !== "grp" && groups[n].options.length > 0;
    }).map(function (n) {
        return groups[n];
    });
}

// XKB layout of a locale's language (pt_BR is the one country variant).
var LOCALE_LAYOUTS = {
    "ru": "ru", "uk": "ua", "be": "by", "kk": "kz", "de": "de", "fr": "fr", "es": "es", "it": "it",
    "pt": "pt", "pl": "pl", "cs": "cz", "tr": "tr", "ja": "jp", "ko": "kr", "zh": "cn", "el": "gr",
    "he": "il", "ar": "ara"
};

// First-run layouts for a locale name ("ru_RU", "pt-BR.UTF-8"): `us` plus
// the locale's own layout; English and unknown languages get `us` only.
function defaultsForLocale(locale) {
    var name = String(locale || "").split(".")[0].replace("-", "_");
    var parts = name.split("_");
    var lang = parts[0].toLowerCase();
    var code = (lang === "pt" && (parts[1] || "").toUpperCase() === "BR") ? "br" : LOCALE_LAYOUTS[lang];
    return code ? ["us", code] : ["us"];
}
