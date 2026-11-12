.pragma library

// Exactly one PomodoroSync (one per bar clock, so one per screen and bar
// layout) owns the `pomodoro` IPC target and the Spotify sync: the first
// alive one, in creation order. A library script is one instance for the
// whole engine, so every PomodoroSync shares this list.

const syncs = [];

// claim registers a PomodoroSync; it owns if it is the only one.
function claim(sync) {
    if (syncs.indexOf(sync) >= 0)
        return;
    syncs.push(sync);
    sync.owner = syncs.length === 1;
}

// release drops a PomodoroSync (destroyed); the next one takes over.
function release(sync) {
    const i = syncs.indexOf(sync);
    if (i < 0)
        return;
    syncs.splice(i, 1);
    sync.owner = false;
    if (i === 0 && syncs.length > 0)
        syncs[0].owner = true;
}

function count() {
    return syncs.length;
}
