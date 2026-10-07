.pragma library

// A dock panel sharing its edge with the notch parts around the grown
// notch instead of letting it drop past the bar: the groups split in two
// runs that slide apart, leaving the notch's claimed length free around the
// panel's center, where the notch grows in place. Pure, unit tested in
// tests/dock-split.test.cjs. Lengths along the edge, offsets from the
// panel's center (negative = toward the start).

// The two runs of the groups (non-empty ones, in order): the end group on
// its own on the right, everything before it on the left ("__sep__"
// between the left groups). With fewer than two groups nothing can part:
// everything on the left, nothing on the right.
function runs(start, center, end) {
    var groups = [start || [], center || [], end || []].filter(function (g) {
        return g.length > 0;
    });
    if (groups.length < 2)
        return { left: groups.length ? groups[0].slice() : [], right: [] };
    var left = [];
    for (var i = 0; i < groups.length - 1; i++) {
        if (i > 0)
            left.push("__sep__");
        left = left.concat(groups[i]);
    }
    return { left: left, right: groups[groups.length - 1].slice() };
}

// Length of the parted panel: two runs (each with its padding) placed
// symmetrically around a gap of `gap`, so the gap sits on the center.
function partedLength(o) {
    var lw = o.left + 2 * o.pad;
    var rw = o.right + 2 * o.pad;
    return 2 * Math.max(lw, rw) + o.gap;
}

// Length of the resting panel: both runs and the separator block between.
function restLength(o) {
    return o.left + o.sep + o.right + 2 * o.pad;
}

// Whether the panel parts for a notch claiming `claim` px. o: { enabled
// (same edge, both centered, horizontal), left, right (run lengths, 0 =
// empty), pad, gap (space kept on each side of the notch), claim, max
// (longest the panel may get along the edge) }.
function parts(o) {
    if (!o || !o.enabled || !(o.claim > 0) || !(o.left > 0) || !(o.right > 0))
        return false;
    return partedLength({ left: o.left, right: o.right, pad: o.pad, gap: o.claim + 2 * o.gap }) <= o.max;
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

// Surfaces and runs at `part` (0 resting .. 1 parted). o: { left, right,
// pad, sep (separator block), gap (the free length in the middle once
// parted), part }. Returns offsets from the center: leftFrom/leftTo,
// rightFrom/rightTo (surfaces), leftRun/rightRun (start of each run), seam
// (resting separator center), and the lengths reaching from each end of
// the parted panel (startReach/endReach) once parted.
function layout(o) {
    var t = Math.max(0, Math.min(1, o.part || 0));
    var rest = restLength(o);
    var gap = Math.max(0, o.gap || 0);
    var seam = -rest / 2 + o.pad + o.left + o.sep / 2;
    var lw = o.left + 2 * o.pad;
    var rw = o.right + 2 * o.pad;
    var leftFrom = lerp(-rest / 2, -gap / 2 - lw, t);
    var leftTo = lerp(seam, -gap / 2, t);
    var rightFrom = lerp(seam, gap / 2, t);
    var rightTo = lerp(rest / 2, gap / 2 + rw, t);
    var half = partedLength({ left: o.left, right: o.right, pad: o.pad, gap: gap }) / 2;
    return {
        leftFrom: leftFrom,
        leftTo: leftTo,
        rightFrom: rightFrom,
        rightTo: rightTo,
        leftRun: leftFrom + o.pad,
        rightRun: rightTo - o.pad - o.right,
        seam: seam,
        startReach: half - gap / 2,
        endReach: half - gap / 2
    };
}
