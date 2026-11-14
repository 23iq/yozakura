.pragma library

// Pure (tests/settings-control-column.test.cjs): the control column of a
// settings card. Every inline segmented, dropdown, slider and text field of
// a card takes one width, flush right, so their left edges line up row to
// row (a switch and a stepper keep their own width: they share the right
// edge). The column is as wide as the widest of those controls needs, at
// least `MIN` and at most `LIMIT` of the row's width; a control that goes
// under its label (SettingRow.stacked) does not size it, and a row whose
// label would not fit beside it keeps its control's own width.

var MIN = 0.4;
var LIMIT = 0.8;

// What a row's inline control needs, in px (0: not a column control).
// `measure(text)` = the width of a (translated) text in the row font (with
// its margin), `tr(key)` translates a label,
// `px(v)` = Space.px. `bare`: without the segments' glyphs (the estimate
// SettingRow stacks a segmented by).
function need(entry, measure, px, tr, bare) {
    if (!entry || entry.advanced)
        return 0;
    var t = entry.type;
    if (t === "slider")
        return px(240);
    // a font picker without its size: the family name whole
    if (t === "font")
        return entry.sizeKey ? 0 : px(260);
    if (t === "text")
        return entry.multiline === true ? 0 : px(240);
    if (t !== "selector" || entry.display === "cards")
        return 0;
    var options = entry.options || [];
    if (options.length === 0)
        return 0;
    if (entry.iconOnly === true)
        return options.length * px(44);
    var longest = 0;
    var icons = false;
    for (var i = 0; i < options.length; i++) {
        longest = Math.max(longest, measure(tr ? tr(options[i].label) : options[i].label));
        icons = icons || !!options[i].icon;
    }
    // a glyph before the name (and its gap)
    if (icons && !bare)
        longest += px(24);
    // more options than segments hold: a dropdown, as wide as its longest
    if (options.length > 4)
        return longest + px(100);
    return options.length * (longest + px(40));
}

// The readout width every stepper of a card shares (its - / + buttons line
// up row to row): the widest value any of them can show (each range's ends
// and its special values' names), `text(value, entry)` measuring one.
function readout(entries, text) {
    var w = 0;
    (entries || []).forEach(function (e) {
        if (!e || e.advanced || e.type !== "number")
            return;
        var samples = [e.min, e.max];
        (e.specialValues || []).forEach(function (s) {
            samples.push(s.value);
        });
        samples.forEach(function (v) {
            if (v !== undefined && v !== null && isFinite(v))
                w = Math.max(w, text(v, e));
        });
    });
    return Math.ceil(w);
}

// The card's column in px for rows `width` wide (0: no column control).
function column(entries, measure, width, px, tr) {
    var widest = 0;
    var label = 0;
    (entries || []).forEach(function (e) {
        var n = need(e, measure, px, tr);
        if (n <= 0)
            return;
        // a control that cannot stand beside the longest word of its label
        // goes under it (SettingRow.stacked): it does not size the column
        var text = String(tr && e.label ? tr(e.label) : (e.label || ""));
        var word = 0;
        text.split(" ").forEach(function (w) {
            word = Math.max(word, measure(w));
        });
        if (word + need(e, measure, px, tr, true) + px(88) > width)
            return;
        widest = Math.max(widest, n);
        label = Math.max(label, measure(text));
    });
    if (widest <= 0 || !(width > 0))
        return 0;
    // never so wide that a label of the column's rows leaves its line (a
    // row whose label still would not fit keeps its own control width:
    // SettingRow.columnar)
    // (the label keeps two gaps beside the control: SettingRow)
    var cap = Math.min(width * LIMIT, width - label - px(40));
    return Math.max(0, Math.round(Math.min(Math.max(width * MIN, widest), cap)));
}
