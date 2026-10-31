.pragma library

// Does a saved screenshot belong on this screen's preview? True when the
// selection point lies inside the screen; for full-screen captures the
// screen under the cursor shows it.
// screen: {x, y, width, height, name}; sel: {x, y}; cursorScreen: name or "".
function showsPreview(screen, sel, mode, cursorScreen) {
    if (!screen)
        return false;
    if (sel.x >= screen.x && sel.x < screen.x + screen.width && sel.y >= screen.y && sel.y < screen.y + screen.height)
        return true;
    return mode === "screen" && cursorScreen === screen.name;
}
