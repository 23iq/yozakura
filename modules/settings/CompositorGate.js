.pragma library

// Which compositors an entry / section is shown on. `spec` is one name
// ("hyprland") or a list (["hyprland", "mango"]); no spec = every compositor.
// A single name keeps the strict behaviour (hidden until the compositor is
// known); a list also shows while the name is still being probed, so a page
// does not flash empty.
function allows(spec, name) {
    if (!spec || (Array.isArray(spec) && spec.length === 0))
        return true;
    if (Array.isArray(spec))
        return !name || spec.indexOf(name) !== -1;
    return name === spec;
}
