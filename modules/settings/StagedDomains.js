.pragma library

// Which config domains a staging (the GlobalStates snapshots) changed, and
// how each is written. A separate Settings / wizard window writes only
// these when no main shell writes for it (PreviewSink.applyOwn), so it
// never overwrites a domain it did not touch with its own, older copy,
// and of a domain it did touch only its own changes (write).
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

// Writes each domain with only what this process changed laid over the
// file as it is now (ConfigFile.writeMerged): the main shell may have
// written the domain meanwhile (a desktop widget moved), and this window's
// copy of the rest of it is older. A config without merged writes, or a
// domain file not loaded: the whole domain, the way
// GlobalStates.apply*Changes does (theme through its loader, every other
// one through Config.save<Domain>()).
function write(config, domains) {
    for (var i = 0; i < domains.length; i++) {
        var d = domains[i];
        var file = typeof config.configFile === "function" ? config.configFile(d) : null;
        if (file && typeof file.writeMerged === "function" && file.writeMerged())
            continue;
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
