.pragma library

// Which surface owner pre-creates the launcher view a few seconds after
// startup (HostedSurfaces / NotchHostedSurfaces): one view, on the screen
// the launcher will most likely open on, in the host the layout routes it to.
//
// screenNames  the screens in Quickshell order
// focused      the last focused screen name ("" before any focus event)
// Returns the screen name to warm on ("" when there is no screen).
function targetScreen(screenNames, focused) {
    const names = Array.isArray(screenNames) ? screenNames.filter(n => typeof n === "string" && n !== "") : [];
    if (focused && names.indexOf(focused) >= 0)
        return focused;
    return names.length > 0 ? names[0] : "";
}

// owner      "notch" (NotchHostedSurfaces) or "hosts" (HostedSurfaces)
// host       HostRouter.hostFor("launcher"): notch | spotlight | sheet
// screen     the owner's screen name
function shouldWarm(owner, host, screen, screenNames, focused) {
    if (!screen || !host)
        return false;
    const inNotch = host === "notch";
    if ((owner === "notch") !== inNotch)
        return false;
    return targetScreen(screenNames, focused) === screen;
}
