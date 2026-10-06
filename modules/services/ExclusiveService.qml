pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services

// Exclusive mode (Hyprland): make the shell the only one on the session and
// undo it. State and actions come from the backend `exclusive` service
// (status, plan, enable, restore); the files, units and the compositor
// reload are handled there. The Settings card and the onboarding finish
// step use this singleton.
Singleton {
    id: root

    // exclusive.status: {active, backup, disabledUnits, compositor, reason?}
    property var status: ({
            "active": false,
            "backup": "",
            "disabledUnits": [],
            "compositor": "",
            "reason": ""
        })
    // exclusive.plan: what enable would do (units, monitors, keyboard ...)
    property var plan: ({})
    property bool busy: false
    property string error: ""
    // exclusive.restore result: where the replaced files were saved
    property var restored: null

    readonly property bool supported: YozdService.compositorName === "hyprland"
    readonly property bool active: !!root.status.active
    // Why enabling is impossible here (home-manager config, linked dir ...)
    readonly property string blocked: root.active ? "" : (root.status.reason ?? "")

    function refresh() {
        BackendService.call("exclusive.status", {}, (result, error) => {
            if (error) {
                console.warn("ExclusiveService: status failed", JSON.stringify(error));
                return;
            }
            root.status = result || root.status;
        });
    }

    function loadPlan() {
        BackendService.call("exclusive.plan", {}, (result, error) => {
            root.plan = error ? ({}) : (result || {});
        });
    }

    // Callback receives (ok). Failure text lands in `error`.
    function enable(done) {
        root._run("exclusive.enable", {}, done);
    }

    function restore(done) {
        root._run("exclusive.restore", {}, done);
    }

    function _run(method, params, done) {
        if (root.busy)
            return;
        root.busy = true;
        root.error = "";
        root.restored = null;
        BackendService.call(method, params, (result, error) => {
            root.busy = false;
            if (error) {
                root.error = error.message ?? String(error);
            } else {
                root.status = result || root.status;
                if (method === "exclusive.restore")
                    root.restored = {
                        "replaced": result.replaced ?? "",
                        "backup": result.backup ?? ""
                    };
                // restored, but a unit or the reload failed afterwards
                if (result && result.warning)
                    root.error = result.warning;
            }
            if (done)
                done(!error);
            root.refresh();
        });
    }
}
