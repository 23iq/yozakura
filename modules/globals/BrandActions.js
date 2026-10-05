.pragma library

// App identity for JS libraries (QML code uses the Brand singleton, which
// reads these values). The legacy id names the project this one was forked
// from and is only used for backwards compatibility.
var appId = "yozakura";
var displayName = "Yozakura";
var legacyAppId = "ambxst";
var legacyDisplayName = "Ambxst";
var repoUrl = "https://github.com/23iq/yozakura";
var repoSlug = "23iq/yozakura";
// Compositor IPC daemon binary (mirrors backend/pkg/brand.Daemon). The
// legacy daemon is the external one it replaced; only old bind command
// lines still name it.
var daemon = "yozd";
var legacyDaemon = "axctl";
// Env var through which the backend exports the resolved daemon executable.
var daemonBinEnv = appId.toUpperCase() + "_DAEMON_BIN";

// Keybind/IPC action id: "<app>.<name>".
function action(name) {
    return appId + "." + name;
}

// Layer-shell namespace: "<app>" or "<app>:<suffix>".
function namespace(suffix) {
    return suffix ? appId + ":" + suffix : appId;
}

// Shell command line invoking the CLI: command("run", "launcher").
function command() {
    return [appId].concat(Array.prototype.slice.call(arguments)).join(" ");
}

// Shell command line invoking the daemon CLI: daemonCommand("monitor", "list").
function daemonCommand() {
    return [daemon].concat(Array.prototype.slice.call(arguments)).join(" ");
}

// Maps a legacy action id ("<legacy>.<name>") to the current one; any other
// id is returned unchanged. Old binds.json files keep dispatching.
function normalizeAction(id) {
    const prefix = legacyAppId + ".";
    if (typeof id === "string" && id.indexOf(prefix) === 0)
        return action(id.substring(prefix.length));
    return id;
}
