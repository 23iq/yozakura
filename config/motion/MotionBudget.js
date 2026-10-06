.pragma library

// Motion budget: the effective millisecond ceilings of the shell tokens and
// the speed caps of the compositor animation tree (Hyprland units, 1 = 100 ms).
// Applied before the user's explicit motionDurationScale.

var SHELL = {
    enter: 260,
    exit: 180,
    morph: 360,
    emphasis: 450,
    palette: 600,
    delay: 40
};
var BASE_MAX = 300;
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
    enter: 0.87,
    exit: 0.6,
    morph: 1.2,
    emphasis: 1.5
};

// theme.animDuration x profile scale, capped. Never negative.
function shellBase(animDuration, profileScale) {
    var v = Math.round((animDuration || 0) * (profileScale || 0));
    return Math.max(0, Math.min(v, BASE_MAX));
}

// kind: enter | exit | morph | emphasis -> effective ms.
function token(kind, base) {
    if (!(base > 0) || FACTOR[kind] === undefined)
        return 0;
    return Math.round(Math.min(base * FACTOR[kind], SHELL[kind]));
}

// Enter and morph motion decelerates: In/InOut families become Out.
function enterEasing(name) {
    var n = String(name || "");
    if (n === "Linear")
        return n;
    if (n.indexOf("InOut") === 0)
        return "Out" + n.substring(5);
    if (n.indexOf("In") === 0)
        return "Out" + n.substring(2);
    return n;
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
