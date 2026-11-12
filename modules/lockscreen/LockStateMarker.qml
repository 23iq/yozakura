pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "LockRestore.js" as LockRestore

// Keeps the lock across a shell restart (crash, freeze watchdog, reload).
// GlobalStates.lockscreenVisible is mirrored to a marker file in the runtime
// dir: written when the lock engages, removed when it is released (after a
// successful PAM unlock, or the IPC unlock). At startup an existing marker
// for this Wayland display locks again at once. Rules: LockRestore.js.
QtObject {
    id: root

    // "" disables the marker (no XDG_RUNTIME_DIR).
    property string path: LockRestore.markerPath(Quickshell.env("XDG_RUNTIME_DIR") || "", Brand.runtimeFile("-locked"))
    property string identity: LockRestore.identity(Quickshell.env("WAYLAND_DISPLAY") || "")

    readonly property bool locked: GlobalStates.lockscreenVisible
    // True when this shell started locked because of a marker.
    property bool restored: false
    // What the last finished marker operation left: present | absent | unknown.
    property string applied: "unknown"
    // The operation the writer runs ("write" | "remove") and its file.
    property string pendingOp: ""
    property string pendingPath: ""

    function restore() {
        if (root.path === "")
            return;
        if (!LockRestore.shouldRestore(root.reader.text(), root.identity))
            return;
        console.warn("LockStateMarker: the session was locked when the shell stopped; locking again");
        root.restored = true;
        GlobalStates.lockscreenVisible = true;
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

    onLockedChanged: sync()

    property FileView reader: FileView {
        path: root.path
        blockLoading: true
        printErrors: false
    }

    // One operation at a time, so a quick lock/unlock cannot end with the
    // remove finishing before the write.
    property Process writer: Process {
        onExited: (exitCode, exitStatus) => root.finished(exitCode)
    }

    Component.onCompleted: restore()
}
