pragma Singleton
import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.config
import "../settings/ConfigWrite.js" as ConfigWrite

// performance.separateWindows: the one staging of Settings and the setup
// wizard, shared between processes through the daemon's `preview` relay
// (backend/pkg/svc/preview). In-process there is one Config and one set of
// GlobalStates snapshots: what either window stages is the same unsaved
// changes, Apply anywhere writes all of it, Discard anywhere restores all of
// it. Here every process applies what another one staged with that same
// staging (the snapshot of the domain is taken and its auto-save paused
// before the first change), so the desktop previews it, every window shows
// it as unsaved and nothing of it is written:
//   set     ConfigWrite.assign, staged like SettingsStore.set
//   discard the snapshots are restored (Discard, the last window gone)
//   commit  the snapshots are dropped without restoring (the files hold
//           the values)
// Events of this process's own owner (its echo) are ignored. The main shell
// links it from SeparateWindows once the setting is on; a window process
// links it from its entry file. Events wait until this process has read
// its config (a replay arrives on subscribe).
Singleton {
    id: root

    // This process as an owner: "" in the main shell, the window's kind in
    // a window process.
    readonly property string self: ProcessRole.primary ? "" : ProcessRole.role
    readonly property var shellDomains: GlobalStates._shellSections || {}

    property bool _linked: false
    function link() {
        if (root._linked)
            return;
        root._linked = true;
        BackendService.addSubscription(["preview"], (service, data) => root.handle(service, data));
    }

    // Only staged domains are relayed; anything else is refused (an
    // unstaged key would be written by this process's auto-save).
    function isStaged(domain) {
        return domain === "theme" || domain === "compositor" || Object.prototype.hasOwnProperty.call(root.shellDomains, domain);
    }

    function stage(domain) {
        if (domain === "theme")
            GlobalStates.markThemeChanged();
        else if (domain === "compositor")
            GlobalStates.markCompositorChanged();
        else
            GlobalStates.markShellChanged();
    }

    function set(key, value) {
        const domain = ConfigWrite.splitKey(key).domain;
        if (!root.isStaged(domain) || !Config[domain])
            return false;
        if (ConfigWrite.equal(ConfigWrite.getPath(Config[domain], ConfigWrite.splitKey(key).path), value))
            return true;
        return ConfigWrite.assign(Config, key, value, root.stage) !== "";
    }

    function discard() {
        GlobalStates.discardThemeChanges();
        GlobalStates.discardShellChanges();
        GlobalStates.discardCompositorChanges();
    }

    // The staging ends without restoring: the values stay (they are written).
    function drop() {
        GlobalStates.themeSnapshot = null;
        GlobalStates.themeHasChanges = false;
        GlobalStates.shellSnapshot = null;
        GlobalStates.shellHasChanges = false;
        GlobalStates.compositorSnapshot = null;
        GlobalStates.compositorHasChanges = false;
    }

    property var _waiting: []
    readonly property bool _ready: Config.initialLoadComplete === true
    on_ReadyChanged: {
        if (!root._ready)
            return;
        const queued = root._waiting;
        root._waiting = [];
        queued.forEach(e => root.handle(e.service, e.data));
    }

    // A `preview` stream event.
    function handle(service, data) {
        if (!root._ready) {
            root._waiting = root._waiting.concat([
                {
                    "service": service,
                    "data": data
                }
            ]);
            return;
        }
        const owner = data && typeof data.owner === "string" ? data.owner : "";
        if (root.self !== "" && owner === root.self)
            return;
        if (service === "preview.set" && data && typeof data.key === "string")
            root.set(data.key, data.value);
        else if (service === "preview.discard")
            root.discard();
        else if (service === "preview.commit")
            root.drop();
    }
}
