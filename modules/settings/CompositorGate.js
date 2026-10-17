.pragma library

// Which compositors an entry / section is shown on. `spec` is one name
// ("hyprland") or a list (["hyprland", "mango"]); no spec = every compositor.
// A single name keeps the strict behaviour (hidden until the compositor is
// known); a list also shows while the name is still being probed, so a page
// does not flash empty.
// A list may arrive as a sequence instead of a JS array: schema entries
// that went through a Repeater model are QVariant copies, their string
// lists QStringList sequences (Array.isArray is false for those).
function allows(spec, name) {
    if (!spec)
        return true;
    if (typeof spec === "string")
        return name === spec;
    var list = _specList(spec);
    return list.length === 0 || !name || list.indexOf(name) !== -1;
}

var _LABELS = { "hyprland": "Hyprland", "niri": "niri", "mango": "MangoWC" };

function _specList(spec) {
    if (!spec)
        return [];
    return typeof spec === "string" ? [spec] : Array.prototype.slice.call(spec);
}

// What the compositor gate hides of `sections` (a page's schema sections)
// on compositor `name`: {count, compositors}. count = entries not shown
// because their own spec, or their section's, excludes `name` (entries
// hidden by visibleWhen are not counted); compositors = the ones that do
// support them, in first-seen order. Nothing is counted while the name is
// still unknown.
function hiddenBy(sections, name) {
    var out = { "count": 0, "compositors": [] };
    if (!name || !Array.isArray(sections))
        return out;
    function note(spec) {
        _specList(spec).forEach(function (c) {
            if (out.compositors.indexOf(c) === -1)
                out.compositors.push(c);
        });
    }
    sections.forEach(function (s) {
        var entries = s && Array.isArray(s.entries) ? s.entries : [];
        if (s && !allows(s.compositor, name)) {
            out.count += entries.length;
            note(s.compositor);
            return;
        }
        entries.forEach(function (e) {
            if (e && !allows(e.compositor, name)) {
                out.count++;
                note(e.compositor);
            }
        });
    });
    return out;
}

// "Hyprland, MangoWC" for a list of compositor ids.
function describe(compositors) {
    return (compositors || []).map(function (c) {
        return _LABELS[c] || c;
    }).join(", ");
}
