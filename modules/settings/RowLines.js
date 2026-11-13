.pragma library

// Pure (tests/settings-row-lines.test.cjs): the lines of a card's rows.
// Picture choices that follow each other share one line when all their
// pictures fit it at `min` px each (Wallpaper: the two fits beside the six
// transitions, one row of pictures instead of two half-empty ones); every
// other row is a line of its own. A row that folds open or shut
// (`visibleWhen`) never shares: its neighbour would be left half a line.

// A row of pictures that may share a line: its option count, else 0.
function pictures(entry) {
    if (!entry || entry.display !== "cards" || entry.visibleWhen || entry.advanced)
        return 0;
    var n = (entry.options || []).length;
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

// The width of row `k` of `line` in `width`: its share by picture count,
// the gaps between the rows taken out first.
function share(entries, line, k, width, gap) {
    if (line.length < 2)
        return width;
    var total = 0;
    line.forEach(function (i) {
        total += pictures(entries[i]);
    });
    var room = width - gap * 2 * (line.length - 1);
    return Math.floor(room * pictures(entries[line[k]]) / Math.max(1, total));
}
