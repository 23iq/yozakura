.pragma library

// Wallpaper grid geometry. The dashboard keeps one size for every tab, so the
// grid reflows into whatever width the tab gets instead of using a fixed
// column count.
var MIN_COLUMNS = 3;
var MAX_COLUMNS = 12;

// Column count for a grid `width` px wide with cells about `cell` px square.
function columnsFor(width, cell) {
    if (!(width > 0) || !(cell > 0))
        return MIN_COLUMNS;
    return Math.max(MIN_COLUMNS, Math.min(MAX_COLUMNS, Math.round(width / cell)));
}
