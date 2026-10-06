.pragma library

// Advanced block: schema entries flagged `advanced: true` leave their
// section and gather, in page order, in one collapsed "Advanced" section at
// the end of the page. Categories.js applies it to every category, so the
// renderer, search (results point at this block, and revealing an entry
// unfolds it), resets and the generated catalog all see the same sections.
// A section whose entries are all advanced disappears; an entry keeps its
// section's `compositor` restriction.

var SECTION_ID = "advanced";

function apply(cat) {
    if (!cat || !cat.sections)
        return cat;
    var moved = [];
    var sections = [];
    cat.sections.forEach(function (sec) {
        var basic = (sec.entries || []).filter(function (e) {
            return !e.advanced;
        });
        (sec.entries || []).forEach(function (e) {
            if (e.advanced)
                moved.push(sec.compositor && !e.compositor ? copy(e, {
                    "compositor": sec.compositor
                }) : e);
        });
        if (basic.length === (sec.entries || []).length)
            sections.push(sec);
        else if (basic.length > 0)
            sections.push(copy(sec, {
                "entries": basic
            }));
    });
    if (moved.length === 0)
        return cat;
    sections.push({
        "id": SECTION_ID,
        "title": "prefs.common.advanced",
        "collapsible": true,
        "collapsed": true,
        "entries": moved
    });
    return copy(cat, {
        "sections": sections
    });
}

function copy(obj, extra) {
    var out = {};
    for (var k in obj)
        out[k] = obj[k];
    for (var e in extra)
        out[e] = extra[e];
    return out;
}
