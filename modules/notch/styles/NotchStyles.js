.pragma library

// notch.style registry. Each style is data, not a branch in Notch.qml:
//   background  "attached" (flows out of the screen edge with concave
//               corners) | "island" (a floating rounded surface)
//   corners     concave screen corners next to the notch
//   gap         px between the screen edge and a floating notch
//   collapses   shrinks to a small capsule while idle (pill)
// Unit tested in tests/notch-styles.test.cjs.

var STYLES = {
    attached: { id: "attached", background: "attached", corners: true, gap: 0, collapses: false },
    island: { id: "island", background: "island", corners: false, gap: 4, collapses: false },
    pill: { id: "pill", background: "island", corners: false, gap: 4, collapses: true }
};

function spec(style) {
    return STYLES[style] || STYLES.attached;
}

// Legacy two-way name used before notch.style ("default" | "island").
function legacyTheme(style) {
    return spec(style).background === "attached" ? "default" : "island";
}

// Whether a collapsing style sits as a capsule right now. state: {
// hovered, open (a launcher/dashboard/... is in the notch), expanded
// (a panel is open), notifications, activities (live activities shown) }.
// Media alone keeps it collapsed: hovering reveals it.
function collapsed(s, state) {
    if (!s || !s.collapses)
        return false;
    var st = state || {};
    return !(st.hovered || st.open || st.expanded || st.notifications || st.activities);
}

// Size of the idle capsule: `unit` (Metrics.spacing) high, four units
// wide, so it reads as a quiet line on the edge rather than a button.
function capsule(unit) {
    var u = Math.max(4, Math.round(unit || 0));
    return { w: u * 4, h: u };
}
