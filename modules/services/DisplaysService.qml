pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.globals
import qs.config
import "DisplayModel.js" as DisplayModel

// Monitors: the live outputs, applying a layout with the 15 s "keep these
// settings?" session, identify overlays and the old compositor monitor rules
// found in the user's own config. Output logic is in the backend `displays`
// service and DisplayModel.js; the saved layout is Config.displays.monitors.
Singleton {
    id: root

    // Live outputs from the compositor (displays.list)
    property var outputs: []

    // Pending/kept/reverted change {id, state, remaining, live}; state "" = none
    property var session: ({
            "id": "",
            "state": "",
            "remaining": 0,
            "live": true
        })
    readonly property bool pending: root.session.state === "pending"

    // Overlay numbers [{name, index}] shown by identify() for a few seconds
    property var identified: []

    // Monitor rules in the user's compositor config, [{file, line, text}] from displays.conflicts
    property var conflicts: []

    // Rules the last move left in place, [{file, line, text, reason}]
    property var moveSkipped: []

    // Configs of this shell's pending apply. The backend saves a kept
    // layout itself (whoever keeps it); only the dry run's mock cannot, so
    // there the shell saves it into the dry run's config copy.
    property var _candidate: []

    // True between an apply request and its answer (blocks a second apply)
    property bool applying: false

    // Last problem to show the user: kind is "apply", "keep", "revert",
    // "restore" (the backend could not put the old layout back) or "info".
    property var notice: ({
            "kind": "",
            "message": ""
        })

    signal applyFailed(string message)

    function _text(error, fallback) {
        if (error === undefined || error === null)
            return fallback;
        if (typeof error === "string")
            return error;
        return error.message ? String(error.message) : fallback;
    }

    function setNotice(kind, message) {
        root.notice = {
            "kind": kind,
            "message": message
        };
        // keep/revert are answered on the full-screen prompt, which closes
        // at once: say what went wrong where the user will still see it
        const titles = {
            "keep": "prefs.displays.keep_failed",
            "revert": "prefs.displays.revert_failed",
            "restore": "prefs.displays.restore_failed"
        };
        if (message !== "" && titles[kind] !== undefined) {
            try {
                Notifications.notifyInternal({
                    "summary": I18n.t(titles[kind]),
                    "body": message,
                    "appName": Brand.displayName,
                    "urgency": "critical",
                    "replaceKey": Brand.appId + "-displays"
                });
            } catch (e) {
                console.warn("DisplaysService: notify failed", e);
            }
        }
    }

    function dismissNotice() {
        if (root.notice.kind !== "" || root.notice.message !== "")
            root.setNotice("", "");
    }

    function refresh() {
        BackendService.call("displays.list", {}, (result, error) => {
            if (error) {
                console.warn("DisplaysService: list failed", JSON.stringify(error));
                return;
            }
            root.outputs = result || [];
        });
    }

    // The saved layout resolved onto the connected outputs (current connector names)
    function savedConfigs() {
        const saved = Config.displaysReady ? Array.from(Config.displays.monitors) : [];
        return DisplayModel.resolveSaved(saved, root.outputs);
    }

    function currentConfigs() {
        const saved = root.savedConfigs();
        return root.outputs.map(o => DisplayModel.outputToConfig(o, saved.find(c => c.name === o.name)));
    }

    // Applies configs (the saved form) live; the backend reverts after 15 s unless keep() is called.
    // Only the outputs that differ from the live state are applied.
    function apply(configs) {
        if (root.applying)
            return;
        root.applying = true;
        root.dismissNotice();
        BackendService.call("displays.apply", {
            "outputs": configs.map(DisplayModel.toWire)
        }, (result, error) => {
            root.applying = false;
            if (error || !result) {
                const message = root._text(error, "apply failed");
                root.setNotice("apply", message);
                root.applyFailed(message);
                root.refresh();
                return;
            }
            if (result.unchanged === true || !result.session) {
                root.setNotice("info", "");
                root.refresh();
                return;
            }
            root.session = {
                "id": result.session,
                "state": "pending",
                "remaining": result.revertIn,
                "live": result.live !== false
            };
            const applied = Array.isArray(result.applied) ? result.applied : null;
            root._candidate = applied ? configs.filter(c => applied.indexOf(c.name) >= 0) : configs;
            root.refresh();
        });
    }

    function keep() {
        if (!root.pending)
            return;
        const id = root.session.id;
        BackendService.call("displays.keep", {
            "session": id
        }, (result, error) => {
            if (error) {
                console.warn("DisplaysService: keep failed", JSON.stringify(error));
                root.setNotice("keep", root._text(error, "keep failed"));
                root.refresh();
                return;
            }
            const candidate = root._candidate;
            root._candidate = [];
            if (DryRun.active && candidate.length > 0) {
                const saved = Config.displaysReady ? Array.from(Config.displays.monitors) : [];
                root.saveCurrent(DisplayModel.mergeSaved(saved, candidate));
            }
        });
    }

    function revert() {
        if (!root.pending)
            return;
        BackendService.call("displays.revert", {
            "session": root.session.id
        }, (result, error) => {
            if (error) {
                console.warn("DisplaysService: revert failed", JSON.stringify(error));
                root.setNotice("revert", root._text(error, "revert failed"));
                root.refresh();
            }
        });
    }

    function identify() {
        BackendService.call("displays.identify", {}, (result, error) => {
            if (error)
                console.warn("DisplaysService: identify failed", JSON.stringify(error));
        });
    }

    // Persists configs as the saved layout (bulk write, one disk save)
    function saveCurrent(configs) {
        if (!Config.displaysReady)
            return;
        Config.holdAutoSave();
        try {
            Config.displays.monitors = configs;
        } finally {
            Config.releaseAutoSave();
        }
        Config.saveDisplays();
    }

    function scanConflicts() {
        BackendService.call("displays.conflicts", {}, (result, error) => {
            if (error) {
                console.warn("DisplaysService: conflicts failed", JSON.stringify(error));
                return;
            }
            root.conflicts = result || [];
        });
    }

    // Comments the rules out of the user's compositor config and merges the
    // outputs they described into the saved layout (by connector name).
    function moveConflicts() {
        BackendService.call("displays.moveConflicts", {}, (result, error) => {
            if (error || !result) {
                console.warn("DisplaysService: moveConflicts failed", JSON.stringify(error));
                return;
            }
            root.moveSkipped = result.skipped || [];
            const imported = (result.outputs || []).map(w => DisplayModel.fromWire(w, root.outputs));
            const saved = Config.displaysReady ? Array.from(Config.displays.monitors) : [];
            const merged = DisplayModel.mergeSaved(saved, imported);
            root.saveCurrent(merged);
            root.scanConflicts();
        });
    }

    function _onSession(data) {
        if (!data)
            return;
        const prev = root.session.state;
        if (data.error && data.error !== root.notice.message)
            root.setNotice(data.state === "kept" ? "keep" : "restore", String(data.error));
        root.session = {
            "id": data.session,
            "state": data.state,
            "remaining": data.remaining || 0,
            "live": data.live !== false
        };
        if (prev === "pending" && data.state !== "pending") {
            if (data.state === "reverted")
                root._candidate = [];
            root.refresh();
        }
    }

    function _onIdentify(data) {
        root.identified = (data && data.outputs) || [];
        identifyClear.restart();
    }

    Timer {
        id: identifyClear
        interval: 3000
        onTriggered: root.identified = []
    }

    Component.onCompleted: {
        BackendService.addSubscription(["displays"], (service, data) => {
            if (service === "displays.session")
                Qt.callLater(() => root._onSession(data));
            else if (service === "displays.identify")
                Qt.callLater(() => root._onIdentify(data));
        });
        root.refresh();
    }
}
