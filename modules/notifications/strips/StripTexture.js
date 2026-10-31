.pragma library

// Procedural texture of a strip's material (notifications.strips.material).
// Only geometry and opacity: StripTexture.qml strokes it with palette roles,
// so a green palette gives green paper. "plain" has none; "paper" is a fine
// grain of short fibres; "washi" adds long, meandering fibres along the
// strip and a few soft clouds. Deterministic per seed (the strip's key).
// Unit tested in tests/strips-texture.test.cjs.

// Small seeded PRNG (mulberry32): same seed, same texture.
function rng(seed) {
    var a = (Number(seed) | 0) >>> 0;
    return function () {
        a = (a + 0x6D2B79F5) >>> 0;
        var t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// Fibre density per 1000 px² of strip surface.
var DENSITY = {
    "paper": 2.4,
    "washi": 0.9
};

// -> [{kind: "fibre" | "cloud", x1, y1, cx, cy, x2, y2, r, alpha, width, tint}]
// `tint` names the role it is drawn with: "ink" (overBackground) or
// "accent" (primary), never a colour.
function strokes(material, seed, w, h) {
    var out = [];
    if (!DENSITY[material] || !(w > 0) || !(h > 0))
        return out;
    var r = rng(seed);
    var long = Math.max(w, h), vertical = h >= w;
    var count = Math.min(400, Math.round(w * h / 1000 * DENSITY[material]));
    for (var i = 0; i < count; i++) {
        var x = r() * w, y = r() * h;
        var len, ang;
        if (material === "washi") {
            // Long fibres running roughly along the strip
            len = long * (0.12 + r() * 0.3);
            ang = (vertical ? Math.PI / 2 : 0) + (r() - 0.5) * 0.9;
        } else {
            len = 2 + r() * 5;
            ang = r() * Math.PI;
        }
        var dx = Math.cos(ang) * len / 2, dy = Math.sin(ang) * len / 2;
        var bend = (r() - 0.5) * len * 0.35;
        out.push({
            "kind": "fibre",
            "x1": x - dx, "y1": y - dy,
            "x2": x + dx, "y2": y + dy,
            "cx": x - dy / len * bend * 2, "cy": y + dx / len * bend * 2,
            "r": 0,
            "alpha": material === "washi" ? 0.05 + r() * 0.07 : 0.04 + r() * 0.06,
            "width": material === "washi" ? 0.6 + r() * 0.6 : 0.5 + r() * 0.5,
            "tint": r() < 0.18 ? "accent" : "ink"
        });
    }
    if (material === "washi") {
        // Soft clouds of denser pulp
        var clouds = 2 + Math.floor(r() * 2);
        for (var c = 0; c < clouds; c++) {
            out.push({
                "kind": "cloud",
                "x1": r() * w, "y1": r() * h, "x2": 0, "y2": 0, "cx": 0, "cy": 0,
                "r": Math.min(w, h) * (0.5 + r() * 0.7),
                "alpha": 0.035 + r() * 0.03,
                "width": 0,
                "tint": "accent"
            });
        }
    }
    return out;
}
