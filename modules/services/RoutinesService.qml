pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.services

// Routines (backend svc/routines): the saved list, kept live through the
// "routines" subscription, plus save/delete/run. A routine is
// {id, name, icon, keywords, continueOnError, steps: [{kind, action|tool, args, ms}]}.
// Runs report per step: {id, name, ok, steps: [{index, label, status, error, output}]}.
Singleton {
    id: root

    property var routines: []
    // id of the routine running now ("" = none) and the last report
    property string running: ""
    property var lastReport: null
    property string lastError: ""

    signal reported(var report)
    signal failed(string message)

    function find(ref) {
        const r = String(ref || "");
        return root.routines.find(x => x.id === r) || root.routines.find(x => String(x.name).toLowerCase() === r.toLowerCase()) || null;
    }

    function call(method, params, callback) {
        BackendService.call("routines." + method, params || {}, (result, error) => {
            if (error) {
                root.lastError = error.message || String(error);
                root.failed(root.lastError);
            }
            if (callback)
                callback(error ? null : result, error ? root.lastError : "");
        });
    }

    function refresh() {
        root.call("list", {}, result => {
            if (result && Array.isArray(result.routines))
                root.routines = result.routines;
        });
    }

    // routine: the full routine; replace: id it replaces ("" = new)
    function save(routine, replace, callback) {
        root.call("save", {
            "routine": routine,
            "replace": replace || ""
        }, callback);
    }

    function remove(id, callback) {
        root.call("delete", {
            "id": id
        }, callback);
    }

    // Runs a saved routine by id; the backend notifies on failure.
    function run(id, callback) {
        root.call("run", {
            "id": id
        }, callback);
    }

    // Runs an unsaved routine (the editor's test run), quietly.
    function test(routine, callback) {
        root.call("run", {
            "routine": routine,
            "quiet": true
        }, callback);
    }

    Component.onCompleted: {
        BackendService.addSubscription(["routines"], (service, data) => {
            if (service === "routines.state" && data && Array.isArray(data.routines))
                root.routines = data.routines;
            else if (service === "routines.running")
                root.running = data && data.id ? data.id : "";
            else if (service === "routines.report") {
                root.running = "";
                root.lastReport = data;
                root.reported(data);
            }
        });
    }
}
