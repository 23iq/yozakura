.pragma library

// Lock state that survives the shell (LockStateMarker.qml).
//
// While the session is locked a small marker file sits in
// $XDG_RUNTIME_DIR (tmpfs, removed by logind at logout, gone at reboot). If
// the shell dies while locked the compositor keeps the session locked
// (ext-session-lock); the restarted shell finds the marker and locks again.
// The marker names the Wayland display it was written for, so another
// session of the same user sharing the runtime dir is never locked by it.

var PREFIX = "locked display=";

// Marker path: only under a real XDG_RUNTIME_DIR. Without one the shell
// would fall back to /tmp, which outlives the login and is shared.
function markerPath(runtimeDir, runtimeFile) {
    if (typeof runtimeDir !== "string" || runtimeDir === "")
        return "";
    return typeof runtimeFile === "string" ? runtimeFile : "";
}

// Content written while locked.
function identity(waylandDisplay) {
    return PREFIX + (typeof waylandDisplay === "string" ? waylandDisplay : "");
}

// True when a marker read at startup asks to lock this session again.
// `text` is the file's content ("" when it does not exist).
function shouldRestore(text, currentIdentity) {
    if (typeof text !== "string" || typeof currentIdentity !== "string")
        return false;
    var content = text.trim();
    return content !== "" && content.indexOf(PREFIX) === 0 && content === currentIdentity.trim();
}

// Next marker operation, or "" when nothing is to be done. `locked` is the
// wanted state; `applied` what the last finished operation left on disk
// ("present" | "absent" | "unknown": never touched, or the last operation
// failed). An unknown state is written/removed again, so an unlock removes
// the marker even when writing it had failed.
function nextOp(locked, applied) {
    if (locked)
        return applied === "present" ? "" : "write";
    return applied === "absent" ? "" : "remove";
}
