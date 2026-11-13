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

// items: [{span, height}] -> [{col, span, y}], the total height and the
// floor (where the shortest column ends: any card placed after these lands
// at or below it), as {places, height, floor}. `gap` between cards in both
// directions.
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
    var height = 0, floor = Infinity;
    tops.forEach(function (t) {
        height = Math.max(height, t);
        floor = Math.min(floor, t);
    });
    return {
        "places": places,
        "height": Math.max(0, height - gap),
        "floor": Math.max(0, floor - gap)
    };
}

// Picture editors whose compact cards wrap in a single column (like
// `display: "cards"`): they never make their card wide.
var COMPACT_PICTURES = ["BarStyleCards", "PanelStyleCards", "PanelShapeCards", "SchemeGallery", "MotionProfileCards", "ThemeModeCards"];

// The span a schema section asks for: `span` when it sets one, else two
// columns when it holds a full-width control (an editor, a list), one
// otherwise (picture cards are compact and wrap: one column).
function spanOf(section, inWindow) {
    if (section && section.span)
        return section.span;
    var wide = (section && section.entries || []).some(function (e) {
        if (inWindow && !inWindow(e, section))
            return false;
        if (e.type === "custom" && COMPACT_PICTURES.indexOf(e.component) >= 0)
            return false;
        return e.type === "custom" || e.type === "list" || e.type === "multiselect" || e.type === "screens" || e.type === "color-role";
    });
    return wide ? 2 : 1;
}

// Columns a page uses out of `cols`: never more than its cards fill (one
// narrow card takes one column, centred, never a row of empty ones), and
// when every card is wide (spans >= 2) two at most.
function fit(cols, spans) {
    var list = spans || [];
    var narrow = list.some(function (s) {
        return s < 2;
    });
    var total = list.reduce(function (a, s) {
        return a + s;
    }, 0);
    return Math.max(1, Math.min(narrow ? cols : Math.min(cols, 2), total || cols));
}

// How much room a card's rows take per row: 0 for plain rows (switches,
// short selectors, sliders), 1 for one big control (pictures, an editor, a
// list). Used to order the cards after the lead ones.
function heaviness(section, inWindow) {
    var heavy = (section && section.entries || []).some(function (e) {
        if (inWindow && !inWindow(e, section))
            return false;
        return e.type === "custom" || e.type === "list" || e.type === "multiselect" || e.type === "screens" || e.display === "cards";
    });
    return heavy ? 1 : 0;
}

// The page order of `sections` (indexes): the lead ids first (as listed),
// then cards of plain rows, then the ones holding a big control, each in
// schema order. The first screen shows the most rows that way.
function order(sections, leadIds, inWindow) {
    var secs = sections || [];
    var lead = (leadIds || []).map(function (id) {
        for (var i = 0; i < secs.length; i++)
            if (secs[i].id === id)
                return i;
        return -1;
    }).filter(function (i) {
        return i >= 0;
    });
    var rest = [];
    for (var i = 0; i < secs.length; i++)
        if (lead.indexOf(i) < 0)
            rest.push(i);
    var light = rest.filter(function (i) {
        return heaviness(secs[i], inWindow) === 0;
    });
    var heavy = rest.filter(function (i) {
        return heaviness(secs[i], inWindow) !== 0;
    });
    return lead.concat(light, heavy);
}
