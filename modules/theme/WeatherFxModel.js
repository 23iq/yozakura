.pragma library

// Weather on surfaces (theme.weatherFx, WeatherFx.qml): pure logic. Maps
// the current weather (WMO code + temperature in °C) and the season at the
// place to the effects drawn on shell surfaces, and how dense / how often.
// No QML here; tests/weather-fx.test.cjs.

var MODES = ["off", "subtle", "vivid"];
var TOGGLES = ["rain", "frost", "heat", "fog", "seasonal"];
// Conditions a preview can force (WeatherFx.previewCondition, the settings
// preview card); "" = the live weather.
var PREVIEWS = ["drizzle", "rain", "storm", "snow", "frost", "fog", "heat", "petals", "leaves"];

var FROST_C = 0;   // at or below: frost creeps in from the corners
var HEAT_C = 30;   // at or above: heat shimmer on the bar

var DEFAULTS = { mode: "off", rain: true, frost: true, heat: false, fog: true, seasonal: false };

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
    return a + (b - a) * clamp(t, 0, 1);
}

function normalizeMode(mode) {
    return MODES.indexOf(mode) !== -1 ? mode : "off";
}

// Config object -> every toggle a bool (missing keys take DEFAULTS).
function options(cfg) {
    var c = cfg || {};
    var out = { mode: normalizeMode(c.mode) };
    for (var i = 0; i < TOGGLES.length; i++) {
        var k = TOGGLES[i];
        out[k] = c[k] === undefined || c[k] === null ? DEFAULTS[k] : !!c[k];
    }
    return out;
}

// WMO weather code -> precipitation / sky: { sky, rain, snow, fog } with
// levels 0..1 (drizzle light, showers and storms heavy).
var RAIN = { 51: 0.25, 53: 0.35, 55: 0.45, 56: 0.3, 57: 0.45, 61: 0.5, 63: 0.7, 65: 0.95, 66: 0.55, 67: 0.9,
    80: 0.55, 81: 0.75, 82: 1, 95: 1, 96: 1, 99: 1 };
var SNOW = { 71: 0.35, 73: 0.6, 75: 0.9, 77: 0.3, 85: 0.6, 86: 0.9 };
var FOG = { 45: 0.6, 48: 0.85 };

function condition(code) {
    var c = Number(code);
    var out = { sky: "clear", rain: 0, snow: 0, fog: 0 };
    if (RAIN[c] !== undefined) {
        out.rain = RAIN[c];
        out.sky = c >= 95 ? "storm" : (c <= 57 ? "drizzle" : "rain");
    } else if (SNOW[c] !== undefined) {
        out.snow = SNOW[c];
        out.sky = "snow";
    } else if (FOG[c] !== undefined) {
        out.fog = FOG[c];
        out.sky = "fog";
    } else if (c === 2 || c === 3) {
        out.sky = "clouds";
    }
    return out;
}

function frostLevel(tempC) {
    if (!isFinite(tempC) || tempC > FROST_C)
        return 0;
    return clamp(0.45 + (FROST_C - tempC) / 12, 0, 1);
}

function heatLevel(tempC) {
    if (!isFinite(tempC) || tempC < HEAT_C)
        return 0;
    return clamp(0.4 + (tempC - HEAT_C) / 8, 0, 1);
}

// Unknown latitude counts as the northern hemisphere.
function hemisphere(lat) {
    return isFinite(lat) && lat < 0 ? "south" : "north";
}

// Meteorological season for a month (0 = January) at a latitude.
function season(lat, month) {
    var m = ((Math.floor(month) % 12) + 12) % 12;
    if (hemisphere(lat) === "south")
        m = (m + 6) % 12;
    if (m >= 2 && m <= 4)
        return "spring";
    if (m >= 5 && m <= 7)
        return "summer";
    if (m >= 8 && m <= 10)
        return "autumn";
    return "winter";
}

// Weather a forced preview condition stands for: { code, tempC, month, lat }.
function previewWeather(name) {
    switch (name) {
    case "drizzle": return { code: 53, tempC: 12, month: 0, lat: 40 };
    case "rain": return { code: 63, tempC: 12, month: 0, lat: 40 };
    case "storm": return { code: 95, tempC: 18, month: 0, lat: 40 };
    case "snow": return { code: 73, tempC: -2, month: 0, lat: 40 };
    case "frost": return { code: 0, tempC: -7, month: 0, lat: 40 };
    case "fog": return { code: 45, tempC: 6, month: 0, lat: 40 };
    case "heat": return { code: 0, tempC: 35, month: 6, lat: 40 };
    case "petals": return { code: 1, tempC: 16, month: 3, lat: 40 };
    case "leaves": return { code: 1, tempC: 12, month: 9, lat: 40 };
    }
    return null;
}

// The effects to draw: levels 0..1 per effect, `seasonal` "" | "petals" |
// "leaves", `strength` (mode multiplier) and `any`. `weather` = { code,
// tempC, known, month, lat }; `force` = options whose toggles are ignored
// (a preview shows the effect whatever the toggles say).
function effects(opts, weather, force) {
    var o = opts || options(null);
    var w = weather || {};
    var out = { rain: 0, snow: 0, frost: 0, fog: 0, heat: 0, seasonal: "", strength: strength(o.mode), any: false };
    if (o.mode === "off" && !force)
        return out;
    var on = function (k) { return !!force || !!o[k]; };
    if (w.known !== false) {
        var c = condition(w.code);
        if (on("rain"))
            out.rain = c.rain;
        if (on("frost")) {
            out.snow = c.snow;
            out.frost = Math.max(frostLevel(w.tempC), c.snow > 0 && w.tempC <= 1 ? 0.4 : 0);
        }
        if (on("fog"))
            out.fog = c.fog;
        if (on("heat"))
            out.heat = heatLevel(w.tempC);
    }
    if (on("seasonal") && out.rain === 0 && out.snow === 0) {
        var s = season(w.lat, w.month);
        out.seasonal = s === "spring" ? "petals" : (s === "autumn" ? "leaves" : "");
    }
    out.any = out.rain > 0 || out.snow > 0 || out.frost > 0 || out.fog > 0 || out.heat > 0 || out.seasonal !== "";
    return out;
}

// Alpha / density multiplier of a mode (a preview of "off" looks subtle).
function strength(mode) {
    return mode === "vivid" ? 1.5 : 1;
}

// Rain beads resting on a surface of `area` px² (a bar strip or a panel).
function beadCount(level, mode, area) {
    if (level <= 0 || area <= 0)
        return 0;
    var perTenK = lerp(0.35, 1.3, level) * (mode === "vivid" ? 1.5 : 1);
    var cap = mode === "vivid" ? 22 : 14;
    return clamp(Math.round(area / 10000 * perTenK), 2, cap);
}

// Snowflakes that can rest along a top edge `width` px long.
function flakeSlots(level, mode, width) {
    if (level <= 0 || width <= 0)
        return 0;
    var per = lerp(70, 34, level) / (mode === "vivid" ? 1.4 : 1);
    return clamp(Math.round(width / per), 2, mode === "vivid" ? 28 : 18);
}

// Milliseconds between two events of an effect (a drop running down, a
// flake settling, a petal landing, a heat wave), before jitter.
function cadence(kind, level, mode) {
    var k = mode === "vivid" ? 0.8 : 1;
    switch (kind) {
    case "rain": return Math.round(lerp(10000, 3500, level) * k);
    case "snow": return Math.round(lerp(9000, 2800, level) * k);
    case "seasonal": return Math.round(26000 * k);
    case "heat": return Math.round(lerp(11000, 7000, level) * k);
    }
    return 0;
}

// Deterministic PRNG (mulberry32): rng(seed)() -> [0, 1).
function rng(seed) {
    var a = (Math.floor(seed) >>> 0) || 0x9e3779b9;
    return function () {
        a = (a + 0x6d2b79f5) >>> 0;
        var t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}
