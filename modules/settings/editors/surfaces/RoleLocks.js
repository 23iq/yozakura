.pragma library
.import "../../../theme/VisualLanguage.js" as VisualLanguage
.import "../../../theme/GlassModel.js" as GlassModel
.import "../../../../config/JsonUtil.js" as JsonUtil

// Which fields of a surface role the shell can honour right now. The visual
// language (theme.language) rewrites opacity, border width, gradient and item
// color of some roles on top of the sr* config, and with Glass off a glass
// surface is drawn opaque, so editing those fields would change nothing.
// Derived by probing VisualLanguage.apply itself, so it cannot drift from it.
// Node-tested (tests/surface-role-locks.test.cjs).
//
// locks(language, glassEnabled, prop) -> {field: {kind, value?, language?}}
//   kind "forced"  the field is overridden (value = what is drawn)
//   kind "capped"  edits above `value` have no effect
//   kind "glass"   opacity ignored while Glass is off

var PROBE = {
    "gradient": [["__probeFill", 0]],
    "gradientType": "radial",
    "gradientAngle": 33,
    "opacity": 0.77,
    "border": ["__probeEdge", 3],
    "itemColor": "__probeItem"
};

var FILL_FIELDS = ["gradient", "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY", "halftoneDotColor", "halftoneBackgroundColor", "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd"];

function variantId(prop) {
    return String(prop).substring(2).toLowerCase();
}

function same(a, b) {
    return JsonUtil.deepEqual(a, b);
}

function locks(language, glassEnabled, prop) {
    var out = {};
    var id = variantId(prop);
    var res = VisualLanguage.apply(language, id, PROBE);
    var lang = VisualLanguage.normalize(language);
    var i;
    if (res && res !== PROBE) {
        if (!same(res.gradient, PROBE.gradient) || res.gradientType !== PROBE.gradientType) {
            for (i = 0; i < FILL_FIELDS.length; i++)
                out[FILL_FIELDS[i]] = { "kind": "forced", "language": lang };
        }
        if (res.itemColor !== PROBE.itemColor)
            out.itemColor = { "kind": "forced", "language": lang };
        if (res.border && res.border[1] !== PROBE.border[1])
            out.borderWidth = { "kind": "forced", "value": res.border[1], "language": lang };
        if (res.border && res.border[0] !== PROBE.border[0])
            out.borderColor = { "kind": "forced", "language": lang };
        if (res.opacity !== PROBE.opacity) {
            // a cap leaves lower opacities alone, a forced value does not
            var low = {};
            for (var k in PROBE)
                low[k] = PROBE[k];
            low.opacity = 0.2;
            var res2 = VisualLanguage.apply(language, id, low);
            out.opacity = res2 && res2.opacity !== res.opacity ? {
                "kind": "capped",
                "value": res.opacity,
                "language": lang
            } : {
                "kind": "forced",
                "value": res.opacity,
                "language": lang
            };
        }
    }
    if (!out.opacity && !glassEnabled && GlassModel.GLASS_VARIANTS[id] !== undefined)
        out.opacity = { "kind": "glass" };
    return out;
}

// What the editor says in its one-line notes: the language that rewrites
// fields of this role (+ their names, picker-field order) and whether the
// opacity is ignored because Glass is off.
function summary(lockMap) {
    var out = {
        "language": "",
        "fields": [],
        "glass": false
    };
    var order = ["opacity", "borderColor", "borderWidth", "itemColor", "gradient"];
    for (var i = 0; i < order.length; i++) {
        var l = lockMap[order[i]];
        if (!l)
            continue;
        if (l.kind === "glass")
            out.glass = true;
        else {
            out.language = l.language;
            out.fields.push(order[i]);
        }
    }
    return out;
}
