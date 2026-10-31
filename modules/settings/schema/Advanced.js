.pragma library

// Simple / All view of a settings page (general.settingsShowAll, the
// toggle in the sidebar). Schema entries flagged `advanced: true` are the
// expert knobs: raw px / ms numbers, plumbing "Match shell ..." switches,
// endpoints, per-surface opacities. Simple (the default) hides them and a
// section left without rows; All shows every entry in place, next to the
// row it refines. Search always indexes every entry: jumping to an advanced
// one in Simple reveals just that row (`revealed`: {entryId: true}).

function entryId(entry) {
    return entry ? (entry.id || entry.key || "") : "";
}

// Is the entry shown in the current view?
function shown(entry, showAll, revealed) {
    if (!entry || !entry.advanced || showAll)
        return true;
    return !!(revealed && revealed[entryId(entry)]);
}

// Advanced entries of a category hidden by Simple right now. `visible`
// (optional): the page's own filter (compositor gate, visibleWhen), so the
// count only names rows All would really show.
function hiddenCount(cat, showAll, revealed, visible) {
    if (showAll || !cat || !cat.sections)
        return 0;
    var n = 0;
    cat.sections.forEach(function (sec) {
        (sec.entries || []).forEach(function (e) {
            if (!shown(e, false, revealed) && (!visible || visible(e, sec)))
                n++;
        });
    });
    return n;
}

// Count of every advanced entry (the audit / tests).
function advancedCount(categories) {
    var n = 0;
    (categories || []).forEach(function (cat) {
        (cat.sections || []).forEach(function (sec) {
            (sec.entries || []).forEach(function (e) {
                if (e.advanced)
                    n++;
            });
        });
    });
    return n;
}
