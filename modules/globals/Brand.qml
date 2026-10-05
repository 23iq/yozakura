pragma Singleton
import QtQuick
import Quickshell
import "BrandActions.js" as BrandActions

// Single source of truth for the app identity on the QML side (values come
// from BrandActions.js, shared with the JS libraries).
Singleton {
    readonly property string appId: BrandActions.appId
    readonly property string displayName: BrandActions.displayName
    readonly property string legacyAppId: BrandActions.legacyAppId
    readonly property string repoUrl: BrandActions.repoUrl
    readonly property string repoSlug: BrandActions.repoSlug
    // Compositor IPC daemon: its name, and the executable to run — the one
    // the backend resolved and exported (next to the yozakura binary first),
    // else the name on PATH.
    readonly property string daemon: BrandActions.daemon
    readonly property string daemonBin: Quickshell.env(BrandActions.daemonBinEnv) || BrandActions.daemon
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/" + appId
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/" + appId
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/" + appId
    // SDDM login theme (scripts/install-sddm-theme.sh) and its shared,
    // user-writable data dir (scripts/sddm-sync.sh writes theme.conf there).
    readonly property string sddmTheme: appId
    readonly property string sddmDataDir: "/var/lib/" + appId + "-sddm"
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + appId

    function namespace(suffix: string): string {
        return BrandActions.namespace(suffix);
    }

    // Process argv for a daemon command: daemonArgs(["monitor", "list"]).
    function daemonArgs(args: var): var {
        return [daemonBin].concat(args);
    }

    function action(name: string): string {
        return BrandActions.action(name);
    }

    // Path of a file directly in $XDG_RUNTIME_DIR named "<app><suffix>".
    function runtimeFile(suffix: string): string {
        return (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/" + appId + suffix;
    }
}
