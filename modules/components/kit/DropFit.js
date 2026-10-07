.pragma library

// Where a kit drop-down list opens, relative to its anchor control: below by
// default, above when it does not fit under the anchor but fits over it, so a
// control near the bottom of its window never opens a list off-screen.
// Unit tested in tests/kit-dropfit.test.cjs.
//   anchorTop  anchor's top edge in window coordinates
//   anchorH    anchor height, listH the list height, gap the space between
//   winH       window height
function dropY(anchorTop, anchorH, listH, gap, winH) {
    var below = anchorH + gap;
    if (!(winH > 0) || anchorTop + below + listH <= winH)
        return below;
    var above = -listH - gap;
    return anchorTop + above >= 0 ? above : below;
}
