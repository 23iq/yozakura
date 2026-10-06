pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.config
import "../theme/AppThemes.js" as AppThemes

// Connects third-party apps (kitty, Ghostty, Foot, Alacritty, Vesktop, Qt) to
// the theme files the shell generates, through the backend `apphooks` service.
// `status` maps an app id to {state, reason, files, needsRestart} with state
// one of connected | disconnected | absent | managed | error. Apps whose
// apps.theming.<id> toggle is on get connected once after the config loads
// (the shell's deferred 2 s timer instantiates this singleton) and whenever
// the toggles change; switching one off reverts its hook.
Singleton {
    id: root

    property var status: ({})
    // Set by tests; the shell leaves it at 0 (it already defers 2 s)
    property int startDelay: 0
    property bool started: false

    // apps.theming ids that are switched on
    readonly property var enabledIds: Config.initialLoadComplete ? AppThemes.ids().filter(id => AppThemes.enabled(Config.apps ? Config.apps.theming : null, id)) : []
    readonly property string enabledKey: root.enabledIds.join(",")
    property var _seen: []

    function stateOf(id) {
        const st = root.status[id];
        return st ? st.state : "";
    }

    function _merge(map) {
        const next = Object.assign({}, root.status);
        for (const id in map)
            next[id] = map[id];
        root.status = next;
    }

    function refresh() {
        BackendService.call("apphooks.status", {}, (result, error) => {
            if (error || !result) {
                console.warn("AppHooksService: status failed", JSON.stringify(error));
                return;
            }
            root.status = result;
        });
    }

    // Connect every enabled app that is not connected yet (backend skips
    // absent, managed and failing ones)
    function ensureEnabled() {
        BackendService.call("apphooks.ensure", {
            "ids": root.enabledIds
        }, (result, error) => {
            if (error || !result) {
                console.warn("AppHooksService: ensure failed", JSON.stringify(error));
                return;
            }
            root._merge(result);
        });
    }

    function _one(method, id) {
        BackendService.call("apphooks." + method, {
            "id": id
        }, (result, error) => {
            if (error || !result) {
                console.warn("AppHooksService: " + method + " failed", JSON.stringify(error));
                return;
            }
            const m = {};
            m[id] = result;
            root._merge(m);
        });
    }

    function connectApp(id) {
        root._one("apply", id);
    }

    function revert(id) {
        root._one("revert", id);
    }

    function _togglesChanged() {
        const now = root.enabledIds;
        for (const id of root._seen) {
            if (now.indexOf(id) < 0)
                root.revert(id); // idempotent; the backend ignores apps without a hook
        }
        root._seen = now;
        root.ensureEnabled();
    }

    onEnabledKeyChanged: {
        if (root.started)
            root._togglesChanged();
    }

    Timer {
        interval: root.startDelay
        running: Config.initialLoadComplete && !root.started
        onTriggered: {
            root.started = true;
            root._seen = root.enabledIds;
            root.refresh();
            root.ensureEnabled();
        }
    }
}
