pragma Singleton
import QtQuick
import Quickshell
import qs.modules.services
import "../extras/ExtrasModel.js" as ExtrasModel

// Apps & Extras: the optional-software catalog of the backend `extras`
// service (backend/pkg/svc/extras), its detected install state and the live
// install queue. Settings > Apps & Extras and the onboarding app steps read
// it; every install goes through the backend (pkexec / flatpak --user / npm
// --prefix), nothing runs from QML.
Singleton {
    id: root

    // {categories:[{id, name, icon}], entries:[...]} once loaded
    property var catalog: null
    // {distro, gpu, hasParu, hasYay, hasFlatpak, hasNpm, hasPkexec, multilib}
    property var platform: ({})
    // entry id -> {state, source, version, reason}
    property var status: ({})
    // job id -> Progress {job, kind, entries, state, percent, phase, reason}
    property var jobs: ({})
    // entry id -> latest Progress of the job that installs it
    property var progress: ({})
    property bool loading: false
    // The last job failed for lack of network: installs stay disabled until
    // a job succeeds or the user checks again (refresh()).
    property bool offline: false
    // Install waiting for consent: {kind: "multilib", entries, ids}
    property var confirm: null
    // Last refused install: {reasons: {id: reason}} (needs_aur_helper, ...)
    property var unavailable: null
    // Last plain error text of an install / cancel / retry call
    property string error: ""

    // An install request was accepted and queued (the ids of that request).
    signal queued(var ids)

    readonly property var activeJobs: ExtrasModel.activeJobs(root.jobs)
    readonly property bool busy: root.activeJobs.length > 0

    property bool _catalogRequested: false
    property bool _subscribed: false

    function entry(id) {
        const list = root.catalog ? root.catalog.entries : [];
        return list.find(e => e.id === id) ?? null;
    }

    function displayName(id) {
        const e = root.entry(id);
        return e ? e.name : id;
    }

    function cardState(id) {
        return ExtrasModel.cardState(root.status[id], root.progress[id]);
    }

    // Catalog (once) and the detected state; safe to call from every page.
    function load() {
        root._subscribe();
        if (!root._catalogRequested) {
            root._catalogRequested = true;
            root.loading = true;
            BackendService.call("extras.catalog", {}, (result, error) => {
                root.loading = false;
                if (error || !result) {
                    root._catalogRequested = false;
                    root.error = String(error || "");
                    return;
                }
                root.platform = result.platform || {};
                root.catalog = {
                    "categories": result.categories || [],
                    "entries": result.entries || []
                };
            });
        }
        root._status(false);
    }

    // Re-detect now (also clears the offline flag: "Check again").
    function refresh() {
        root.offline = false;
        root._status(true);
    }

    function _status(force) {
        BackendService.call("extras.status", force ? {
            "refresh": true
        } : {}, (result, error) => {
            if (!error && result)
                root.status = result;
        });
    }

    // Queue the ids as one batch. A multilib need parks the request in
    // `confirm`; call again with confirmMultilib (accept()) to go on.
    function install(ids, confirmMultilib) {
        if (!ids || ids.length === 0)
            return;
        root.error = "";
        root.unavailable = null;
        BackendService.call("extras.install", {
            "ids": ids,
            "confirmMultilib": !!confirmMultilib
        }, (result, error) => {
            if (!error) {
                root.confirm = null;
                root.queued(ids);
                return;
            }
            const e = ExtrasModel.parseError(error);
            if (e.code === "needs_confirm")
                root.confirm = Object.assign({}, e.data, {
                    "ids": ids
                });
            else if (e.code === "unavailable")
                root.unavailable = e.data;
            else
                root.error = e.message || String(error);
        });
    }

    function acceptConfirm() {
        const c = root.confirm;
        if (c)
            root.install(c.ids, true);
    }

    function dismissConfirm() {
        root.confirm = null;
    }

    function dismissUnavailable() {
        root.unavailable = null;
    }

    function cancel(job) {
        BackendService.call("extras.cancel", {
            "job": job
        }, (result, error) => {
            if (error)
                root.error = ExtrasModel.parseError(error).message;
        });
    }

    // needs_sync failure: full system upgrade, then the same job again.
    function retryWithUpgrade(job) {
        BackendService.call("extras.upgradeAndRetry", {
            "job": job
        }, (result, error) => {
            if (error)
                root.error = ExtrasModel.parseError(error).message;
        });
    }

    // cb(text, error)
    function fetchLog(job, cb) {
        BackendService.call("extras.log", {
            "job": job
        }, (result, error) => cb(result ? (result.text || "") : "", error ? String(error) : ""));
    }

    function _onProgress(p) {
        if (!p || !p.job)
            return;
        const jobs = Object.assign({}, root.jobs);
        jobs[p.job] = p;
        root.jobs = jobs;
        if (p.entries && p.entries.length > 0) {
            const prog = Object.assign({}, root.progress);
            p.entries.forEach(id => prog[id] = p);
            root.progress = prog;
        }
        if (p.state === "failed" && p.reason === "network")
            root.offline = true;
        else if (p.state === "done")
            root.offline = false;
    }

    function _subscribe() {
        if (root._subscribed)
            return;
        root._subscribed = true;
        BackendService.addSubscription(["extras"], (service, data) => {
            if (service === "extras.progress")
                Qt.callLater(() => root._onProgress(data));
            else if (service === "extras.status" && data)
                Qt.callLater(() => root.status = data);
        });
    }
}
