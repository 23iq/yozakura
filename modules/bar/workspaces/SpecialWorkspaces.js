.pragma library

// Hyprland keeps the underlying normal workspace active while a special
// workspace is open, so read the monitor's specialWorkspace explicitly.
function namesFromMonitors(monitors) {
    const names = {};
    for (const monitor of monitors || []) {
        const workspace = monitor.specialWorkspace;
        if (!workspace || !(workspace.id < 0))
            continue;
        const name = String(workspace.name || "").replace(/^special:/, "");
        names[monitor.name] = name || "special";
    }
    return names;
}

// Whether a window's workspace is the one a monitor shows: its open
// special (named as namesFromMonitors() reports it) covers the active
// workspace, else the active workspace itself.
function isShown(workspace, activeId, specialName) {
    if (!workspace)
        return false;
    if (specialName) {
        if (!(workspace.id < 0))
            return false;
        const name = String(workspace.name || "").replace(/^special:/, "");
        return (name || "special") === specialName;
    }
    return workspace.id === activeId;
}
