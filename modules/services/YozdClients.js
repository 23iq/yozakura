.pragma library

// Identity-preserving client list for YozdService (pure logic).
//
// compositor.state carries every window on every event (a terminal title
// spinner sends several per second). Rebuilding all client objects each time
// hands every binding that reads clients.values or focusedClient fresh
// objects and re-runs it. merge() maps yozd windows to Hyprland-style client
// objects and reuses the previous object of a client whose fields did not
// change, so unchanged clients keep their identity and an unchanged list is
// reported as such (the caller then skips the assignment).

function _num(v) {
    return parseInt(v) || 0;
}

// Maps one yozd window; focusHistoryID orders clients by most recent focus
// (lower = more recent), counter is the next id source (decremented).
function mapWindow(win, existing, counter) {
    const md = win.metadata || null;
    const prevFocus = existing && existing.focusHistoryID !== undefined ? existing.focusHistoryID : 999999;
    let focus = prevFocus;
    if (win.is_focused && !(existing && existing.is_focused))
        focus = --counter;
    return {
        client: {
            address: win.id,
            class: win.app_id,
            title: win.title,
            workspace: {
                id: _num(win.workspace_id),
                name: win.workspace_id
            },
            monitor: _num(md ? md.monitor_id : 0),
            floating: win.is_floating,
            fullscreen: win.is_fullscreen,
            hidden: win.is_hidden,
            mapped: true,
            at: [md ? (md.x || 0) : 0, md ? (md.y || 0) : 0],
            size: [md ? (md.width || 0) : 0, md ? (md.height || 0) : 0],
            xwayland: (md ? md.xwayland : false) || false,
            is_focused: win.is_focused || false,
            urgent: !!(md && md.is_urgent),
            focusHistoryID: focus
        },
        counter: counter
    };
}

function sameClient(a, b) {
    if (!a || !b)
        return a === b;
    return a.address === b.address && a.class === b.class && a.title === b.title
        && a.workspace.id === b.workspace.id && a.workspace.name === b.workspace.name
        && a.monitor === b.monitor && a.floating === b.floating && a.fullscreen === b.fullscreen
        && a.hidden === b.hidden && a.mapped === b.mapped
        && a.at[0] === b.at[0] && a.at[1] === b.at[1]
        && a.size[0] === b.size[0] && a.size[1] === b.size[1]
        && a.xwayland === b.xwayland && a.is_focused === b.is_focused
        && a.urgent === b.urgent && a.focusHistoryID === b.focusHistoryID;
}

// Returns {values, changed, counter}. values reuses prev's objects for
// unchanged clients; changed is false when values matches prev element for
// element (same objects, same order), in which case values === prev.
function merge(prev, windows, counter) {
    prev = prev || [];
    const byAddress = {};
    for (let i = 0; i < prev.length; i++)
        byAddress[prev[i].address] = prev[i];
    const values = [];
    let changed = prev.length !== windows.length;
    for (let i = 0; i < windows.length; i++) {
        const existing = byAddress[windows[i].id];
        const m = mapWindow(windows[i], existing, counter);
        counter = m.counter;
        const client = sameClient(existing, m.client) ? existing : m.client;
        if (client !== prev[i])
            changed = true;
        values.push(client);
    }
    return {
        values: changed ? values : prev,
        changed: changed,
        counter: counter
    };
}

// The client focusedClient should point at: the focused one; while no
// window has focus (a layer surface such as the launcher took it) the
// previous focused client stays, refreshed to its current object.
function pickFocused(values, prev) {
    for (let i = 0; i < values.length; i++) {
        if (values[i].is_focused)
            return values[i];
    }
    const addr = prev ? prev.address : undefined;
    for (let i = 0; i < values.length; i++) {
        if (values[i].address === addr)
            return values[i];
    }
    return null;
}
