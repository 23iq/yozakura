.pragma library

// The home bento (SettingsHome): a grid of six columns where a tile's size
// is the weight of its destination (Categories.HOME: w x h in six-column
// cells), four columns in a narrower window and two in a narrow one (spans
// scaled down, see pack). Pure, node-tested (tests/settings-home.test.cjs).
// The rows stretch so the grid fills the window (rowUnit).

var FULL = 6;

// Columns for a content width: 6 when a sixth of it is at least `minCell`,
// else 4, else 2. `current` (the count shown now) gives hysteresis: a grid
// keeps its columns until the width is a margin under the switch point, so
// a resize near it never makes the grid flip back and forth.
function columns(width, minCell, current) {
    var cell = Math.max(1, minCell);
    var counts = [FULL, 4];
    for (var i = 0; i < counts.length; i++) {
        var n = counts[i];
        var margin = current === n ? cell * n * 0.08 : 0;
        if (width >= cell * n - margin)
            return n;
    }
    return 2;
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
        var span = [t.w || 1, t.h || 1];
        // fewer columns: the spans shrink with the grid (a third of six
        // columns stays a third of four, at least one cell); in two columns
        // a tile wider than half the grid takes the whole width
        var w = cols >= FULL ? span[0] : cols <= 2 ? (span[0] * 2 > FULL ? cols : 1) : Math.max(1, Math.min(cols, Math.round(span[0] * cols / FULL)));
        var h = span[1];
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
    // no hole at the end of a line: the last one-row tile of a line takes
    // the free cells after it
    cells.forEach(function (c) {
        if (c.h !== 1)
            return;
        while (c.col + c.w < cols && free(c.col + c.w, c.row, 1, 1)) {
            take(c.col + c.w, c.row, 1, 1);
            c.w++;
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
