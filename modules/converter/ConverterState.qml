import QtQuick
import Quickshell
import qs.modules.services
import qs.config
import "ConverterModel.js" as Model

// The converter window's list and its talk with the backend `convert`
// service (backend/pkg/svc/convert): probe what is added, start, cancel,
// paste from the clipboard, copy a result. Every conversion runs in the
// backend; job events arrive on the "convert" subscription. Rows: see
// ConverterModel.js.
QtObject {
    id: root

    property var rows: []
    // The quality of lossy targets ("small" | "balanced" | "best"),
    // starting from system.converter.quality.
    property string quality: Config.system.converter.quality
    // A short message under the list (nothing on the clipboard, ...).
    property string notice: ""
    property bool probing: false

    readonly property var groups: Model.kindGroups(root.rows)
    readonly property int startCount: Model.startable(root.rows).length
    readonly property bool busy: Model.busy(root.rows)
    readonly property bool showQuality: Model.needsQuality(root.rows)
    readonly property bool empty: root.rows.length === 0

    property var _sub: null
    // Job ids this window's start replies returned: only their events
    // touch rows (the backend replays every job it still knows, other
    // windows' and earlier ones included).
    property var _own: ({})
    // Events of ids not (yet) returned by a start reply: the event can
    // beat the reply. Applied when the reply names the id, else ignored.
    property var _early: ({})
    // Paths whose pending start was stopped or removed before the reply
    // named its job: that job is cancelled as soon as the reply comes.
    // {<batch>: {<path>: true}}, per start request
    property var _cancelOnReply: ({})
    // the token of the latest start request (ConverterModel.markPending)
    property int _batch: 0
    // The latest result of this batch: revealed once the batch is over
    // (system.converter.openFolder), however its last job ended.
    property string _lastOutput: ""

    // "Show files when done": once nothing is converting any more, with
    // at least one result written (a failed or stopped last job included).
    onBusyChanged: {
        if (root.busy || root._lastOutput === "")
            return;
        const out = root._lastOutput;
        root._lastOutput = "";
        if (Config.system.converter.openFolder)
            root.reveal(out);
    }

    // The translated line of an error code, "" when the code is unknown
    // here (a newer daemon): the caller shows the backend's words.
    function _codeText(info) {
        const key = "converter.error." + info.key;
        return info.key !== "" && I18n.has(key) ? I18n.t(key, ...info.args) : "";
    }

    // A failed call's error (code, message, args from BackendService.call)
    // as a translated line, else a generic line with the backend's words.
    function errorText(code, error, args) {
        const info = Model.errorInfo(code, error, args);
        return root._codeText(info) || I18n.t("converter.error.other", info.text);
    }

    // A failed job's error: translated by its code, else the tool's own
    // words (ffmpeg, ImageMagick...).
    function jobErrorText(job) {
        const info = Model.errorInfo(job ? job.code : "", job ? job.error : "", job ? job.errorArgs : []);
        return root._codeText(info) || info.text;
    }

    function add(paths) {
        const list = (paths || []).filter(p => String(p).indexOf("/") === 0);
        if (list.length === 0)
            return;
        root.notice = "";
        root.probing = true;
        BackendService.call("convert.probe", {
            "paths": list
        }, (result, error, code, args) => {
            root.probing = false;
            if (error || !result) {
                root.notice = root.errorText(code, error, args);
                return;
            }
            root.rows = Model.addFiles(root.rows, result.files || []);
        });
    }

    function addUrls(urls) {
        root.add(Model.localPaths(urls));
    }

    function paste() {
        root.notice = "";
        BackendService.call("convert.paste", {}, (result, error, code, args) => {
            if (error || !result) {
                root.notice = root.errorText(error ? code : "clipboard_no_file", error, args);
                return;
            }
            root.add(result.paths || []);
        });
    }

    function setTarget(path, id) {
        root.rows = Model.setTarget(root.rows, path, id);
    }

    function setKindTarget(kind, id) {
        root.rows = Model.setKindTarget(root.rows, kind, id);
    }

    function remove(path) {
        const row = root.rows.find(r => r.path === path);
        if (Model.working(row))
            root.cancel(row);
        root.rows = Model.removeRow(root.rows, path);
    }

    // Stop every conversion under way (the rows stay).
    function stopAll() {
        root.rows.forEach(r => {
            if (Model.working(r))
                root.cancel(r);
        });
    }

    function clearAll() {
        root.rows.forEach(r => {
            if (Model.working(r))
                root.cancel(r);
        });
        // nothing listed is left to show
        root._lastOutput = "";
        root.rows = [];
        root.notice = "";
    }

    function convert() {
        const items = Model.startItems(root.rows);
        if (items.length === 0)
            return;
        root._subscribe();
        root.notice = "";
        if (!root.busy)
            root._lastOutput = "";
        const batch = ++root._batch;
        root.rows = Model.markPending(root.rows, items, batch);
        BackendService.call("convert.start", {
            "items": items,
            "outDir": Config.system.converter.outputDir,
            "quality": root.quality
        }, (result, error, code, args) => {
            if (error || !result) {
                root.notice = root.errorText(code, error, args);
                root._dropCancels(batch);
                root.rows = Model.clearPending(root.rows, batch);
                return;
            }
            const jobs = result.jobs || [];
            const own = Object.assign({}, root._own);
            jobs.forEach(j => own[j.id] = true);
            root._own = own;
            // stopped or removed while the reply was on its way
            const drop = root._cancelOnReply[batch] || ({});
            jobs.forEach(j => {
                if (drop[j.path])
                    root._cancelId(j.id);
            });
            root._dropCancels(batch);
            root.rows = Model.attachJobs(root.rows, jobs, batch);
            const early = Object.assign({}, root._early);
            jobs.forEach(j => {
                if (early[j.id]) {
                    root.applyJob(early[j.id]);
                    delete early[j.id];
                }
            });
            // replayed jobs of other windows never get a reply: drop them
            // once nothing waits for one
            root._early = root.rows.some(r => r.job && r.job.state === "pending") ? early : ({});
        });
    }

    // A job event from the subscription.
    function onJobEvent(job) {
        if (!job || !job.id)
            return;
        if (root._own[job.id]) {
            root.applyJob(job);
        } else if (root.rows.some(r => r.job && r.job.state === "pending")) {
            const early = Object.assign({}, root._early);
            early[job.id] = job;
            root._early = early;
        }
    }

    function applyJob(job) {
        const before = root.rows.find(r => r.job && r.job.id === job.id);
        if (!before)
            return;
        if (job.state === "done" && before.job.state !== "done" && job.output)
            root._lastOutput = job.output;
        root.rows = Model.applyJob(root.rows, job);
    }

    // Stop a row's conversion. A pending one has no job id yet: its job
    // is cancelled when the start reply names it.
    function cancel(row) {
        if (!row || !row.job)
            return;
        if (row.job.id) {
            root._cancelId(row.job.id);
        } else if (row.job.state === "pending") {
            const all = Object.assign({}, root._cancelOnReply);
            all[row.job.batch] = Object.assign({}, all[row.job.batch] || ({}));
            all[row.job.batch][row.path] = true;
            root._cancelOnReply = all;
        }
    }

    function _dropCancels(batch) {
        const all = Object.assign({}, root._cancelOnReply);
        delete all[batch];
        root._cancelOnReply = all;
    }

    function _cancelId(id) {
        BackendService.call("convert.cancel", {
            "id": id
        }, null);
    }

    // Select the file in the file manager (FileManager1), else open its
    // folder. The URI is percent-encoded (spaces, #, commas).
    function reveal(path) {
        if (!path)
            return;
        Quickshell.execDetached(["sh", "-c", "dbus-send --session --print-reply --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems array:string:\"$1\" string:\"\" >/dev/null 2>&1 || xdg-open \"$2\"", "sh", Model.fileUri(path), Model.dirOf(path)]);
    }

    function copy(path) {
        BackendService.call("convert.copy", {
            "path": path
        }, (result, error, code, args) => {
            root.notice = error ? root.errorText(code, error, args) : "";
        });
    }

    function _subscribe() {
        if (root._sub !== null)
            return;
        root._sub = BackendService.addSubscription(["convert"], (service, data) => {
            if (service === "convert.job" && data)
                Qt.callLater(() => root.onJobEvent(data));
        });
    }

    function dispose() {
        if (root._sub !== null)
            BackendService.removeSubscription(root._sub);
        root._sub = null;
    }
}
