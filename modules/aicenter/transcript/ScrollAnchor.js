.pragma library

// Where a transcript view puts a remembered row back (TranscriptView's
// scroll memory): `at` is {key, source, index, offset} of the row that was
// at the top. The row is found by its key (indices move when thinking rows
// are shown or hidden); without it, the first row of the same or a later
// source item. `exact`: the key itself was found; `complete`: the rows of
// that source item are all there (a later item exists), so the stand-in
// will not change as more rows load. index -1: nothing to show yet.
// Tested in tests/transcript-scroll-anchor.test.cjs.
function resolve(count, rowAt, at) {
    var none = { "index": -1, "exact": false, "complete": false };
    if (!at || typeof at !== "object")
        return none;
    if (!at.key && typeof at.source !== "number") {
        // an index alone (no row identity to look for)
        return at.index >= 0 && at.index < count ? { "index": at.index, "exact": true, "complete": true } : none;
    }
    var stand = -1;
    var later = false;
    for (var i = 0; i < count; i++) {
        var r = rowAt(i) || {};
        if (at.key && r.key === at.key)
            return { "index": i, "exact": true, "complete": true };
        if (typeof at.source === "number" && r.source >= at.source) {
            if (stand < 0)
                stand = i;
            if (r.source > at.source)
                later = true;
        }
    }
    return { "index": stand, "exact": false, "complete": stand >= 0 && later };
}
