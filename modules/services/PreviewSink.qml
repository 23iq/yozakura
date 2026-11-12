pragma Singleton
import QtQuick
import Quickshell
import qs.modules.globals
import qs.modules.services
import qs.config
import "../settings/ConfigWrite.js" as ConfigWrite
import "../settings/StagedDomains.js" as StagedDomains

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
//   commit  the main shell writes the files (apply*Changes, as Apply does
//           in-process: its Config holds every staged value and what the
//           desktop changed meanwhile, widget positions, dashboard cells)
//           and answers preview.written; a window drops its snapshots
//           without restoring (it follows the written files)
// Events of this process's own owner (its echo) are ignored. A window's
// own Apply (applyOwn) leaves the writing to the main shell and writes the
// domains it changed itself only when no main shell answers. The main shell
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

    // The main shell: a window applied, the files are written here. The
    // commit carries every staged entry (`staged`): a preview.set the stream
    // dropped is applied now, before writing.
    function write(id, staged) {
        (Array.isArray(staged) ? staged : []).forEach(e => {
            if (e && typeof e.key === "string")
                root.set(e.key, e.value);
        });
        GlobalStates.applyThemeChanges();
        GlobalStates.applyShellChanges();
        GlobalStates.applyCompositorChanges();
        if (id)
            BackendService.call("preview.written", {
                "id": id
            });
    }

    // ---- a window's own Apply / Discard (SettingsStore) ----
    // How long a window's Apply waits for the daemon's answer (which itself
    // waits up to 2 s for the main shell) before writing itself.
    readonly property int answerTimeout: 4000
    // Applies waiting for their answer: {domains, until}.
    property var _applying: []
    // An Apply is waiting for its answer (the window process does not quit).
    readonly property bool applying: root._applying.length > 0

    function applyOwn() {
        if (!GlobalStates.themeHasChanges && !GlobalStates.shellHasChanges && !GlobalStates.compositorHasChanges)
            return;
        const domains = StagedDomains.changed(GlobalStates);
        root.drop();
        if (!BackendService.socketAvailable) {
            StagedDomains.write(Config, domains);
            return;
        }
        const entry = {
            "domains": domains,
            "until": Date.now() + root.answerTimeout
        };
        root._applying = root._applying.concat([entry]);
        applyGuard.start();
        BackendService.call("preview.commit", {
            "owner": root.self
        }, (result, error) => root._answered(entry, !error && !!result && result.written === true));
    }

    // Written by the main shell, or (no answer, no main shell) here: only
    // the domains this window changed, never its older copy of the others,
    // and of those only its own changes laid over the file as it is now
    // (StagedDomains.write: ConfigFile.writeMerged), never its older copy
    // of what the main shell changed meanwhile (desktop widget positions).
    function _answered(entry, written) {
        if (root._applying.indexOf(entry) === -1)
            return;
        root._applying = root._applying.filter(e => e !== entry);
        if (!written)
            StagedDomains.write(Config, entry.domains);
    }

    property Timer applyGuard: Timer {
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now();
            root._applying.filter(e => e.until <= now).forEach(e => root._answered(e, false));
            if (root._applying.length === 0)
                stop();
        }
    }

    function discardOwn() {
        const had = GlobalStates.themeHasChanges || GlobalStates.shellHasChanges || GlobalStates.compositorHasChanges;
        root.discard();
        if (had)
            BackendService.call("preview.discard", {
                "owner": root.self
            });
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
        else if (service === "preview.commit" && root.self === "")
            root.write(data && data.id ? data.id : 0, data ? data.staged : null);
        else if (service === "preview.commit")
            root.drop();
    }
}
