.pragma library

// How one light source shapes the shell's shadows (theme.lighting). Pure;
// unit tested in tests/light-model.test.cjs, read by Lighting.qml.
//
// The screen is a window facing the sun's side of the sky (south in the
// northern hemisphere): a morning sun stands to the left, an evening sun to
// the right, and light always comes from above. The result is relative to
// the theme's own shadow:
//   dx, dy      shadow direction (unit vector, screen axes, y down)
//   length      offset length as a multiple of the base length
//   blur        softness multiplier of the theme blur (<= 1 is sharper)
//   strength    opacity multiplier of the theme shadow
//   side        -1..1 where the light stands along x (lit edge)
//   warmth      -1..1: golden hour > 0, night < 0 (cool), 0 at noon
//   day         0..1: 0 at night, 1 in daylight
//   night       sun below civil twilight
// withStrength() scales every departure from the neutral light by
// theme.lighting.strength (subtle | normal | dramatic).

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function smoothstep(a, b, v) {
    var t = clamp((v - a) / (b - a), 0, 1);
    return t * t * (3 - 2 * t);
}

function mix(a, b, t) {
    return a + (b - a) * t;
}

var RAD = Math.PI / 180;
var MODES = ["off", "fixed", "sun"];
var NIGHT_ALTITUDE = -6;
var STRENGTHS = { "subtle": 0.55, "normal": 1, "dramatic": 1.6 };

// theme.lighting.strength -> multiplier of the effect (unknown: normal)
function strengthScale(name) {
    return Object.prototype.hasOwnProperty.call(STRENGTHS, name) ? STRENGTHS[name] : 1;
}

function normalizeMode(mode) {
    return MODES.indexOf(mode) >= 0 ? mode : "off";
}

function neutral() {
    return { dx: 0, dy: 1, length: 1, blur: 1, strength: 1, side: 0, warmth: 0, day: 1, night: false };
}

// angle: where the light comes from, degrees clockwise from the top of the
// screen (0 = above, 90 = from the right); a fixed lamp at 45 degrees.
function fixed(angle) {
    var a = (Number(angle) || 0) * RAD;
    var out = neutral();
    out.side = Math.sin(a);
    out.dx = -Math.sin(a) + 0;
    out.dy = Math.cos(a);
    return out;
}

// azimuth / altitude in degrees (SunPosition.position), lat for the
// hemisphere (which way the window faces).
function sun(azimuth, altitude, lat) {
    var facing = lat < 0 ? 1 : -1;
    var side = facing * Math.sin(azimuth * RAD);
    var day = smoothstep(NIGHT_ALTITUDE, 6, altitude);
    var alt = Math.max(altitude, 4) * RAD;
    // Low sun: the shadow runs sideways; high sun: straight down
    var hx = -side * Math.cos(alt);
    var vy = Math.max(Math.sin(alt), 0.3);
    var n = Math.sqrt(hx * hx + vy * vy);
    var dx = mix(0, hx / n, day);
    var dy = mix(1, vy / n, day);
    var m = Math.sqrt(dx * dx + dy * dy) || 1;
    // 0 with the sun on the horizon, 1 high in the sky
    var high = smoothstep(4, 50, altitude);
    var golden = 1 - smoothstep(2, 20, altitude);
    return {
        dx: dx / m,
        dy: dy / m,
        // Long and soft at dawn and dusk, short and crisp at noon
        length: mix(0.3, mix(3.4, 0.5, high), day),
        blur: mix(1.15, mix(1.15, 0.55, high), day),
        strength: mix(0.22, 1, day),
        side: side * day + 0,
        warmth: day * golden - (1 - day) * 0.8,
        day: day,
        night: altitude < NIGHT_ALTITUDE
    };
}

// The light scaled by k (strengthScale): lengths and softness as powers so
// noon stays shorter than golden hour at every strength; opacity loss and
// warmth linearly. Direction, side and day are kept.
function withStrength(light, k) {
    if (!light)
        return light;
    var out = {};
    for (var key in light)
        out[key] = light[key];
    out.length = clamp(Math.pow(light.length, k), 0.2, 4.5);
    out.blur = Math.pow(light.blur, k);
    out.strength = clamp(1 + (light.strength - 1) * k, 0.06, 1.2);
    out.warmth = clamp(light.warmth * k, -1, 1);
    return out;
}

// The shadow to draw: base = the theme's own values {x, y, blur, opacity}.
// Lit shadows keep at least `minLength` px of offset so a centred theme
// shadow (0, 0) still shows the direction.
function shadow(light, base, minLength) {
    var len = Math.max(Math.sqrt(base.x * base.x + base.y * base.y), minLength || 0) * light.length;
    return {
        x: Math.round(light.dx * len) + 0,
        y: Math.round(light.dy * len) + 0,
        blur: clamp(base.blur * light.blur, 0, 1),
        opacity: clamp(base.opacity * light.strength, 0, 1)
    };
}

// lantern: off | night | always. Whether the cursor lantern glows now.
function lanternOn(lantern, night) {
    return lantern === "always" || (lantern === "night" && !!night);
}
