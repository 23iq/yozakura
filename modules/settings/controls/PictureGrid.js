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
// growing into posters: up to 1.4 times it.
function cardWidth(width, gap, cols, max) {
    var c = Math.max(1, cols);
    var fill = (width - gap * (c - 1)) / c;
    return Math.floor(Math.min(fill, (max || 150) * 1.4));
}

// One cell size per card: the columns every picture grid of a card shares
// (`counts`: their option counts) - the fewest any of them takes, but three
// at least where one of them would take three or more (Theme: the three
// modes and the five styles both in three columns, 3 and 3 + 2, one cell
// size; not three big pictures over five tiny ones). 0 for a single grid.
function shared(counts, width, gap, min) {
    if (!counts || counts.length < 2)
        return 0;
    var lo = 1e9;
    var hi = 0;
    counts.forEach(function (n) {
        var c = columns(width, gap, n, min);
        lo = Math.min(lo, c);
        hi = Math.max(hi, c);
    });
    return Math.max(lo, Math.min(3, hi));
}

// The columns of a library of `count` pictures that fit `fit` a row (it
// shows `maxRows` rows and scrolls past them): `fit`, one less or up to two
// more, the nearest that divides the library evenly, else whose last row is
// more than half full (never 3 + 3 + 3 + 1), else `fit`.
function libraryColumns(count, fit, maxRows) {
    var f = Math.max(2, fit);
    if (!(count > 0) || count > f * maxRows)
        return f;
    var order = [f, f + 1, f - 1, f + 2];
    var ok = function (c, full) {
        if (c < 2 || Math.ceil(count / c) > maxRows)
            return false;
        var rest = count % c;
        return full ? rest === 0 : rest === 0 || rest > c / 2;
    };
    for (var i = 0; i < order.length; i++)
        if (ok(order[i], true))
            return order[i];
    for (var j = 0; j < order.length; j++)
        if (ok(order[j], false))
            return order[j];
    return f;
}

// [{x, y}] of `count` cards `w` x `h` in `cols` columns, `gap` apart, the
// short last row centred under the full ones (a single short row starts at
// the left, like the rows around it).
function places(count, cols, w, h, gap) {
    var out = [];
    var c = Math.max(1, cols);
    var full = Math.floor(count / c) * c;
    var rowW = c * w + (c - 1) * gap;
    for (var i = 0; i < count; i++) {
        var r = Math.floor(i / c);
        var k = i % c;
        var inRow = i < full ? c : count - full;
        var left = i < full || full === 0 ? 0 : (rowW - (inRow * w + (inRow - 1) * gap)) / 2;
        out.push({
            "x": Math.round(left + k * (w + gap)),
            "y": r * (h + gap)
        });
    }
    return out;
}
