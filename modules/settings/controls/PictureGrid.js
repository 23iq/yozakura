.pragma library

// The size of picture cards in a grid (CardSelector and the picture
// editors): as many columns as cards of about `min` px fit (never more than
// options, at least two), each column stretched to fill the row up to `max`
// (callers pass about 190) so a row of pictures ends at the card's edge.

// All the options stay on one line when each still gets 85 % of `min`
// (three shapes in a narrow card: one line of pictures, not two and one).
function columns(width, gap, count, min) {
    var m = min || 124;
    if (count > 0 && count * m * 0.85 + (count - 1) * gap <= width)
        return Math.max(2, count);
    var n = Math.floor((width + gap) / (m + gap));
    return Math.max(2, Math.min(count > 0 ? count : n, n));
}

function cardWidth(width, gap, cols, max) {
    var c = Math.max(1, cols);
    return Math.min((width - gap * (c - 1)) / c, max || 150);
}
