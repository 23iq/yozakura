.pragma library

// Pure helpers of the Widgets & clock stage (node-tested in
// tests/settings-desktop-place.test.cjs): where the depth clock sits on the
// miniature and where it can be moved.

// The depth clock's side: where its real layout put it (`drawn`: "left" |
// "right" | "", the centre of its bounds on the screen), else what its
// position setting says ("auto" sits right).
function clockSide(position, drawn) {
    if (drawn === "left" || drawn === "right")
        return drawn;
    return position === "left" ? "left" : "right";
}

// The side a "Move here" target offers: the other one, when the style can
// sit there (`sides`: the style's placements); "" when there is none.
function moveTarget(side, sides) {
    var other = side === "left" ? "right" : "left";
    var can = sides && sides.length ? sides : ["right"];
    return can.indexOf(other) >= 0 ? other : "";
}

// The side of a clock drawn at `bounds` ({x, w}) on a screen `screenW` wide.
function sideOf(bounds, screenW) {
    if (!bounds || !(bounds.w > 0) || !(screenW > 0))
        return "";
    return bounds.x + bounds.w / 2 < screenW / 2 ? "left" : "right";
}
