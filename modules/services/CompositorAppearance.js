.pragma library

// Single source of truth for the compositor appearance. CompositorConfig
// dispatches the object built here live (hl.config eval) and
// CompositorTomlWriter persists the very same object through the backend,
// which renders it into the generated hyprland.{lua,conf}. Keeping both
// paths on these pure helpers is what makes the persisted config lossless:
// gradients + angle, shadow colors with opacity and every blur key survive
// a Hyprland reload exactly as they were applied live.
//
// Colors are passed around as plain {r, g, b, a} objects with channels in
// [0, 1] (QML color values satisfy that shape), so everything here is
// testable from node without Qt.

function toArray(list) {
    if (list === null || list === undefined)
        return [];
    if (Array.isArray(list))
        return list.slice();
    // QVariantList / QML sequence types fail Array.isArray but are indexable.
    if (typeof list === "object" && typeof list.length === "number") {
        const out = [];
        for (let i = 0; i < list.length; i++)
            out.push(list[i]);
        return out;
    }
    return [list];
}

function hex2(v) {
    const n = Math.max(0, Math.min(255, Math.round(v * 255)));
    return n.toString(16).padStart(2, "0");
}

// Hyprland color literal: rgb(rrggbb) when opaque, rgba(rrggbbaa) otherwise.
function formatColor(color) {
    const rgb = hex2(color.r) + hex2(color.g) + hex2(color.b);
    const a = hex2(color.a === undefined ? 1 : color.a);
    return a === "ff" ? "rgb(" + rgb + ")" : "rgba(" + rgb + a + ")";
}

// Multiplies the color's alpha by factor (shadow opacity).
function withAlpha(color, factor) {
    const a = (color.a === undefined ? 1 : color.a) * (typeof factor === "number" && isFinite(factor) ? factor : 1);
    return { r: color.r, g: color.g, b: color.b, a: Math.max(0, Math.min(1, a)) };
}

// Border value in the shape hl.config() takes: a single color string, or
// a { colors, angle } gradient table when more than one color is given.
// `resolve` maps a color spec (role, literal, "role@alpha") to a color.
function borderValue(specs, angle, fallbackSpec, resolve) {
    let list = toArray(specs).filter(s => typeof s === "string" && s.length > 0);
    if (list.length === 0)
        list = [fallbackSpec];
    const colors = list.map(s => formatColor(resolve(s)));
    if (colors.length === 1)
        return colors[0];
    return { colors: colors, angle: (typeof angle === "number" && isFinite(angle)) ? angle : 0 };
}

// Legacy/daemon string form of a border value: "c1 c2 45deg" or "c1".
function borderString(value) {
    if (typeof value === "string")
        return value;
    if (value && value.colors)
        return value.colors.join(" ") + " " + value.angle + "deg";
    return "";
}

// First color of a border value (targets that can't render gradients).
function firstColor(value) {
    if (typeof value === "string")
        return value;
    if (value && value.colors && value.colors.length > 0)
        return value.colors[0];
    return "";
}

function num(v, fallback) {
    return (typeof v === "number" && isFinite(v)) ? v : fallback;
}

function bool(v, fallback) {
    return (typeof v === "boolean") ? v : fallback;
}

// Builds the hl.config() table for general + decoration.
//
// opts:
//   compositor    Config.compositor (or a plain object with the same keys)
//   resolve       function(spec) -> {r, g, b, a}
//   borderSize    resolved border size (Config.compositorBorderSize)
//   rounding      resolved rounding (Config.compositorRounding)
//   borderColor   synced active border spec (Config.compositorBorderColor)
//   shadowColor   resolved shadow color spec (Config.compositorShadowColor)
//   shadowOpacity resolved shadow opacity (Config.compositorShadowOpacity)
//   layout        optional general.layout
//   glass         optional Glass.compositor (blur, window opacity and shadow
//                 softness resolved by the glass system, see applyGlass)
function buildHyprlandConfig(opts) {
    const c = opts.compositor || {};
    const resolve = opts.resolve;

    const activeSpecs = c.syncBorderColor ? [opts.borderColor || "primary"] : c.activeBorderColor;
    const activeBorder = borderValue(activeSpecs, num(c.borderAngle, 45), opts.borderColor || "primary", resolve);
    const inactiveBorder = borderValue(c.inactiveBorderColor, num(c.inactiveBorderAngle, 45), "surface", resolve);

    const shadowOpacity = num(opts.shadowOpacity, num(c.shadowOpacity, 0.5));
    const shadowColor = formatColor(withAlpha(resolve(opts.shadowColor || c.shadowColor || "shadow"), shadowOpacity));
    const shadowColorInactive = formatColor(withAlpha(resolve(c.shadowColorInactive || "shadow"), shadowOpacity));

    const general = {
        gaps_in: num(c.gapsIn, 0),
        gaps_out: num(c.gapsOut, 0),
        border_size: num(opts.borderSize, num(c.borderSize, 2)),
        col: {
            active_border: activeBorder,
            inactive_border: inactiveBorder,
        },
    };
    if (opts.layout)
        general.layout = opts.layout;

    return applyGlass({
        general: general,
        decoration: {
            rounding: num(opts.rounding, num(c.rounding, 0)),
            dim_inactive: bool(c.dimInactive, false),
            dim_strength: num(c.dimStrength, 0.1),
            active_opacity: num(c.activeOpacity, 1.0),
            inactive_opacity: num(c.inactiveOpacity, 1.0),
            shadow: {
                enabled: bool(c.shadowEnabled, true),
                range: num(c.shadowRange, 8),
                render_power: num(c.shadowRenderPower, 3),
                sharp: bool(c.shadowSharp, false),
                // shadow:ignore_window was removed in Hyprland 0.56; the
                // setting stays in Config but is not dispatched.
                color: shadowColor,
                color_inactive: shadowColorInactive,
                // A half-typed offset must not make Hyprland reject the table.
                offset: /^-?\d+(\.\d+)? -?\d+(\.\d+)?$/.test(String(c.shadowOffset || "").trim()) ? String(c.shadowOffset).trim() : "0 0",
                scale: num(c.shadowScale, 1.0),
            },
            blur: {
                enabled: bool(c.blurEnabled, true),
                size: num(c.blurSize, 4),
                passes: num(c.blurPasses, 2),
                ignore_opacity: bool(c.blurIgnoreOpacity, true),
                new_optimizations: bool(c.blurNewOptimizations, true),
                xray: bool(c.blurXray, false),
                noise: num(c.blurNoise, 0.0),
                contrast: num(c.blurContrast, 1.0),
                brightness: num(c.blurBrightness, 1.0),
                vibrancy: num(c.blurVibrancy, 0.0),
                vibrancy_darkness: num(c.blurVibrancyDarkness, 0.0),
                special: bool(c.blurSpecial, true),
                popups: bool(c.blurPopups, false),
                popups_ignorealpha: num(c.blurPopupsIgnorealpha, 0.2),
                input_methods: bool(c.blurInputMethods, false),
                input_methods_ignorealpha: num(c.blurInputMethodsIgnorealpha, 0.2),
            },
        },
    }, opts.glass);
}

// Overlays the glass system's effective values (GlassModel.compositor) on a
// built config: blur strength, window opacity and shadow range. At a
// preset's own glass amount these equal the configured values.
function applyGlass(hl, glass) {
    if (!glass)
        return hl;
    const d = hl.decoration;
    const b = glass.blur || {};
    const keys = ["enabled", "size", "passes", "noise", "contrast", "brightness", "vibrancy"];
    for (let i = 0; i < keys.length; i++) {
        if (b[keys[i]] !== undefined)
            d.blur[keys[i]] = b[keys[i]];
    }
    d.active_opacity = num(glass.activeOpacity, d.active_opacity);
    d.inactive_opacity = num(glass.inactiveOpacity, d.inactive_opacity);
    const scale = num(glass.shadowScale, 1);
    if (scale !== 1)
        d.shadow.range = Math.round(d.shadow.range * scale);
    return hl;
}

// Emits a Lua literal for a JS value (used for the live hl.config eval).
// Strings get JSON-style quoting, numbers/bools map to Lua, arrays become
// {a, b}, objects {key = value}. null/undefined/non-finite become nil and
// keys that are not Lua identifiers are skipped.
function luaLiteral(value) {
    if (value === null || value === undefined)
        return "nil";
    const t = typeof value;
    if (t === "string")
        return JSON.stringify(value);
    if (t === "number")
        return isFinite(value) ? String(value) : "nil";
    if (t === "boolean")
        return value ? "true" : "false";
    if (Array.isArray(value))
        return "{" + value.map(luaLiteral).join(", ") + "}";
    if (t === "object") {
        const parts = [];
        for (const key in value) {
            if (!Object.prototype.hasOwnProperty.call(value, key))
                continue;
            if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key))
                continue;
            parts.push(key + " = " + luaLiteral(value[key]));
        }
        return "{" + parts.join(", ") + "}";
    }
    return "nil";
}

// Smart gaps: no gaps on a workspace showing a single tiled window. A
// Hyprland workspace rule (w[tv1]) whose handle is kept in a Lua global so a
// later apply can switch the previous one off (rules have no other removal
// until the config reloads). Same text as backend/pkg/svc/compositor
// (smartGapsLua); no ';' because the yozd raw-batch wrapper splits on it.
var SMART_GAPS_SELECTOR = "w[tv1]";

function smartGapsLua(enabled) {
    const lines = [
        "if __smartGapsRule then pcall(function() __smartGapsRule:set_enabled(false) end) end",
        "__smartGapsRule = nil",
    ];
    if (enabled)
        lines.push("pcall(function() __smartGapsRule = hl.workspace_rule({ workspace = \"" + SMART_GAPS_SELECTOR + "\", gaps_in = 0, gaps_out = 0 }) end)");
    return lines.join(" ");
}
