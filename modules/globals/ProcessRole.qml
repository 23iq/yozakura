pragma Singleton
import QtQuick
import Quickshell
import "BrandActions.js" as BrandActions

// Which Quickshell instance this is. The main shell (shell.qml) is
// "shell"; with performance.separateWindows the Settings window and the
// setup wizard run as their own instances (settings-window.qml,
// onboarding-window.qml), started by the daemon (backend/pkg/svc/windows)
// with <PREFIX>ROLE=settings|onboarding before anything loads.
//
// Only the main shell may claim what is session-wide or duplicate its
// work: the notification server, the tray host, global shortcuts and the
// `ui` command stream, the IPC pipe, the session lock, idle monitoring and
// hooks, compositor config writes, wallpaper windows, the polkit agent,
// timers and alarms, the clipboard watcher, update checks, usage writes,
// the freeze-watchdog heartbeat. Those check `primary` (one switch per
// service, at construction). A new session-wide service does the same:
//     if (!ProcessRole.primary) return;   // or running: ProcessRole.primary && ...
//
// The dry-run wizard (onboarding-dryrun.qml, DryRun) keeps its own
// sandbox and is not a role here.
Singleton {
    id: root

    // What the environment says. Trusted only in the matching window entry
    // file (its ShellId pragma, <app>-settings / <app>-onboarding): the
    // variable is inherited by whatever a window launches, and a main
    // shell.qml started from such an environment (a terminal opened from
    // Settings) must stay the main shell.
    readonly property string _claimed: {
        const r = String(Quickshell.env(BrandActions.envPrefix + "ROLE") || "");
        return r === "settings" || r === "onboarding" ? r : "";
    }
    readonly property string role: root._claimed !== "" && Quickshell.shellId === BrandActions.appId + "-" + root._claimed ? root._claimed : "shell"
    // The main shell: owns the session-wide services.
    readonly property bool primary: root.role === "shell"
    // A separate window process (Settings or the setup wizard).
    readonly property bool secondary: !root.primary
    readonly property bool settings: root.role === "settings"
    readonly property bool wizard: root.role === "onboarding"

    // Where the daemon asked the window to open (<PREFIX>WINDOW_*).
    readonly property string initialPage: root.secondary ? String(Quickshell.env(BrandActions.envPrefix + "WINDOW_PAGE") || "") : ""
    readonly property string initialScreen: root.secondary ? String(Quickshell.env(BrandActions.envPrefix + "WINDOW_SCREEN") || "") : ""
    readonly property int initialWorkspace: root.secondary ? (parseInt(Quickshell.env(BrandActions.envPrefix + "WINDOW_WORKSPACE") || "0") || 0) : 0

    // The variables the daemon sets for a window process only.
    readonly property var windowVars: ["ROLE", "WINDOW_PAGE", "WINDOW_SCREEN", "WINDOW_WORKSPACE"].map(n => BrandActions.envPrefix + n)

    // What Quickshell.execDetached gets for argv: in a window process the
    // program is started without the window variables (null removes one),
    // so nothing it starts in turn comes up as a window. Argv only.
    function detached(argv) {
        if (root.primary)
            return argv;
        const env = {};
        root.windowVars.forEach(n => env[n] = null);
        return {
            "command": argv,
            "environment": env
        };
    }
}
