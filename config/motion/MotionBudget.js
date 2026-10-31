.pragma library

// Motion budget: the effective millisecond ceilings of the shell tokens and
// the speed caps of the compositor animation tree (Hyprland units, 1 = 100 ms).
// Applied before the user's explicit motionDurationScale.

var SHELL = {
    // Surfaces and popups opening / closing (exits are faster than enters).
    enter: 220,
    exit: 160,
    // Size / shape changes of an open surface.
    morph: 280,
    emphasis: 360,
    palette: 600,
    delay: 40,
    // Small state changes (fills, hover, focus) and slides inside a surface.
    micro: 120,
    glide: 220,
    // Slow camera moves across a whole surface (panorama wallpaper pan).
    pan: 700
};
// theme.animDuration x profile scale is compressed above KNEE (each ms above
// it counts KNEE_SLOPE ms) and capped at BASE_MAX, so a "calm" 260-300 ms
// preset still feels crisp while the slider stays monotonic. Config.animDuration
// is that base, and ~400 animations use it raw.
var KNEE = 160;
var KNEE_SLOPE = 0.5;
var BASE_MAX = 240;
// Most stagger a list or a reveal adds on top of its own animation.
var STAGGER_MAX = 120;
var PRESET_ANIM = {
    min: 160,
    max: 300
};
var COMPOSITOR = [
    {
        re: /^(windows|layers|fade)/,
        max: 3.5
    },
    {
        re: /^(workspaces|specialWorkspace)/,
        max: 4
    }
];
var FACTOR = {
    enter: 0.9,
    exit: 0.62,
    morph: 1.15,
    emphasis: 1.5,
    micro: 0.45,
    glide: 0.8,
    pan: 3
};

// theme.animDuration x profile scale, compressed and capped. Never negative.
function shellBase(animDuration, profileScale) {
    var v = Math.max(0, (animDuration || 0) * (profileScale || 0));
    if (v > KNEE)
        v = KNEE + (v - KNEE) * KNEE_SLOPE;
    return Math.min(Math.round(v), BASE_MAX);
}

// kind: enter | exit | morph | emphasis | micro | glide | pan -> effective ms.
function token(kind, base) {
    if (!(base > 0) || FACTOR[kind] === undefined)
        return 0;
    return Math.round(Math.min(base * FACTOR[kind], SHELL[kind]));
}

// Soft easings start too slowly to read as a response to a click: the shell
// uses the crisper cubic for them (the profile keeps them for windows).
var SOFT = {
    "OutSine": "OutCubic",
    "OutQuad": "OutCubic"
};
var BOUNCY = /^Out(Back|Elastic|Bounce)$/;

// Enter and morph motion decelerates: In/InOut families become Out, soft
// curves become OutCubic.
function enterEasing(name) {
    var n = String(name || "");
    if (n === "Linear")
        return n;
    if (n.indexOf("InOut") === 0)
        n = "Out" + n.substring(5);
    else if (n.indexOf("In") === 0)
        n = "Out" + n.substring(2);
    return SOFT[n] || n;
}

// Panels, popups and slides never overshoot: a bouncy profile (springs)
// keeps its OutBack for emphasis and the press spring only.
function panelEasing(name) {
    var n = enterEasing(name);
    return BOUNCY.test(n) ? "OutQuart" : n;
}

// Leaving accelerates away (a quick, decisive exit); Linear stays linear.
function exitEasing(name) {
    return String(name || "") === "Linear" ? "Linear" : "InQuad";
}

// Delay of item `index` in a staggered list: `step` each, never more than
// STAGGER_MAX in total, however long the list.
function stagger(index, step) {
    var i = Math.max(0, index | 0);
    var s = Math.max(0, Number(step) || 0);
    return Math.min(i * s, STAGGER_MAX);
}

// Leaves of a motion profile whose speed exceeds the compositor caps.
function compositorViolations(profile) {
    var out = [];
    var leaves = (profile && profile.leaves) || {};
    Object.keys(leaves).forEach(function (node) {
        var speed = leaves[node].speed;
        for (var i = 0; i < COMPOSITOR.length; i++) {
            if (COMPOSITOR[i].re.test(node)) {
                if (speed > COMPOSITOR[i].max)
                    out.push({
                        node: node,
                        speed: speed,
                        max: COMPOSITOR[i].max
                    });
                break;
            }
        }
    });
    return out;
}
