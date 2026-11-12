pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "LockRestore.js" as LockRestore

// Keeps the lock across a shell restart (crash, freeze watchdog, reload).
// GlobalStates.lockscreenVisible is mirrored to a marker file in the runtime
// dir (one per display): written when the lock engages, removed when it is
// released (after a successful PAM unlock, or the IPC unlock). At startup a
// marker written by this compositor instance locks again at once; one left
// by another instance is removed. Rules: LockRestore.js.
QtObject {
    id: root

    readonly property string display: Quickshell.env("WAYLAND_DISPLAY") || ""
    readonly property string token: LockRestore.sessionToken({
        "HYPRLAND_INSTANCE_SIGNATURE": Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "",
        "NIRI_SOCKET": Quickshell.env("NIRI_SOCKET") || "",
        "XDG_SESSION_ID": Quickshell.env("XDG_SESSION_ID") || ""
    })
    readonly property string suffix: LockRestore.fileSuffix(root.display)
    // "" disables the marker (no XDG_RUNTIME_DIR, display or instance token).
    property string path: root.suffix === "" ? "" : LockRestore.markerPath(Quickshell.env("XDG_RUNTIME_DIR") || "", Brand.runtimeFile(root.suffix), root.token)
    property string identity: LockRestore.identity(root.display, root.token)

    readonly property bool locked: GlobalStates.lockscreenVisible
    // True when this shell started locked because of a marker.
    property bool restored: false
    // The startup decision is taken (from the marker, its absence, or a
    // lock/unlock by the user before the marker was read): later reads of
    // the file never lock.
    property bool decided: false
    // What the last finished marker operation left: present | absent | unknown.
    property string applied: "unknown"
    // The operation the writer runs ("write" | "remove") and its file.
    property string pendingOp: ""
    property string pendingPath: ""

    // The marker's content as read at startup. Called on completion (the
    // FileView loads synchronously with blockLoading) and again when the
    // content arrives later (loaded); an empty first read waits for that.
    function consider(text: string, settled: bool) {
        if (root.decided || root.path === "")
            return;
        if (text.trim() === "" && !settled)
            return;
        root.decided = true;
        if (LockRestore.shouldRestore(text, root.identity)) {
            console.warn("LockStateMarker: the session was locked when the shell stopped; locking again");
            root.restored = true;
            GlobalStates.lockscreenVisible = true;
        } else if (LockRestore.isStale(text, root.identity)) {
            console.warn("LockStateMarker: removing a lock marker left by another session");
            root.sync();
        }
    }

    function sync() {
        if (root.path === "" || root.writer.running)
            return;
        const op = LockRestore.nextOp(root.locked, root.applied);
        if (op === "")
            return;
        root.pendingOp = op;
        root.pendingPath = root.path;
        root.writer.command = op === "write" ? ["sh", "-c", 'umask 077 && printf "%s\\n" "$2" > "$1"', "lock-marker", root.path, root.identity] : ["rm", "-f", "--", root.path];
        root.writer.running = true;
    }

    function finished(exitCode: int) {
        const wrote = root.pendingOp === "write";
        if (exitCode === 0) {
            root.applied = wrote ? "present" : "absent";
        } else {
            root.applied = "unknown";
            console.error("LockStateMarker: could not " + root.pendingOp + " the lock marker " + root.pendingPath + " (exit " + exitCode + "); " + (wrote ? "a shell restart while locked will not lock again" : "a shell restart may lock the session again"));
        }
        // Follow a state change made while this ran; a failure with the
        // state unchanged is not retried in a loop.
        if (wrote !== root.locked)
            Qt.callLater(root.sync);
    }

    // A lock or unlock before the marker was read wins: the marker is never
    // acted on afterwards (no re-lock after a deliberate unlock).
    onLockedChanged: {
        root.decided = true;
        sync();
    }

    property FileView reader: FileView {
        path: root.path
        blockLoading: true
        printErrors: false
        onLoaded: root.consider(root.reader.text(), true)
        // Missing or unreadable: no marker.
        onLoadFailed: root.consider("", true)
    }

    // One operation at a time, so a quick lock/unlock cannot end with the
    // remove finishing before the write.
    property Process writer: Process {
        onExited: (exitCode, exitStatus) => root.finished(exitCode)
    }

    Component.onCompleted: root.consider(root.reader.text(), false)
}
