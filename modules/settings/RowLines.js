.pragma library

// Pure (tests/settings-row-lines.test.cjs): the lines of a card's rows.
// Picture choices that follow each other share one line when all their
// pictures fit it at `min` px each (Wallpaper: the two fits beside the six
// transitions, one row of pictures instead of two half-empty ones); every
// other row is a line of its own. A row that folds open or shut
// (`visibleWhen`) never shares: its neighbour would be left half a line.

// A row of pictures that may share a line: its option count (a picture
// editor declares its own: `pictures`), else 0.
function pictures(entry) {
    if (!entry || entry.visibleWhen || entry.advanced)
        return 0;
    var n = entry.display === "cards" ? (entry.options || []).length : entry.type === "custom" ? (entry.pictures || 0) : 0;
    return n >= 2 ? n : 0;
}

// The pictures a row shows, folding or not (rows beside them stay beside:
// the line keeps its place while the pictures fold away).
function shown(entry) {
    if (!entry || entry.advanced)
        return 0;
    var n = entry.display === "cards" ? (entry.options || []).length : entry.type === "custom" ? (entry.pictures || 0) : 0;
    return n >= 2 ? n : 0;
}

// [[index, ...], ...] over `entries`: consecutive picture rows grouped while
// their pictures fit `width` at `min` px with `gap` between them.
function lines(entries, width, gap, min) {
    var out = [];
    var line = [];
    var count = 0;
    function flush() {
        if (line.length > 0)
            out.push(line);
        line = [];
        count = 0;
    }
    (entries || []).forEach(function (e, i) {
        var n = pictures(e);
        if (n === 0) {
            flush();
            out.push([i]);
            return;
        }
        // the pictures of the line so far and this row's, gaps between all
        // of them and a wider one between rows
        var total = count + n;
        var need = total * min + (total - line.length - 1) * gap + line.length * gap * 2;
        if (line.length > 0 && need > width)
            flush();
        line.push(i);
        count += n;
    });
    flush();
    return out;
}

// The width of row `k` of `line` in `width`: its share by picture count
// (equal shares for rows without pictures), the gaps between the rows
// taken out first.
function share(entries, line, k, width, gap) {
    if (line.length < 2)
        return width;
    var total = 0;
    line.forEach(function (i) {
        total += pictures(entries[i]);
    });
    var room = width - gap * 2 * (line.length - 1);
    // rows without pictures (a pair of switches) share it equally
    if (total === 0)
        return Math.floor(room / line.length);
    return Math.floor(room * pictures(entries[line[k]]) / Math.max(1, total));
}

// A short row that may stand beside pictures: a switch, a few-way choice or
// a number (one line, never a list, a picture or an editor).
function small(entry) {
    if (!entry || entry.advanced)
        return false;
    if (entry.type === "toggle" || entry.type === "number")
        return true;
    return entry.type === "selector" && entry.display !== "cards";
}

// The lines with what stands beside them: [{rows: [index...], side:
// [index...]}]. A line of one picture row whose pictures (`max` px each at
// most) leave `sideMin` px or more of the width takes the short rows that
// follow it (three at most) in a column beside the pictures (Terminal: the
// prompt switches beside the three prompts, Bar: the frame switches beside
// the four edges). In a card `pairMin` px wide or more, short rows that
// follow each other go two a line (a wide card of switches is two columns of
// them, not one stretched across the page).
function layout(entries, width, gap, min, max, sideMin, pairMin) {
    var base = lines(entries, width, gap, min);
    var out = [];
    for (var i = 0; i < base.length; i++) {
        var line = base[i];
        var item = {
            "rows": line,
            "side": []
        };
        out.push(item);
        if (line.length !== 1)
            continue;
        var n = shown(entries[line[0]]);
        if (n === 0 || width - (n * max + (n - 1) * gap) - gap * 2 < sideMin)
            continue;
        while (item.side.length < 3 && i + 1 < base.length && base[i + 1].length === 1 && small(entries[base[i + 1][0]])) {
            item.side.push(base[i + 1][0]);
            i++;
        }
    }
    if (!(pairMin > 0) || width < pairMin)
        return out;
    // a wide card: short rows that follow each other go two a line
    var paired = [];
    out.forEach(function (it) {
        var prev = paired.length > 0 ? paired[paired.length - 1] : null;
        if (pairable(entries, it) && prev && prev.rows.length === 1 && pairable(entries, prev))
            prev.rows.push(it.rows[0]);
        else
            paired.push(it);
    });
    return paired;
}

// A line of one short row that never folds: it may share a wide card's line.
function pairable(entries, item) {
    if (item.rows.length !== 1 || item.side.length > 0)
        return false;
    var e = entries[item.rows[0]];
    // a screens row (a label over a few chips) pairs too
    return (small(e) || (!!e && e.type === "screens" && !e.advanced)) && !e.visibleWhen;
}

// The width of the pictures of a line with rows beside them: as many as
// they are at `max` px; the rest of the width (less a wide gap) is the
// column beside.
function picturesWidth(entries, item, width, gap, max) {
    if (!item.side || item.side.length === 0)
        return width;
    var n = shown(entries[item.rows[0]]);
    return Math.min(width, n * max + (n - 1) * gap);
}
