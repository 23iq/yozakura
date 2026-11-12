.pragma library

// Which config domains a staging (the GlobalStates snapshots) changed, and
// how each is written. A separate Settings / wizard window writes only
// these when no main shell writes for it (PreviewSink.applyOwn), so it
// never overwrites a domain it did not touch with its own, older copy.
// Tested in tests/staged-domains.test.cjs.

// gs: GlobalStates (themeHasChanges, compositorHasChanges, shellHasChanges,
// shellSnapshot, createShellSnapshot(), _shellSections).
function changed(gs) {
    var out = [];
    if (!gs)
        return out;
    if (gs.themeHasChanges)
        out.push("theme");
    if (gs.compositorHasChanges)
        out.push("compositor");
    if (gs.shellHasChanges) {
        var domains = Object.keys(gs._shellSections || {});
        var snap = gs.shellSnapshot;
        var now = snap ? gs.createShellSnapshot() : null;
        for (var i = 0; i < domains.length; i++) {
            var d = domains[i];
            // no snapshot to compare with: every staged domain
            if (!snap || JSON.stringify(now[d]) !== JSON.stringify(snap[d]))
                out.push(d);
        }
    }
    return out;
}

// Writes each domain the way GlobalStates.apply*Changes does: theme through
// the theme file's loader, every other one through Config.save<Domain>().
function write(config, domains) {
    for (var i = 0; i < domains.length; i++) {
        var d = domains[i];
        if (d === "theme") {
            if (config.loader && typeof config.loader.writeAdapter === "function")
                config.loader.writeAdapter();
            continue;
        }
        var save = config["save" + d.charAt(0).toUpperCase() + d.slice(1)];
        if (typeof save === "function")
            save();
    }
}
