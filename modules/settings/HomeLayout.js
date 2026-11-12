.pragma library

// The home bento (SettingsHome): how many columns a width takes and where
// each tile sits. Pure, node-tested (tests/settings-home.test.cjs).
// Tiles are `w` columns by `h` row units (Categories.HOME: a 12-column grid
// of half-row units); a tile never gets wider than the grid. The rows
// stretch so the bento fills the window (rowUnit).

var SPANS = {
    "big": [6, 8],
    "wide": [3, 4],
    "small": [2, 4]
};

// Columns for a content width: 12 (the whole bento side by side), else 6
// (the hero full width, the rest in halves and thirds).
function columns(width, minColumn) {
    return width >= Math.max(1, minColumn) * 12 ? 12 : 6;
}

// The height of one row unit so `rows` units (and their gaps) fill
// `height`, never under `minUnit` (then the bento scrolls).
function rowUnit(height, rows, gap, minUnit) {
    if (rows <= 0)
        return minUnit;
    return Math.max(minUnit, (height - gap * (rows - 1)) / rows);
}

// First-fit packing in reading order: [{id, col, row, w, h}] and the row
// count, as {cells, rows}.
function pack(tiles, cols) {
    var used = [];
    function free(c, r, w, h) {
        for (var y = r; y < r + h; y++)
            for (var x = c; x < c + w; x++)
                if (x >= cols || (used[y] && used[y][x]))
                    return false;
        return true;
    }
    function take(c, r, w, h) {
        for (var y = r; y < r + h; y++) {
            used[y] = used[y] || [];
            for (var x = c; x < c + w; x++)
                used[y][x] = true;
        }
    }
    var cells = [];
    var rows = 0;
    tiles.forEach(function (t) {
        var span = t.w ? [t.w, t.h || 1] : (SPANS[t.size] || SPANS.small);
        var w = Math.min(span[0], cols), h = span[1];
        for (var r = 0; ; r++) {
            var placed = false;
            for (var c = 0; c + w <= cols; c++) {
                if (free(c, r, w, h)) {
                    take(c, r, w, h);
                    cells.push({
                        "id": t.id,
                        "col": c,
                        "row": r,
                        "w": w,
                        "h": h
                    });
                    rows = Math.max(rows, r + h);
                    placed = true;
                    break;
                }
            }
            if (placed)
                break;
        }
    });
    return {
        "cells": cells,
        "rows": rows
    };
}

// Arrow-key move from cell `from` (index into cells) in direction
// "left" | "right" | "up" | "down": a tile that lines up with it (shares a
// row for left/right, a column for up/down) beats one off to the side; then
// the smallest gap, the closest centre and reading order. `from` when there
// is none that way.
function neighbour(cells, from, dir) {
    var a = cells[from];
    if (!a)
        return from;
    var across = dir === "left" || dir === "right";
    var best = from, bestD = Infinity;
    for (var i = 0; i < cells.length; i++) {
        if (i === from)
            continue;
        var b = cells[i];
        var gap = dir === "left" ? a.col - (b.col + b.w) : dir === "right" ? b.col - (a.col + a.w) : dir === "up" ? a.row - (b.row + b.h) : b.row - (a.row + a.h);
        if (gap < 0)
            continue;
        var lo = across ? Math.max(a.row, b.row) : Math.max(a.col, b.col);
        var hi = across ? Math.min(a.row + a.h, b.row + b.h) : Math.min(a.col + a.w, b.col + b.w);
        var side = across ? Math.abs(b.row + b.h / 2 - a.row - a.h / 2) : Math.abs(b.col + b.w / 2 - a.col - a.w / 2);
        var d = (hi > lo ? 0 : 1000) + gap * 10 + side;
        if (d < bestD) {
            bestD = d;
            best = i;
        }
    }
    return best;
}
