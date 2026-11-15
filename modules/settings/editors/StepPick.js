.pragma library

// Pure helpers of the picture strips that offer a few steps of a number
// that can hold any value (WindowCornersEditor: rounding, WindowBorderEditor:
// border width; a preset, the stage or `yozakura config` may set 4 or 12).
// Node-tested (tests/settings-step-pick.test.cjs).

// The index of the step equal to `value`, or -1 (no tile is chosen for a
// value between steps).
function exactIndex(steps, value) {
    return steps.indexOf(Number(value));
}

// The step one keyboard press away from `value` (`dir` -1 / +1): the
// nearest step past it in that direction, else the last step that way.
function stepFrom(steps, value, dir) {
    var v = Number(value);
    if (!isFinite(v))
        return dir > 0 ? steps[steps.length - 1] : steps[0];
    if (dir > 0) {
        for (var i = 0; i < steps.length; i++) {
            if (steps[i] > v)
                return steps[i];
        }
        return steps[steps.length - 1];
    }
    for (var j = steps.length - 1; j >= 0; j--) {
        if (steps[j] < v)
            return steps[j];
    }
    return steps[0];
}
