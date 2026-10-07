.pragma library

// State -> look of the kit's interactive controls (IconButton, Chip, ListRow).
// One rule for the whole shell:
//   normal   the rest variant: "common" (the visual language decides ghost /
//            translucent / solid) or "transparent" for list rows
//   hover    "focus" (also keyboard highlight)
//   active   accent tint: the "primary" variant at 16% (24% hovered), accent glyph
//   primary  the one filled accent action of a surface
// Unit tested in tests/kit-states.test.cjs.

var TINT = 0.16;
var TINT_HOVER = 0.24;

function look(primary, active, hovered) {
    if (primary)
        return "primary";
    if (active)
        return "active";
    return hovered ? "hover" : "normal";
}

function variant(lk, rest) {
    if (lk === "primary" || lk === "active")
        return "primary";
    if (lk === "hover")
        return "focus";
    return rest || "common";
}

// StyledRect.backgroundOpacity (-1 keeps the variant's own opacity).
function opacity(lk, hovered) {
    if (lk === "primary")
        return hovered ? 0.88 : 1;
    if (lk === "active")
        return hovered ? TINT_HOVER : TINT;
    return -1;
}

// Glyph / label ink: "accentInk" on the filled primary, "accent" on a tint.
function ink(lk) {
    if (lk === "primary")
        return "accentInk";
    return lk === "active" ? "accent" : "text";
}
