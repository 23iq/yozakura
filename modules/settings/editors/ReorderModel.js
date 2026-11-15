.pragma library

// Pure model of the reorderable lists (ReorderList.qml): where a dragged row
// lands and the moves the keyboard makes. Only the first `movable` rows
// have an order (the rest, if any, stay after them). Node-tested
// (tests/settings-reorder.test.cjs).

// The slot boundary (0..movable) nearest a pointer at `y` (from the top of
// the list) over rows `rowHeight` tall: the insertion line shows above that
// slot.
function slotAt(y, rowHeight, movable) {
    if (rowHeight <= 0)
        return 0;
    return Math.max(0, Math.min(movable, Math.round(y / rowHeight)));
}

// The index a row dragged from `from` ends at when dropped on `slot` (the
// row itself leaves its place first).
function dropIndex(from, slot) {
    return slot > from ? slot - 1 : slot;
}

// The index one key press moves row `from` to (`dir` -1 / +1), kept among
// the movable rows; `from` itself where it cannot move.
function stepIndex(from, dir, movable) {
    if (from < 0 || from >= movable)
        return from;
    return Math.max(0, Math.min(movable - 1, from + dir));
}
