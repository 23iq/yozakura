.pragma library

// Which output the settings window lives on. Resolved once when it opens
// (never bound, so output churn does not move a mapped window), and re-homed
// to the first output only after the outputs settle without its own.

function indexIn(screens, screen) {
    if (!screens || !screen)
        return -1;
    for (let i = 0; i < screens.length; i++) {
        if (screens[i] === screen)
            return i;
    }
    return -1;
}

// The output named `name`, else null (the compositor places the window).
function byName(screens, name) {
    if (!screens || !name)
        return null;
    for (let i = 0; i < screens.length; i++) {
        if (screens[i] && screens[i].name === name)
            return screens[i];
    }
    return null;
}

// Where to move a window currently on `current` once `screens` settled:
// null when it can stay (still there, or no output at all).
function rehomeTarget(screens, current) {
    if (!screens || screens.length === 0)
        return null;
    if (current && indexIn(screens, current) >= 0)
        return null;
    return screens[0];
}
