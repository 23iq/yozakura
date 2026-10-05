.pragma library
.import "MotionProfiles.js" as Profiles

// Resolves a motion profile (+ the user's per-part overrides) into the exact
// list of Hyprland curves and animation-tree nodes to apply, and renders
// them as Lua statements for the live `hyprctl eval`. The backend renders
// the same spec into hyprland.{lua,conf} (backend/pkg/svc/compositor/motion.go).
// Pure: node-tested (tests/motion-profiles.test.cjs).

// Hyprland 0.56 animation tree, parents first: [node, parent]. Every node is
// emitted on every apply so switching profiles never leaves a stale leaf.
var TREE = [
    ["windows", "global"],
    ["windowsIn", "windows"],
    ["windowsOut", "windows"],
    ["windowsMove", "windows"],
    ["layers", "global"],
    ["layersIn", "layers"],
    ["layersOut", "layers"],
    ["fade", "global"],
    ["fadeIn", "fade"],
    ["fadeOut", "fade"],
    ["fadeSwitch", "fade"],
    ["fadeShadow", "fade"],
    ["fadeDim", "fade"],
    ["fadeLayers", "fade"],
    ["fadeLayersIn", "fadeLayers"],
    ["fadeLayersOut", "fadeLayers"],
    ["fadePopups", "fade"],
    ["fadePopupsIn", "fadePopups"],
    ["fadePopupsOut", "fadePopups"],
    ["border", "global"],
    ["borderangle", "global"],
    ["workspaces", "global"],
    ["workspacesIn", "workspaces"],
    ["workspacesOut", "workspaces"],
    ["specialWorkspace", "workspaces"],
    ["specialWorkspaceIn", "specialWorkspace"],
    ["specialWorkspaceOut", "specialWorkspace"]
];

// Hyprland's built-in root ("global": bezier "default", speed 8).
var GLOBAL = {
    "enabled": true,
    "curve": "default",
    "speed": 8,
    "style": ""
};

// Curves Hyprland always defines (never emitted).
var BUILTIN_CURVES = ["default", "linear"];

var LINEAR_CURVE = "motionLinear";

// Workspace style overrides (compositor.motionWorkspaceStyle).
var WORKSPACE_STYLES = {
    "slide": "slide",
    "slidefade": "slidefade 20%",
    "fade": "fade"
};

var WORKSPACE_NODES = ["workspaces", "workspacesIn", "workspacesOut"];

function nodes() {
    return TREE.map(function (n) {
        return n[0];
    });
}

function parentOf(node) {
    for (var i = 0; i < TREE.length; i++) {
        if (TREE[i][0] === node)
            return TREE[i][1];
    }
    return null;
}

function num(v, fallback) {
    return (typeof v === "number" && isFinite(v)) ? v : fallback;
}

function round2(v) {
    return Math.round(v * 100) / 100;
}

function copy(o) {
    return {
        "enabled": o.enabled,
        "curve": o.curve,
        "speed": o.speed,
        "style": o.style
    };
}

// Workspace slides run along the bar: vertical bar -> *vert variants.
function verticalStyle(style) {
    return String(style || "").replace(/^(slide|slidefade)(\s|$)/, "$1vert$2");
}

// opts:
//   profile           compositor.motionProfile
//   durationScale     compositor.motionDurationScale (1 = as designed)
//   workspaceStyle    compositor.motionWorkspaceStyle ("auto" = profile)
//   vertical          bar on the left/right edge
//   borderLoop        compositor.motionBorderLoop ("auto" | "on" | "off")
//   borderLoopSpeed   compositor.motionBorderLoopSpeed (0 = profile)
//   overrides         compositor.motionOverrides {node: {enabled, speed, curve, style}}
//                     curve: a curve name or [x0, y0, x1, y1]
// Returns {profile, enabled, curves: [...], animations: [...], shell}.
function resolve(opts) {
    var o = opts || {};
    var p = Profiles.resolveId(o.profile);
    var scale = Math.max(0.05, num(o.durationScale, 1));
    var shell = {
        "scale": p.disabled ? 0 : round2(num(p.shell && p.shell.scale, 1) * scale),
        "easing": (p.shell && p.shell.easing) || "OutCubic"
    };
    if (p.disabled) {
        return {
            "profile": p.id,
            "enabled": false,
            "curves": [],
            "animations": [],
            "shell": shell
        };
    }

    var curveDefs = {};
    var curveOrder = [];
    function addCurve(name, def) {
        if (!curveDefs[name])
            curveOrder.push(name);
        curveDefs[name] = def;
    }
    for (var cn in p.curves)
        addCurve(cn, p.curves[cn]);

    var overrides = (o.overrides && typeof o.overrides === "object") ? o.overrides : {};
    var wsStyle = WORKSPACE_STYLES[o.workspaceStyle] || "";
    var resolved = {};
    var out = [];

    TREE.forEach(function (pair) {
        var node = pair[0];
        var explicit = p.leaves[node];
        var r = explicit ? {
            "enabled": explicit.enabled !== false,
            "curve": explicit.curve,
            "speed": explicit.speed,
            "style": explicit.style || ""
        } : copy(resolved[pair[1]] || GLOBAL);
        var ov = overrides[node];
        if (ov && typeof ov === "object") {
            if (typeof ov.enabled === "boolean")
                r.enabled = ov.enabled;
            if (num(ov.speed, 0) > 0)
                r.speed = ov.speed;
            if (typeof ov.style === "string")
                r.style = ov.style;
            if (Array.isArray(ov.curve) && ov.curve.length === 4) {
                var custom = "motionOverride" + node.charAt(0).toUpperCase() + node.slice(1);
                addCurve(custom, {
                    "type": "bezier",
                    "points": ov.curve.map(Number)
                });
                r.curve = custom;
            } else if (typeof ov.curve === "string" && (curveDefs[ov.curve] || BUILTIN_CURVES.indexOf(ov.curve) !== -1)) {
                r.curve = ov.curve;
            }
        }
        if (WORKSPACE_NODES.indexOf(node) !== -1) {
            if (wsStyle)
                r.style = wsStyle;
            if (o.vertical)
                r.style = verticalStyle(r.style);
        }
        if (node === "borderangle" && !(ov && typeof ov === "object")) {
            var loop = o.borderLoop === "on" || (o.borderLoop !== "off" && p.borderLoop && p.borderLoop.enabled);
            if (loop) {
                var loopCurve = (p.borderLoop && p.borderLoop.curve) || LINEAR_CURVE;
                if (loopCurve === LINEAR_CURVE)
                    addCurve(LINEAR_CURVE, {
                        "type": "bezier",
                        "points": [0, 0, 1, 1]
                    });
                var loopSpeed = num(o.borderLoopSpeed, 0) > 0 ? o.borderLoopSpeed : num(p.borderLoop && p.borderLoop.speed, 0) || 50;
                r = {
                    "enabled": true,
                    "curve": loopCurve,
                    "speed": Math.max(1, Math.min(100, loopSpeed)),
                    "style": "loop"
                };
            } else if (!explicit) {
                r = copy(GLOBAL);
            }
        }
        if (!curveDefs[r.curve] && BUILTIN_CURVES.indexOf(r.curve) === -1)
            r.curve = "default";
        resolved[node] = r;
        out.push({
            "leaf": node,
            "enabled": r.enabled,
            // The border loop speed is a rotation period, not a duration.
            "speed": round2(Math.max(0.01, r.style === "loop" ? r.speed : r.speed * scale)),
            "curve": r.curve,
            "kind": (curveDefs[r.curve] && curveDefs[r.curve].type === "spring") ? "spring" : "bezier",
            "style": r.style
        });
    });

    var used = {};
    out.forEach(function (a) {
        used[a.curve] = true;
    });
    var curves = [];
    curveOrder.forEach(function (name) {
        if (!used[name])
            return;
        var d = curveDefs[name];
        if (d.type === "spring") {
            curves.push({
                "name": name,
                "type": "spring",
                "mass": d.mass,
                "stiffness": d.stiffness,
                "dampening": d.dampening,
                "points": [[d.fallback[0], d.fallback[1]], [d.fallback[2], d.fallback[3]]]
            });
        } else {
            curves.push({
                "name": name,
                "type": "bezier",
                "points": [[d.points[0], d.points[1]], [d.points[2], d.points[3]]]
            });
        }
    });

    return {
        "profile": p.id,
        "enabled": true,
        "curves": curves,
        "animations": out,
        "shell": shell
    };
}

// --- Lua (live eval; same text as backend/pkg/svc/compositor/motion.go) ---

function luaNum(v) {
    return String(v);
}

function luaCurve(c) {
    if (c.type === "spring")
        return "hl.curve(" + JSON.stringify(c.name) + ", { type = \"spring\", mass = " + luaNum(c.mass) + ", stiffness = " + luaNum(c.stiffness) + ", dampening = " + luaNum(c.dampening) + " })";
    return "hl.curve(" + JSON.stringify(c.name) + ", { type = \"bezier\", points = { {" + luaNum(c.points[0][0]) + ", " + luaNum(c.points[0][1]) + "}, {" + luaNum(c.points[1][0]) + ", " + luaNum(c.points[1][1]) + "} } })";
}

function luaAnimation(a) {
    var s = "hl.animation({ leaf = " + JSON.stringify(a.leaf) + ", enabled = " + (a.enabled ? "true" : "false") + ", speed = " + luaNum(a.speed) + ", " + a.kind + " = " + JSON.stringify(a.curve);
    if (a.style)
        s += ", style = " + JSON.stringify(a.style);
    return s + " })";
}

// One Lua chunk for `hyprctl eval`: statements separated by spaces (one line), each
// guarded by pcall so one rejected leaf cannot abort the rest. No ';' (the
// yozd raw-batch wrapper splits on it).
function luaChunk(spec) {
    var lines = ["pcall(hl.config, { animations = { enabled = " + (spec.enabled ? "true" : "false") + " } })"];
    spec.curves.forEach(function (c) {
        lines.push("pcall(function() " + luaCurve(c) + " end)");
    });
    spec.animations.forEach(function (a) {
        lines.push("pcall(function() " + luaAnimation(a) + " end)");
    });
    return lines.join(" ");
}

// --- Sampling (settings previews) ---

// Cubic bezier with P0 = (0, 0), P3 = (1, 1): y for a given x.
function bezierAt(points, x) {
    var x1 = points[0], y1 = points[1], x2 = points[2], y2 = points[3];
    if (x <= 0)
        return 0;
    if (x >= 1)
        return 1;
    function bx(t) {
        return 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t;
    }
    function by(t) {
        return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t;
    }
    // x(t) is monotonic for x1, x2 in [0, 1]: bisection is exact enough.
    var lo = 0, hi = 1, t = x;
    for (var i = 0; i < 40; i++) {
        t = (lo + hi) / 2;
        if (bx(t) < x)
            lo = t;
        else
            hi = t;
    }
    return by(t);
}

// Unit step response of a damped spring at `sec` seconds.
function springAt(c, sec) {
    var m = num(c.mass, 1), k = num(c.stiffness, 100), d = num(c.dampening, 10);
    var w0 = Math.sqrt(k / m);
    var zeta = d / (2 * Math.sqrt(k * m));
    var t = Math.max(0, sec);
    if (zeta < 1) {
        var wd = w0 * Math.sqrt(1 - zeta * zeta);
        return 1 - Math.exp(-zeta * w0 * t) * (Math.cos(wd * t) + (zeta * w0 / wd) * Math.sin(wd * t));
    }
    return 1 - Math.exp(-w0 * t) * (1 + w0 * t);
}

// Progress (0..1, may overshoot) of a resolved curve at linear time p of an
// animation lasting `seconds`.
function curveAt(curve, p, seconds) {
    if (!curve)
        return p;
    if (curve.type === "spring")
        return p >= 1 ? 1 : springAt(curve, p * seconds);
    var pts = curve.points;
    return bezierAt([pts[0][0], pts[0][1], pts[1][0], pts[1][1]], p);
}

function curveNamed(spec, name) {
    if (name === "linear")
        return {
            "type": "bezier",
            "points": [[0, 0], [1, 1]]
        };
    if (name === "default")
        return {
            "type": "bezier",
            "points": [[0, 0.75], [0.15, 1]]
        };
    for (var i = 0; i < spec.curves.length; i++) {
        if (spec.curves[i].name === name)
            return spec.curves[i];
    }
    return null;
}

function animation(spec, leaf) {
    for (var i = 0; i < spec.animations.length; i++) {
        if (spec.animations[i].leaf === leaf)
            return spec.animations[i];
    }
    return null;
}

// Scale a "popin N%" style starts from (1 when the style has no popin).
function popinScale(style) {
    var m = /^popin\s+(\d+(?:\.\d+)?)%/.exec(String(style || ""));
    return m ? Math.max(0, Math.min(1, parseFloat(m[1]) / 100)) : (/^popin/.test(String(style || "")) ? 0.8 : 1);
}

// --- Registry checks (tests + audit) ---

function validate(profile) {
    var problems = [];
    var known = nodes();
    function bad(msg) {
        problems.push(profile.id + ": " + msg);
    }
    if (!profile.id || !profile.label || !profile.description || !profile.icon)
        bad("needs id, label, description and icon");
    for (var name in profile.curves) {
        var c = profile.curves[name];
        if (name.indexOf(profile.id) !== 0)
            bad("curve '" + name + "' must start with the profile id");
        if (c.type === "bezier") {
            if (!Array.isArray(c.points) || c.points.length !== 4)
                bad("curve '" + name + "' needs 4 points");
            else if (c.points[0] < 0 || c.points[0] > 1 || c.points[2] < 0 || c.points[2] > 1)
                bad("curve '" + name + "' x control points must be in [0, 1]");
        } else if (c.type === "spring") {
            ["mass", "stiffness", "dampening"].forEach(function (f) {
                if (!(num(c[f], 0) >= 0.5))
                    bad("spring '" + name + "' " + f + " must be >= 0.5");
            });
            if (!Array.isArray(c.fallback) || c.fallback.length !== 4)
                bad("spring '" + name + "' needs a 4-point bezier fallback");
        } else {
            bad("curve '" + name + "' has unknown type '" + c.type + "'");
        }
    }
    for (var node in profile.leaves) {
        var l = profile.leaves[node];
        if (known.indexOf(node) === -1)
            bad("unknown animation node '" + node + "'");
        if (!profile.curves[l.curve] && BUILTIN_CURVES.indexOf(l.curve) === -1)
            bad(node + ": unknown curve '" + l.curve + "'");
        if (!(num(l.speed, 0) > 0))
            bad(node + ": speed must be > 0");
    }
    if (profile.borderLoop && profile.borderLoop.curve && !profile.curves[profile.borderLoop.curve])
        bad("borderLoop: unknown curve '" + profile.borderLoop.curve + "'");
    if (!profile.shell || typeof profile.shell.scale !== "number" || !profile.shell.easing)
        bad("needs shell {scale, easing}");
    return problems;
}
