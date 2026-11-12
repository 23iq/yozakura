import QtQuick
import qs.modules.globals
import qs.config
import "../settings/ConfigWrite.js" as ConfigWrite

// Main shell: applies what a separate Settings window stages (daemon
// `preview` relay, backend/pkg/svc/preview) to the in-memory Config with the
// same staging the window used in-process: the GlobalStates snapshot of the
// domain is taken and its auto-save paused before the first change, so the
// desktop previews the value and nothing of it is written here.
//   set     ConfigWrite.assign, staged like SettingsStore.set
//   discard the snapshots are restored (Discard, a closed or dead window)
//   commit  the window wrote the files: the snapshots are dropped without
//           restoring (the reload of those files brings the same values)
// Owned by SeparateWindows.qml, which subscribes it once the setting is on.
QtObject {
    id: root

    readonly property var shellDomains: GlobalStates._shellSections || {}

    // Only staged domains are relayed; anything else is refused (an
    // unstaged key would be written by this shell's auto-save).
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

    function commit() {
        GlobalStates.themeSnapshot = null;
        GlobalStates.themeHasChanges = false;
        GlobalStates.shellSnapshot = null;
        GlobalStates.shellHasChanges = false;
        GlobalStates.compositorSnapshot = null;
        GlobalStates.compositorHasChanges = false;
    }

    // A `preview` stream event.
    function handle(service, data) {
        if (service === "preview.set" && data && typeof data.key === "string")
            root.set(data.key, data.value);
        else if (service === "preview.discard")
            root.discard();
        else if (service === "preview.commit")
            root.commit();
    }
}
