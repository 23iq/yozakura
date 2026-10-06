pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
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

    signal applyFailed(string message)

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
        return root.outputs.map(DisplayModel.outputToConfig);
    }

    // Applies configs (the saved form) live; the backend reverts after 15 s unless keep() is called
    function apply(configs) {
        BackendService.call("displays.apply", {
            "outputs": configs.map(DisplayModel.toWire)
        }, (result, error) => {
            if (error || !result) {
                root.applyFailed(error && error.message ? error.message : "apply failed");
                root.refresh();
                return;
            }
            root.session = {
                "id": result.session,
                "state": "pending",
                "remaining": result.revertIn,
                "live": result.live !== false
            };
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
            if (error)
                console.warn("DisplaysService: keep failed", JSON.stringify(error));
        });
    }

    function revert() {
        if (!root.pending)
            return;
        BackendService.call("displays.revert", {
            "session": root.session.id
        }, (result, error) => {
            if (error)
                console.warn("DisplaysService: revert failed", JSON.stringify(error));
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
        Config.pauseAutoSave = true;
        try {
            Config.displays.monitors = configs;
        } finally {
            Config.pauseAutoSave = false;
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
            const imported = (result.outputs || []).map(w => DisplayModel.fromWire(w, root.outputs));
            const merged = Config.displaysReady ? Array.from(Config.displays.monitors) : [];
            for (const cfg of imported) {
                const i = merged.findIndex(m => m.name === cfg.name);
                if (i >= 0)
                    merged[i] = cfg;
                else
                    merged.push(cfg);
            }
            root.saveCurrent(merged);
            root.scanConflicts();
        });
    }

    function _onSession(data) {
        if (!data)
            return;
        const prev = root.session.state;
        root.session = {
            "id": data.session,
            "state": data.state,
            "remaining": data.remaining || 0,
            "live": data.live !== false
        };
        if (prev === "pending" && data.state !== "pending")
            root.refresh();
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
