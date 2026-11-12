.pragma library

// Lock state that survives the shell (LockStateMarker.qml).
//
// While the session is locked a small marker file sits in
// $XDG_RUNTIME_DIR. If the shell dies while locked the compositor keeps the
// session locked (ext-session-lock); the restarted shell finds the marker
// and locks again.
//
// $XDG_RUNTIME_DIR is per user, not per login: it survives while another
// session of the user exists, during logind's stop delay, and for good with
// linger, and Wayland display names are reused. So the marker is one file
// per display, and its content names the compositor instance it was written
// in; a marker of another instance (a previous login on the same display)
// is ignored and removed. The instance token (sessionToken), first found of:
// - HYPRLAND_INSTANCE_SIGNATURE: new for every Hyprland start;
// - NIRI_SOCKET: niri.<display>.<pid>.sock, the compositor's pid;
// - XDG_SESSION_ID: the logind session (other compositors).
// The shell inherits all of them from the compositor, so a shell restarted
// inside the same session sees the same token and a re-login a new one.
// Without any of them the marker is off (no restore), as before it existed.

var PREFIX = "locked display=";

// The compositor instance token from the environment ({name: value});
// "" when none is known.
function sessionToken(env) {
    var e = env || {};
    var pick = function (name, tag) {
        var v = e[name];
        return typeof v === "string" && v.trim() !== "" ? tag + ":" + v.trim() : "";
    };
    return pick("HYPRLAND_INSTANCE_SIGNATURE", "hyprland") || pick("NIRI_SOCKET", "niri") || pick("XDG_SESSION_ID", "logind");
}

// Marker file suffix for a display ("-locked-wayland-1"); "" without one.
// Characters outside [A-Za-z0-9._-] (WAYLAND_DISPLAY may be a path) become
// "_".
function fileSuffix(waylandDisplay) {
    if (typeof waylandDisplay !== "string" || waylandDisplay === "")
        return "";
    return "-locked-" + waylandDisplay.replace(/[^A-Za-z0-9._-]/g, "_");
}

// Marker path: only under a real XDG_RUNTIME_DIR (without one the shell
// would fall back to /tmp, which outlives the login and is shared), and only
// with a display and an instance token to tell sessions apart.
function markerPath(runtimeDir, runtimeFile, token) {
    if (typeof runtimeDir !== "string" || runtimeDir === "")
        return "";
    if (typeof token !== "string" || token === "")
        return "";
    return typeof runtimeFile === "string" ? runtimeFile : "";
}

// Content written while locked.
function identity(waylandDisplay, token) {
    return PREFIX + (typeof waylandDisplay === "string" ? waylandDisplay : "") + " session=" + (typeof token === "string" ? token : "");
}

// True when a marker read at startup asks to lock this session again.
// `text` is the file's content ("" when it does not exist).
function shouldRestore(text, currentIdentity) {
    if (typeof text !== "string" || typeof currentIdentity !== "string")
        return false;
    var content = text.trim();
    return content !== "" && content.indexOf(PREFIX) === 0 && content === currentIdentity.trim();
}

// True when a marker read at startup is left over from another session (or
// unreadable garbage): it is removed.
function isStale(text, currentIdentity) {
    return typeof text === "string" && text.trim() !== "" && !shouldRestore(text, currentIdentity);
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
