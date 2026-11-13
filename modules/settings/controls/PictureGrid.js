.pragma library

// The size of picture cards in a grid (CardSelector and the picture
// editors): compact cards of about `min` px (default 124, five or six a row
// in a wide card), never wider than `max` (150), at least two a row, never
// more columns than options.

function columns(width, gap, count, min) {
    var m = min || 124;
    var n = Math.floor((width + gap) / (m + gap));
    return Math.max(2, Math.min(count > 0 ? count : n, n));
}

function cardWidth(width, gap, cols, max) {
    var c = Math.max(1, cols);
    return Math.min((width - gap * (c - 1)) / c, max || 150);
}
