.pragma library

// Pure (tests/settings-picture-grid.test.cjs): the one layout of every
// single-choice picture grid (ChoiceGrid, CardSelector and the picture
// editors): as many columns as cards of about `min` px fit, the rows
// balanced (no orphan: 6 -> 3 + 3, 7 -> 4 + 3, 8 -> 4 + 4, never 4 + 1 or
// 4 + 2), each card stretched so every row reaches the card's edge.

// All the options stay on one line when each still gets 70 % of `min`
// (five styles in a narrow card: one line of smaller pictures, not 4 + 1).
function columns(width, gap, count, min) {
    var m = min || 124;
    if (count > 0 && count * m * 0.7 + (count - 1) * gap <= width)
        return Math.max(2, count);
    var fit = Math.max(2, Math.floor((width + gap) / (m + gap)));
    if (!(count > 0))
        return fit;
    // the fewest rows that hold them, then the fewest columns that keep
    // that many rows: the rows come out even (or one short)
    var rows = Math.ceil(count / fit);
    return Math.max(2, Math.ceil(count / rows));
}

// The width of a card: the row filled edge to edge. `max` (callers pass
// about 190) only stops a very short row (two options in a wide card) from
// growing into posters: up to one and a half times it.
function cardWidth(width, gap, cols, max) {
    var c = Math.max(1, cols);
    var fill = (width - gap * (c - 1)) / c;
    return Math.floor(Math.min(fill, (max || 150) * 1.5));
}

// [{x, y}] of `count` cards `w` x `h` in `cols` columns, `gap` apart, the
// short last row centred under the full ones.
function places(count, cols, w, h, gap) {
    var out = [];
    var c = Math.max(1, cols);
    var full = Math.floor(count / c) * c;
    var rowW = c * w + (c - 1) * gap;
    for (var i = 0; i < count; i++) {
        var r = Math.floor(i / c);
        var k = i % c;
        var inRow = i < full ? c : count - full;
        var left = i < full ? 0 : (rowW - (inRow * w + (inRow - 1) * gap)) / 2;
        out.push({
            "x": Math.round(left + k * (w + gap)),
            "y": r * (h + gap)
        });
    }
    return out;
}
