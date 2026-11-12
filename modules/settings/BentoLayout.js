.pragma library

// The bento of a settings page (SettingsPage): cards of one or two column
// spans packed into `cols` columns, each going where its columns are the
// shortest (masonry, reading order kept as far as the heights allow).
// Pure, node-tested (tests/settings-home.test.cjs).

// Columns for a body width.
function columns(width, minCard) {
    var n = Math.floor(width / Math.max(1, minCard));
    return Math.max(1, Math.min(3, n));
}

// items: [{span, height}] -> [{col, span, y}] and the total height, as
// {places, height}. `gap` between cards in both directions.
function place(items, cols, gap) {
    var tops = [];
    for (var c = 0; c < cols; c++)
        tops.push(0);
    var places = [];
    items.forEach(function (it) {
        var span = Math.max(1, Math.min(cols, it.span || 1));
        var best = 0, bestTop = Infinity;
        for (var c = 0; c + span <= cols; c++) {
            var top = 0;
            for (var k = c; k < c + span; k++)
                top = Math.max(top, tops[k]);
            if (top < bestTop - 0.5) {
                bestTop = top;
                best = c;
            }
        }
        places.push({
            "col": best,
            "span": span,
            "y": bestTop
        });
        if (it.height > 0)
            for (var k = best; k < best + span; k++)
                tops[k] = bestTop + it.height + gap;
    });
    var height = 0;
    tops.forEach(function (t) {
        height = Math.max(height, t);
    });
    return {
        "places": places,
        "height": Math.max(0, height - gap)
    };
}

// The span a schema section asks for: `span` when it sets one, else two
// columns when it holds a full-width control (picture cards, an editor, a
// list, a macro slider), one otherwise.
function spanOf(section, inWindow) {
    if (section && section.span)
        return section.span;
    var wide = (section && section.entries || []).some(function (e) {
        if (inWindow && !inWindow(e, section))
            return false;
        return e.type === "custom" || e.type === "list" || e.type === "multiselect" || e.type === "screens" || e.type === "color-role" || e.type === "macro" || e.display === "cards";
    });
    return wide ? 2 : 1;
}
