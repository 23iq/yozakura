pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "LockPam.js" as LockPam

// The PAM stack for the next authentication (rules: LockPam.js). The
// bundled config unless lockscreen.pamService names a service whose
// /etc/pam.d file is a usable password stack (readable, not an autologin
// stack, no `auth ... pam_permit.so`); the check runs when the setting
// changes, before any password is typed, and again after a failed attempt.
QtObject {
    id: root

    // lockscreen.pamService ("" = bundled)
    property string service: ""
    // Directory of the bundled password.conf
    required property string bundledDir

    readonly property string path: LockPam.servicePath(root.service)
    // The service file the last finished check looked at, and its verdict
    // (LockPam.checkResult: "usable" | "permit" | "unreadable").
    property string checkedPath: ""
    property string verdict: ""
    // The service file the running check looks at.
    property string checkingPath: ""

    // A result only counts for the path it was taken for (LockPam.target),
    // so the previous one can stand until the new check finishes.
    function refresh() {
        if (root.path === "") {
            // Unset, not a plain name, or refused by name (autologin).
            const why = LockPam.warning(root.service, root.checkedPath, root.verdict);
            if (why !== "")
                console.warn("LockScreen: " + why);
            return;
        }
        if (root.check.running)
            return;
        root.checkingPath = root.path;
        root.check.command = LockPam.checkCommand(root.path);
        root.check.running = true;
    }

    // {configDirectory, config, system} for PamContext, read at submit.
    function resolve() {
        const t = LockPam.target(root.service, root.checkedPath, root.verdict, root.bundledDir);
        if (!t.system) {
            const why = LockPam.warning(root.service, root.checkedPath, root.verdict);
            if (why !== "")
                console.warn("LockScreen: " + why);
        }
        return t;
    }

    onPathChanged: refresh()
    Component.onCompleted: refresh()

    function checked(exitCode: int) {
        if (root.checkingPath !== root.path) {
            // The setting changed while this ran: check the new one.
            Qt.callLater(root.refresh);
            return;
        }
        root.checkedPath = root.checkingPath;
        root.verdict = LockPam.checkResult(exitCode);
        if (root.verdict !== "usable")
            console.warn("LockScreen: " + LockPam.warning(root.service, root.checkedPath, root.verdict));
    }

    property Process check: Process {
        onExited: (exitCode, exitStatus) => root.checked(exitCode)
    }
}
