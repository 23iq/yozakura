.pragma library

// Whether one config domain holds its adapter edits back instead of writing
// them to <domain>.json (tests/auto-save-pause.test.cjs).
//
// state: {
//   holds:      Config.autoSaveHolds (a service's bulk edit; pauses all),
//   theme, compositor, shell: GlobalStates.*HasChanges (staged settings),
//   shellDomains: GlobalStates._shellSections (the domains the shell
//                 snapshot stages, as SettingsStore.shellDomains)
// }
// A staged settings change pauses only the domains it stages: an edit to any
// other domain (keybinds, MCP bridge, desktop widgets, dashboard toggles) is
// written as usual, so it is not lost at the next restart.
function paused(name, state) {
    var s = state || {};
    if (s.holds > 0)
        return true;
    if (name === "theme")
        return !!s.theme;
    if (name === "compositor")
        return !!s.compositor;
    var shellDomains = s.shellDomains || {};
    return !!s.shell && Object.prototype.hasOwnProperty.call(shellDomains, name);
}
