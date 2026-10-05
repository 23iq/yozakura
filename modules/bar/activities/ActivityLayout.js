.pragma library

// Pure geometry for live activity islands next to the notch. Unit tested in
// tests/activities.test.cjs.
//
// Placement rule: activities always attach to the notch's edge, as its
// satellites.
//   - classic bar on the notch's edge -> "pill": module-like pills inside the
//     bar strip, between the end of the left/right groups and the notch
//   - notch theme "island" (floating notch) -> "floating" pills that float
//     like the notch
//   - otherwise -> "tab": notch-shaped tabs growing out of the frame/edge
//     (islands bar on the notch's edge, or the bar on another edge)
//
// Sides: privacy indicators (recording, screen share, camera, mic) prefer
// the right of the notch, like a phone's status bar; tasks (timers, progress)
// prefer the left. A full side spills to the other one before anything
// collapses into the "+N" island.

function placement(opts) {
    var o = opts || {};
    var edge = o.notchPosition === "bottom" ? "bottom" : "top";
    var sameEdge = !!o.barEnabled && o.barPosition === edge;
    var mode = "tab";
    if (sameEdge && o.barStyle !== "islands")
        mode = "pill";
    else if (o.notchTheme === "island")
        mode = "floating";
    return {
        mode: mode,
        edge: edge,
        sameEdge: sameEdge
    };
}

function preferredSide(category) {
    return category === "privacy" ? "right" : "left";
}

// items:  [{ id, category, width }] in priority order (ActivityService order)
// opts:   { leftSpace, rightSpace, spacing, maxVisible, overflowWidth }
// Widths are full footprints (tabs include their fillets).
// Returns { left: [id], right: [id], overflow: { side, ids } | null } where
// each side lists ids from the notch outwards.
function distribute(items, opts) {
    var o = opts || {};
    var spacing = o.spacing || 0;
    var space = {
        left: Math.max(0, o.leftSpace || 0),
        right: Math.max(0, o.rightSpace || 0)
    };
    var used = {
        left: 0,
        right: 0
    };
    var placed = {
        left: [],
        right: []
    };
    var widthOf = {};
    var maxVisible = Math.max(1, o.maxVisible || 1);
    var overflowWidth = o.overflowWidth || 0;
    var overflow = [];

    function cost(side, width) {
        return (placed[side].length > 0 ? spacing : 0) + width;
    }
    function fits(side, width) {
        return used[side] + cost(side, width) <= space[side] + 0.5;
    }
    function put(side, item) {
        used[side] += cost(side, item.width);
        placed[side].push(item.id);
    }

    var list = items || [];
    for (var i = 0; i < list.length; i++) {
        var item = list[i];
        widthOf[item.id] = item.width;
        if (placed.left.length + placed.right.length >= maxVisible) {
            overflow.push(item.id);
            continue;
        }
        var first = preferredSide(item.category);
        var second = first === "left" ? "right" : "left";
        if (fits(first, item.width))
            put(first, item);
        else if (fits(second, item.width))
            put(second, item);
        else
            overflow.push(item.id);
    }

    if (overflow.length === 0)
        return {
            left: placed.left,
            right: placed.right,
            overflow: null
        };

    // Make room for "+N": drop the lowest-priority placed island until it
    // fits on some side (or nothing is left)
    for (;;) {
        var best = "";
        var sides = ["right", "left"];
        for (var s = 0; s < sides.length; s++) {
            var side = sides[s];
            if (fits(side, overflowWidth) && (best === "" || space[side] - used[side] > space[best] - used[best]))
                best = side;
        }
        if (best !== "")
            return {
                left: placed.left,
                right: placed.right,
                overflow: {
                    side: best,
                    ids: overflow
                }
            };
        var victimSide = lastPlacedSide(placed, list);
        if (victimSide === "")
            return {
                left: [],
                right: [],
                overflow: null
            };
        var victim = placed[victimSide].pop();
        used[victimSide] = 0;
        for (var k = 0; k < placed[victimSide].length; k++)
            used[victimSide] += (k > 0 ? spacing : 0) + widthOf[placed[victimSide][k]];
        overflow.unshift(victim);
    }
}

// Side holding the lowest-priority placed item ("" when none)
function lastPlacedSide(placed, list) {
    for (var i = list.length - 1; i >= 0; i--) {
        var id = list[i].id;
        if (placed.left.length && placed.left[placed.left.length - 1] === id)
            return "left";
        if (placed.right.length && placed.right[placed.right.length - 1] === id)
            return "right";
    }
    return "";
}

// Left x of every placed footprint. `notchStart`/`notchEnd` are the notch's
// outer x bounds (including its fillets), `gap` the distance kept from it.
// widths: { id: width }; overflowWidth for the "+N" island ("__overflow").
function positions(result, widths, notchStart, notchEnd, gap, spacing, overflowWidth) {
    var out = {};
    var x = notchStart - gap;
    var i;
    for (i = 0; i < result.left.length; i++) {
        x -= widths[result.left[i]] || 0;
        out[result.left[i]] = x;
        x -= spacing;
    }
    if (result.overflow && result.overflow.side === "left")
        out.__overflow = x - overflowWidth;
    x = notchEnd + gap;
    for (i = 0; i < result.right.length; i++) {
        out[result.right[i]] = x;
        x += (widths[result.right[i]] || 0) + spacing;
    }
    if (result.overflow && result.overflow.side === "right")
        out.__overflow = x;
    return out;
}
