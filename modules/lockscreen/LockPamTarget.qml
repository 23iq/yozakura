pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "LockPam.js" as LockPam

// The PAM stack for the next authentication (rules: LockPam.js). The
// bundled config unless lockscreen.pamService names a service whose
// /etc/pam.d file exists; the existence check runs when the setting
// changes, before any password is typed.
QtObject {
    id: root

    // lockscreen.pamService ("" = bundled)
    property string service: ""
    // Directory of the bundled password.conf
    required property string bundledDir

    readonly property string path: LockPam.servicePath(root.service)
    // The service file the last finished check looked at, and its result.
    property string checkedPath: ""
    property bool exists: false
    // The service file the running check looks at.
    property string checkingPath: ""

    // A result only counts for the path it was taken for (LockPam.target),
    // so the previous one can stand until the new check finishes.
    function refresh() {
        if (root.service.trim() !== "" && root.path === "")
            console.warn("LockScreen: lockscreen.pamService is not a plain PAM service name; using the bundled config");
        if (root.path === "" || root.check.running)
            return;
        root.checkingPath = root.path;
        root.check.command = ["test", "-f", root.path];
        root.check.running = true;
    }

    // {configDirectory, config, system} for PamContext, read at submit.
    function resolve() {
        const t = LockPam.target(root.service, root.checkedPath, root.exists, root.bundledDir);
        if (root.path !== "" && !t.system)
            console.warn("LockScreen: PAM service " + root.path + " not found (or not checked yet); using the bundled config");
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
        root.exists = exitCode === 0;
    }

    property Process check: Process {
        onExited: (exitCode, exitStatus) => root.checked(exitCode)
    }
}
