.pragma library

// Which workspaces want attention. yozd reports urgency per window on niri
// (metadata.is_urgent) and per tag on MangoWC (workspace metadata.urgent);
// Hyprland only sends "urgent>>ADDRESS" events, tracked as a set of window
// addresses until that window is focused or closed.

// Hyprland addresses come with "0x" in yozd state and without it in events.
function address(a) {
    return String(a || "").toLowerCase().replace(/^0x/, "");
}

// Hyprland event -> the next set of urgent addresses ({addr: true}).
function onEvent(addresses, name, data) {
    var out = {};
    for (var k in addresses)
        out[k] = true;
    if (name === "urgent")
        out[address(data)] = true;
    else if (name === "activewindowv2" || name === "closewindow")
        delete out[address(String(data || "").split(",")[0])];
    return out;
}

// {workspaceId: true} for each workspace with an urgent window or tag
// (urgentIds: workspace ids with an urgent tag).
function map(windows, urgentIds, addresses) {
    var out = {};
    var wins = windows || [];
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && w.workspace && (w.urgent || (addresses && addresses[address(w.address)])))
            out[w.workspace.id] = true;
    }
    var ids = urgentIds || [];
    for (var j = 0; j < ids.length; j++)
        out[ids[j]] = true;
    return out;
}
