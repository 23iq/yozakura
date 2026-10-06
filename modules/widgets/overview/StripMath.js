.pragma library

// Pure geometry and selection maths of the overview filmstrip.

function step(selected, dir, count) {
    return Math.max(1, Math.min(count, selected + dir));
}

// Workspaces shown: the configured number, grown to hold the active one and
// every window's workspace.
function count(shown, active, windows) {
    let n = Math.max(1, shown || 0, active || 0);
    (windows || []).forEach(w => {
        const id = w && w.workspace ? w.workspace.id : 0;
        if (id > n)
            n = id;
    });
    return n;
}

// Cells in view at once: odd so one sits in the middle, never more than exist.
function visibleCount(wanted, total) {
    let n = Math.max(1, Math.min(wanted || 1, total));
    if (n % 2 === 0)
        n -= 1;
    return Math.max(1, n);
}

function cellX(cellW, gap, ws) {
    return (ws - 1) * (cellW + gap);
}

// Belt x that puts the selected cell in the middle of the viewport.
function beltX(viewportW, cellW, gap, selected) {
    return viewportW / 2 - (cellX(cellW, gap, selected) + cellW / 2);
}

// 1 for the selected cell, fading with distance down to a floor.
function emphasis(ws, selected) {
    const d = Math.abs(ws - selected);
    if (d === 0)
        return 1;
    return Math.max(0.25, 0.7 - (d - 1) * 0.2);
}
