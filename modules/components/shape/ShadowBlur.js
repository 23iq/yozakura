.pragma library

// MultiEffect's blur (blurMax 32) as a mix of Gaussians, for the analytic
// shadow (ShapeShadow / shape_shadow.frag). MultiEffect blends the sharp
// source with a pyramid of blurred copies; its result on a straight edge is
// matched within 2/255 by Gaussians of sigma 2, 4, 8 and 16 px plus the
// sharp source, weighted per blur amount. The weights were fitted (non-
// negative least squares) to MultiEffect renders of a box at blur 0, 0.05,
// ..., 1 (tests/shape-shadow.test.py re-checks the result against the
// captured MultiEffect shadow). Unit tested in tests/shadow-blur.test.cjs.

var SIGMAS = [2, 4, 8, 16];
var STEP = 0.05;
// Weight of each sigma at blur = index * STEP
var TABLE = [
    [0, 0, 0, 0],
    [0.3143, 0, 0, 0],
    [0.4, 0.0066, 0.0102, 0],
    [0.4262, 0.0728, 0.0031, 0],
    [0.4591, 0.1163, 0.0003, 0],
    [0.5025, 0.1159, 0.0312, 0],
    [0.485, 0.155, 0.0635, 0],
    [0.4981, 0.1665, 0.0949, 0],
    [0.4613, 0.2084, 0.118, 0],
    [0.4242, 0.2494, 0.1383, 0],
    [0.3971, 0.2683, 0.1722, 0],
    [0.3426, 0.3157, 0.1872, 0.0183],
    [0.313, 0.3236, 0.215, 0.0411],
    [0.2927, 0.332, 0.2311, 0.0616],
    [0.2262, 0.3859, 0.2266, 0.0868],
    [0.2416, 0.3335, 0.2728, 0.1047],
    [0.2146, 0.3203, 0.309, 0.121],
    [0.2111, 0.2937, 0.3434, 0.1393],
    [0.2074, 0.2563, 0.3766, 0.1597],
    [0.169, 0.2377, 0.4024, 0.168],
    [0.1434, 0.2385, 0.3938, 0.1884]
];

function clamp01(v) {
    return typeof v === "number" && v > 0 ? Math.min(v, 1) : 0;
}

// {w: [4 weights for SIGMAS], sharp: weight of the unblurred shape,
//  reach: px beyond the shape the blur still shows (3 sigma of the widest
//  level in use)}; blur is MultiEffect's 0..1 (clamped like MultiEffect).
function weights(blur) {
    var b = clamp01(blur) / STEP;
    var i = Math.min(Math.floor(b), TABLE.length - 2);
    var t = b - i;
    var w = [];
    var sum = 0;
    var reach = 0;
    for (var k = 0; k < SIGMAS.length; k++) {
        var v = TABLE[i][k] * (1 - t) + TABLE[i + 1][k] * t;
        w.push(v);
        sum += v;
        if (v > 0.02)
            reach = SIGMAS[k] * 3;
    }
    return {
        "w": w,
        "sharp": Math.max(0, 1 - sum),
        "reach": reach
    };
}
