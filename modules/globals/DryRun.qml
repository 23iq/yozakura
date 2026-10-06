pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "BrandActions.js" as BrandActions

// Dry-run mode of the setup wizard (`<app> onboarding --dry-run`, root file
// onboarding-dryrun.qml). The CLI runs a separate Quickshell with
// <PREFIX>DRYRUN=1, <PREFIX>DRYRUN_DIR=<temp dir> and the XDG config/cache/
// state dirs pointed at copies inside it. While active, BackendService
// answers mutating methods from DryRunBackend.js and every guarded action
// (theme generators, preset apply, compositor writes, ...) calls journal()
// instead of changing the system; the CLI prints <dir>/dryrun.log on exit.
// <PREFIX>DRYRUN_FAIL=id1,id2 makes those fake installs fail.
Singleton {
    id: root

    readonly property bool active: Quickshell.env(BrandActions.envPrefix + "DRYRUN") === "1"
    readonly property string dir: root.active ? (Quickshell.env(BrandActions.envPrefix + "DRYRUN_DIR") || "") : ""
    // The config dir really is the temp copy (writes there are harmless).
    readonly property bool sandboxed: root.dir !== "" && String(Quickshell.env("XDG_CONFIG_HOME") || "").indexOf(root.dir + "/") === 0
    readonly property var failIds: String(Quickshell.env(BrandActions.envPrefix + "DRYRUN_FAIL") || "").split(",").map(s => s.trim()).filter(s => s !== "")
    readonly property string journalFile: root.dir !== "" ? root.dir + "/dryrun.log" : ""

    // Journal lines so far (one per intercepted action)
    property var lines: []

    function journal(line) {
        if (!root.active || !line)
            return;
        if (root.lines.length > 0 && root.lines[root.lines.length - 1] === line)
            return;
        root.lines = root.lines.concat([String(line)]);
        console.info("[dry-run]", line);
        if (root.journalFile !== "")
            journalView.setText(root.lines.join("\n") + "\n");
    }

    property FileView journalView: FileView {
        path: root.journalFile
        printErrors: false
    }
}
