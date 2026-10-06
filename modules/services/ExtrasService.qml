pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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
    // A job failed for lack of network: installs stay disabled until a
    // connectivity probe ("Check again", refresh()) succeeds.
    property bool offline: false
    // The connectivity probe is running.
    property bool checking: false
    // Probe argv and its watchdog (tests point them at a missing binary).
    property var probeCommand: ["curl", "-sI", "--max-time", "6", "-o", "/dev/null", "https://flathub.org"]
    property int probeTimeout: 8000
    property alias probeRunning: probe.running
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

    // Re-detect now; while offline also probes the network ("Check again").
    function refresh() {
        root._status(true);
        if (root.offline && !probe.running) {
            root.checking = true;
            probeWatchdog.restart();
            probe.running = true;
        }
    }

    function _status(force) {
        BackendService.call("extras.status", force ? {
            "refresh": true
        } : {}, (result, error) => {
            if (!error && result)
                root._setStatus(result, force);
        });
    }

    // New detection. Finished (done / cancelled) progress no longer pins a
    // card once a fresh detection covers it: always after a forced
    // refresh, otherwise only for entries now detected as installed.
    function _setStatus(st, fresh) {
        root.status = st;
        const prog = {};
        let dropped = false;
        for (const id in root.progress) {
            const p = root.progress[id];
            const finished = p.state === "done" || p.state === "cancelled";
            if (finished && (fresh || (st[id] && st[id].state === "installed")))
                dropped = true;
            else
                prog[id] = p;
        }
        if (dropped)
            root.progress = prog;
    }

    // Cheap connectivity probe: a HEAD request to a fixed URL (argv, no
    // shell). curl's "couldn't resolve / connect / timed out" codes keep
    // the flag; success clears it, and so does any other outcome (no curl,
    // odd TLS setup) so a broken probe never blocks installs for good.
    // A probe that never starts or stops without an exit code (no curl) and
    // one that hangs past the watchdog fail open the same way.
    function _probeDone(offline) {
        if (!root.checking)
            return;
        probeWatchdog.stop();
        root.checking = false;
        root.offline = offline;
    }

    Process {
        id: probe
        command: root.probeCommand
        onExited: (code, status) => root._probeDone([6, 7, 28].includes(code))
        // exited (if any) is delivered first; only then fail open
        onRunningChanged: if (!running)
            Qt.callLater(() => root._probeDone(false))
    }

    Timer {
        id: probeWatchdog
        interval: root.probeTimeout
        onTriggered: {
            probe.running = false;
            root._probeDone(false);
        }
    }

    Timer {
        id: detectAfterDone
        interval: 1500
        onTriggered: root._status(true)
    }

    // Queue the ids as one batch. A multilib need parks the request in
    // `confirm`; call again with confirmMultilib (accept()) to go on.
    function install(ids, confirmMultilib) {
        if (!ids || ids.length === 0 || root.offline)
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
        if (root.offline)
            return;
        BackendService.call("extras.upgradeAndRetry", {
            "job": job
        }, (result, error) => {
            if (error)
                root.error = ExtrasModel.parseError(error).message;
        });
    }

    // Queue `chsh` to `shell` (must be in /etc/shells; asks for the password).
    function setLoginShell(shell) {
        root.error = "";
        BackendService.call("extras.setLoginShell", {
            "shell": shell
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
        else if (p.state === "done" || p.state === "cancelled")
            detectAfterDone.restart();
    }

    function _subscribe() {
        if (root._subscribed)
            return;
        root._subscribed = true;
        BackendService.addSubscription(["extras"], (service, data) => {
            if (service === "extras.progress")
                Qt.callLater(() => root._onProgress(data));
            else if (service === "extras.status" && data)
                Qt.callLater(() => root._setStatus(data, false));
        });
    }
}
