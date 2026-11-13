.pragma library
.import "../../shell/osd/OsdStyles.js" as OsdStyles

// Where the on-screen display shows on the settings stage, by the shell's
// rules (OsdStyles.edgePref, then EdgeLayout.osdPlacement's order for
// "auto": the first free edge of bottom, top, right, left). Pure
// (tests/settings-osd-place.test.cjs).
//
// edge(style, pref, ctx) -> "top" | "bottom" | "left" | "right" | ""
// ctx: {notchPosition, notchEnabled, barEdge, occupied: [edges]}; "" for
// bar-inline (it lives in the bar, not on an edge).
var ORDER = ["bottom", "top", "right", "left"];

function edge(style, pref, ctx) {
    var c = ctx || {};
    if (OsdStyles.normalize(style) === "bar-inline")
        return "";
    var e = OsdStyles.edgePref(style, pref, c.notchPosition, c.notchEnabled, c.barEdge || "");
    if (ORDER.indexOf(e) !== -1)
        return e;
    var busy = c.occupied || [];
    for (var i = 0; i < ORDER.length; i++)
        if (busy.indexOf(ORDER[i]) === -1)
            return ORDER[i];
    return "bottom";
}

// The position values a click on an edge writes.
function positionFor(edgeName) {
    return ORDER.indexOf(edgeName) !== -1 ? edgeName : "auto";
}
