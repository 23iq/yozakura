.pragma library

// Pure model of the surface-role editor (SurfaceRolesEditor.qml): the sr*
// variants of theme.js every StyledRect is drawn with, and the fields of
// one variant. A role object is `Config.theme.<prop>` (or a plain copy):
// {gradient: [[spec, pos], ...], gradientType, border: [spec, width], ...}.
// Node-tested (tests/surface-roles.test.cjs).

// The sr* variants, grouped as the role picker shows them.
var GROUPS = [
    {
        "id": "surfaces",
        "label": "prefs.surfaces.group.surfaces",
        "props": ["srBg", "srPopup", "srInternalBg", "srBarBg", "srFrame", "srPane", "srCommon", "srFocus"]
    },
    {
        "id": "accents",
        "label": "prefs.surfaces.group.accents",
        "props": ["srPrimary", "srPrimaryFocus", "srOverPrimary", "srSecondary", "srSecondaryFocus", "srOverSecondary", "srTertiary", "srTertiaryFocus", "srOverTertiary", "srError", "srErrorFocus", "srOverError"]
    }
];

// Stored sub-keys of every variant (srFrame also has inheritBg).
var STORED = ["gradient", "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY", "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd", "halftoneDotColor", "halftoneBackgroundColor", "border", "itemColor", "opacity"];

var GRADIENT_TYPES = ["linear", "radial", "halftone"];

var PERCENT = {
    "min": 0,
    "max": 100,
    "step": 1,
    "scale": 100,
    "unit": "%"
};
var DOT = {
    "min": 0,
    "max": 20,
    "step": 0.5,
    "unit": "px"
};

function merged(base, extra) {
    var out = {};
    for (var k in base)
        out[k] = base[k];
    for (var j in extra)
        out[j] = extra[j];
    return out;
}

function field(name, kind, group, label, extra) {
    return merged({
        "field": name,
        "kind": kind,
        "group": group,
        "label": "prefs.surfaces." + label
    }, extra || {});
}

// Editor fields. `field` is the stored sub-key, except the border pair
// (borderColor/borderWidth both write `border`). `scale` maps the stored
// value to the slider's (0..1 -> 0..100 %). `types`: shown only for these
// gradient types; `only`: shown only when the variant has that sub-key.
var FIELDS = [
    field("inheritBg", "toggle", "main", "follow_bg", {
        "only": "inheritBg",
        "description": "prefs.surfaces.follow_bg.desc"
    }),
    field("gradient", "fill", "main", "fill", {
        "types": ["linear", "radial"],
        "description": "prefs.surfaces.fill.desc"
    }),
    field("opacity", "slider", "main", "opacity", PERCENT),
    field("borderColor", "color", "main", "border_color"),
    field("borderWidth", "slider", "main", "border_width", {
        "min": 0,
        "max": 16,
        "step": 1,
        "unit": "px"
    }),
    field("itemColor", "color", "main", "item_color", {
        "description": "prefs.surfaces.item_color.desc"
    }),
    field("gradientType", "selector", "more", "type", {
        "options": [
            {
                "value": "linear",
                "label": "prefs.surfaces.type.linear"
            },
            {
                "value": "radial",
                "label": "prefs.surfaces.type.radial"
            },
            {
                "value": "halftone",
                "label": "prefs.surfaces.type.halftone"
            }
        ]
    }),
    field("gradientAngle", "slider", "more", "angle", {
        "types": ["linear", "halftone"],
        "min": 0,
        "max": 360,
        "step": 1,
        "unit": "°"
    }),
    field("gradientCenterX", "slider", "more", "center_x", merged(PERCENT, {
        "types": ["radial"]
    })),
    field("gradientCenterY", "slider", "more", "center_y", merged(PERCENT, {
        "types": ["radial"]
    })),
    field("halftoneDotColor", "color", "more", "dot_color", {
        "types": ["halftone"]
    }),
    field("halftoneBackgroundColor", "color", "more", "dot_background", {
        "types": ["halftone"]
    }),
    field("halftoneDotMin", "slider", "more", "dot_min", merged(DOT, {
        "types": ["halftone"]
    })),
    field("halftoneDotMax", "slider", "more", "dot_max", merged(DOT, {
        "types": ["halftone"]
    })),
    field("halftoneStart", "slider", "more", "range_start", merged(PERCENT, {
        "types": ["halftone"]
    })),
    field("halftoneEnd", "slider", "more", "range_end", merged(PERCENT, {
        "types": ["halftone"]
    }))
];

// StyledRect variant id of a role (srPrimaryFocus -> primaryfocus).
function variantId(prop) {
    return String(prop).substring(2).toLowerCase();
}

// i18n key of a role's name (srPrimaryFocus -> prefs.surfaces.role.primaryfocus).
function roleLabel(prop) {
    return "prefs.surfaces.role." + variantId(prop);
}

function roles() {
    var out = [];
    for (var g = 0; g < GROUPS.length; g++)
        out = out.concat(options(GROUPS[g]).map(function (o) {
            return {
                "prop": o.value,
                "label": o.label
            };
        }));
    return out;
}

// SelectorControl options of one picker group.
function options(group) {
    return group.props.map(function (p) {
        return {
            "value": p,
            "label": roleLabel(p)
        };
    });
}

// Every settings key the editor writes (reset/modified state), given the
// theme defaults (config/defaults/theme.js `data`).
function keys(defaults) {
    var out = [];
    var all = roles();
    for (var i = 0; i < all.length; i++) {
        var prop = all[i].prop;
        var role = defaults ? defaults[prop] : null;
        if (role && role.inheritBg !== undefined)
            out.push("theme." + prop + ".inheritBg");
        for (var j = 0; j < STORED.length; j++)
            out.push("theme." + prop + "." + STORED[j]);
    }
    return out;
}

function typeOf(role) {
    var t = role ? role.gradientType : "";
    return GRADIENT_TYPES.indexOf(t) >= 0 ? t : "linear";
}

// Fields of `group` ("main" | "more") shown for this variant.
function fields(role, group) {
    var t = typeOf(role);
    return FIELDS.filter(function (f) {
        if (f.group !== group || (f.types && f.types.indexOf(t) < 0))
            return false;
        return !f.only || (!!role && role[f.only] !== undefined);
    });
}

function fieldDef(name) {
    for (var i = 0; i < FIELDS.length; i++) {
        if (FIELDS[i].field === name)
            return FIELDS[i];
    }
    return null;
}

// [[spec, pos], ...] -> [spec, ...] (the color-role control's stops).
function stopsOf(gradient) {
    var out = [];
    var n = gradient ? gradient.length : 0;
    for (var i = 0; i < n; i++) {
        var s = gradient[i];
        var spec = s && typeof s === "object" ? s[0] : s;
        if (typeof spec === "string" && spec !== "")
            out.push(spec);
    }
    return out;
}

// [spec, ...] -> [[spec, pos], ...]: keeps the old positions while the
// stop count is unchanged, else spreads the stops evenly.
function gradientOf(stops, previous) {
    var n = stops.length;
    var keep = previous && previous.length === n;
    var out = [];
    for (var i = 0; i < n; i++) {
        var pos = n > 1 ? Math.round(i / (n - 1) * 1000) / 1000 : 0;
        if (keep && previous[i] && typeof previous[i][1] === "number")
            pos = previous[i][1];
        out.push([stops[i], pos]);
    }
    return out;
}

function borderOf(role) {
    var b = role ? role.border : null;
    return [b && typeof b[0] === "string" ? b[0] : "surfaceBright", b && typeof b[1] === "number" ? b[1] : 0];
}

// Value of a field as its control shows it.
function read(role, name) {
    var f = fieldDef(name);
    if (!role || !f)
        return undefined;
    if (name === "gradient")
        return stopsOf(role.gradient);
    if (name === "borderColor")
        return borderOf(role)[0];
    if (name === "borderWidth")
        return borderOf(role)[1];
    if (name === "gradientType")
        return typeOf(role);
    if (f.kind === "slider")
        return Number(role[name] || 0) * (f.scale || 1);
    return role[name];
}

function write(sub, value) {
    return {
        "sub": sub,
        "value": value
    };
}

// Writes for a control's new value: [{sub, value}] relative to the variant
// ("theme.<prop>.<sub>"). Editing a variant that follows Background
// (srFrame.inheritBg) detaches it first, as the legacy editor did.
function writes(role, name, value) {
    var f = fieldDef(name);
    if (!f)
        return [];
    var out = [];
    if (name !== "inheritBg" && role && role.inheritBg === true)
        out.push(write("inheritBg", false));
    if (name === "gradient")
        out.push(write("gradient", gradientOf(stopsOf(value), role ? role.gradient : null)));
    else if (name === "borderColor")
        out.push(write("border", [value, borderOf(role)[1]]));
    else if (name === "borderWidth")
        out.push(write("border", [borderOf(role)[0], Math.round(value)]));
    else if (f.kind === "slider")
        out.push(write(name, Math.round(value / (f.scale || 1) * 1000) / 1000));
    else
        out.push(write(name, value));
    return out;
}
