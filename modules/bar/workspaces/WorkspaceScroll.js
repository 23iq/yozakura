.pragma library

// The workspace a wheel step over the workspaces widget goes to (a relative
// dispatch for the compositor): down = the next one, up = the previous one;
// `invert` (workspaces.invertScroll) swaps them. "" for no vertical step.
// Tested in tests/workspace-scroll.test.cjs.
function target(deltaY, invert) {
    var dy = invert ? -deltaY : deltaY;
    if (dy < 0)
        return "workspace r+1";
    if (dy > 0)
        return "workspace r-1";
    return "";
}
