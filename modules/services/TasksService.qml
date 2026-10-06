pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import "tasks/TaskModel.js" as TaskModel

// Thin client of the backend tasks service (backend/pkg/svc/tasks; API in
// docs/superpowers/plans/2026-10-06-G1-tasks-backend.md): AI-first coding
// tasks run by CLI agents in worktrees. Keeps every task from the
// subscription (tasks.list / tasks.updated / tasks.removed), the notch
// activity summary, per-project caches (project config, git summary,
// templates) and the task selected in the Code board. The transcript of a
// run is the agents session `run.sessionId` (Ai.agents).
Singleton {
    id: root

    readonly property var cfg: Config.ai ? Config.ai.tasks : null

    // Every task, newest first (backend order kept on updates).
    property var tasks: []
    property var activity: ({
            "headline": "idle",
            "items": []
        })
    property var settings: ({})
    property bool ready: false
    // agents session id -> task id (task sessions stay out of the history)
    readonly property var sessionIds: {
        const out = {};
        for (const t of root.tasks)
            for (const r of t.runs || [])
                for (const s of (r.sessionIds || []).concat(r.sessionId ? [r.sessionId] : []))
                    out[s] = t.id;
        return out;
    }

    // Board selection (Code space).
    property string selectedId: ""
    property int selectedRun: -1
    readonly property var selected: root.tasks.find(t => t.id === root.selectedId) || null

    // Per project dir: tasks.project.get view, tasks.git summary, templates.
    property var projects: ({})
    property var gits: ({})
    property var templates: ({})

    property string lastError: ""
    signal failed(string message)
    // A task should be shown (notification Open, notch click, tasks.open).
    signal focusRequested(string id, int run)

    function task(id) {
        return root.tasks.find(t => t.id === id) || null;
    }

    function select(id, run) {
        root.selectedId = id || "";
        root.selectedRun = run === undefined ? -1 : run;
    }

    // Show a task in the AI bar: Code space, board, task selected.
    function focusTask(id, run) {
        if (!id)
            return;
        root.select(id, run === undefined ? -1 : run);
        if (Ai.space !== "code")
            Ai.setSpace("code");
        if (Ai.activeAgent)
            Ai.newConversation();
        if (!GlobalStates.assistantVisible)
            GlobalStates.toggleAssistant();
        else
            GlobalStates.assistantFocusRequested(false);
        root.focusRequested(id, run === undefined ? -1 : run);
    }

    // ── backend calls ──
    function call(method, params, callback) {
        BackendService.call("tasks." + method, params || {}, (result, error) => {
            if (error) {
                root.lastError = error.message || String(error);
                root.failed(root.lastError);
            } else {
                root.lastError = "";
                if (result && result.id && result.runs)
                    root.upsert(result);
            }
            if (callback)
                callback(result, error ? (error.message || String(error)) : "");
        });
    }

    function create(params, callback) {
        root.call("create", params, (task, error) => {
            if (task && task.id)
                root.select(task.id, -1);
            if (callback)
                callback(task, error);
        });
    }
    function updatePlan(id, steps, callback) {
        root.call("plan.update", {
            "id": id,
            "steps": TaskModel.planClean(steps)
        }, callback);
    }
    function runPlan(id, steps, callback) {
        const p = {
            "id": id
        };
        if (steps)
            p.steps = TaskModel.planClean(steps);
        root.call("run", p, callback);
    }
    function followup(id, run, text, callback) {
        root.call("followup", {
            "id": id,
            "run": Math.max(0, run),
            "text": text
        }, callback);
    }
    function accept(id, run, message, callback) {
        const p = {
            "id": id,
            "run": Math.max(0, run)
        };
        if (message)
            p.message = message;
        root.call("accept", p, callback);
    }
    // run < 0: every run
    function discard(id, run, callback) {
        const p = {
            "id": id
        };
        if (run !== undefined && run >= 0)
            p.run = run;
        root.call("discard", p, callback);
    }
    function cancel(id, callback) {
        root.call("cancel", {
            "id": id
        }, callback);
    }
    function remove(id, callback) {
        root.call("delete", {
            "id": id
        }, (res, error) => {
            if (!error)
                root.drop(id);
            if (callback)
                callback(res, error);
        });
    }
    function diff(id, run, callback) {
        BackendService.call("tasks.diff", {
            "id": id,
            "run": Math.max(0, run)
        }, (res, error) => callback(res ? res.diff || "" : "", error ? (error.message || String(error)) : ""));
    }
    function debug(id, run, lines, callback) {
        BackendService.call("tasks.debug", {
            "id": id,
            "run": Math.max(0, run),
            "lines": lines || 200
        }, (res, error) => callback(res || null, error ? (error.message || String(error)) : ""));
    }

    // ── project caches ──
    function _store(prop, dir, value) {
        const next = Object.assign({}, root[prop]);
        next[dir] = value;
        root[prop] = next;
    }
    function refreshProject(dir, callback) {
        if (!dir)
            return;
        BackendService.call("tasks.project.get", {
            "dir": dir
        }, (res, error) => {
            if (!error && res)
                root._store("projects", dir, res);
            if (callback)
                callback(res, error ? (error.message || String(error)) : "");
        });
    }
    function setProject(patch, callback) {
        BackendService.call("tasks.project.set", patch, (res, error) => {
            if (!error && res)
                root._store("projects", patch.dir, res);
            if (callback)
                callback(res, error ? (error.message || String(error)) : "");
        });
    }
    function refreshGit(dir) {
        if (!dir)
            return;
        BackendService.call("tasks.git", {
            "dir": dir
        }, (res, error) => {
            if (!error && res)
                root._store("gits", dir, res);
        });
    }
    function refreshTemplates(dir) {
        BackendService.call("tasks.templates.list", {
            "dir": dir || ""
        }, (res, error) => {
            if (!error && Array.isArray(res))
                root._store("templates", dir || "", res);
        });
    }
    function refreshAll(dir) {
        root.refreshProject(dir);
        root.refreshGit(dir);
        root.refreshTemplates(dir);
    }

    // ── subscription ──
    function upsert(t) {
        if (!t || !t.id)
            return;
        const list = root.tasks.slice();
        const i = list.findIndex(x => x.id === t.id);
        const before = i >= 0 ? list[i].status : "";
        if (i >= 0)
            list[i] = t;
        else
            list.unshift(t);
        root.tasks = list;
        if (before !== t.status)
            root._statusChanged(t, before);
    }
    function drop(id) {
        root.tasks = root.tasks.filter(t => t.id !== id);
        if (root.selectedId === id)
            root.select("", -1);
    }
    function _statusChanged(t, before) {
        // A finished task's project changed: refresh its git summary.
        if (t.status === "accepted" || t.status === "review")
            root.refreshGit(t.projectDir);
        if (t.status === "review" && before && root.cfg && root.cfg.autoOpenReview && (root.selectedId === "" || root.selectedId === t.id))
            root.select(t.id, -1);
    }

    function applyEvent(kind, data) {
        if (kind === "tasks.list") {
            root.tasks = Array.isArray(data) ? data : [];
            root.ready = true;
        } else if (kind === "tasks.updated") {
            root.upsert(data);
        } else if (kind === "tasks.removed") {
            root.drop(data ? data.id : "");
        } else if (kind === "tasks.activity") {
            root.activity = data || {
                "headline": "idle",
                "items": []
            };
        } else if (kind === "tasks.open") {
            root.focusTask(data ? data.id : "", data && data.run !== undefined ? data.run : -1);
        }
    }

    // ai.tasks.* -> tasks.configure (max parallel, fallback, notifications, merge mode)
    readonly property var configureParams: TaskModel.configureParams(root.cfg)
    function configure() {
        BackendService.call("tasks.configure", root.configureParams, (res, error) => {
            if (!error && res)
                root.settings = res;
        });
    }
    onConfigureParamsChanged: if (root.ready)
        Qt.callLater(root.configure)

    Component.onCompleted: {
        BackendService.addSubscription(["tasks"], (service, data) => {
            const first = !root.ready;
            root.applyEvent(service, data);
            if (first && root.ready)
                root.configure();
        });
    }
}
