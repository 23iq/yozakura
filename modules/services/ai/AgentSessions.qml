import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import "AgentTimeline.js" as Timeline
import "EngineSelection.js" as Selection

// QML side of the backend "agents" service (Claude Code, Codex, OpenCode run
// as CLI processes by the Go daemon). Keeps one timeline per opened session:
// a ListModel of blocks (see AgentTimeline.js) plus reducer state.
QtObject {
    id: root

    // [{id, label, available, binary, version, capabilities, notes}]
    property var agents: []
    // [{id, agent, cwd, title, created, updated, status, pinned, yolo, model, mode, lastText, pending}]
    property var sessions: []
    property string activeId: ""
    readonly property var active: sessions.find(s => s.id === activeId) || null
    property bool connected: false

    // per session: {state, model (ListModel), diffs (array)}
    property var _timelines: ({})
    property int timelineRevision: 0
    property int _sub: -1

    signal sessionCreated(var meta)
    signal eventReceived(var event)
    signal operationError(string message)

    property AgentModels modelCatalogs: AgentModels {}

    function settingsFor(agent, cwd) {
        return modelCatalogs.get(agent, cwd);
    }

    function refreshModels(agent, cwd) {
        modelCatalogs.refresh(agent, cwd);
    }

    function prepareInput(text, attachments, capabilities) {
        return Selection.agentInput(text, attachments, capabilities);
    }

    readonly property Component listModel: Component {
        ListModel {}
    }

    readonly property var config: {
        const a = Config.ai.agents;
        const pick = id => ({
                    enabled: a[id].enabled,
                    binary: a[id].binary,
                    model: a[id].model,
                    effort: a[id].effort || "",
                    yolo: a[id].yolo,
                    extraArgs: a[id].extraArgs || []
                });
        return {
            agents: {
                claude: pick("claude"),
                codex: pick("codex"),
                opencode: pick("opencode")
            },
            policy: {
                autoApprove: a.autoApprove || ["read"]
            },
            yozakuraMcp: Config.ai.mcp.yozakura
        };
    }
    onConfigChanged: if (connected)
        configure()

    function start() {
        if (_sub >= 0)
            return;
        _sub = BackendService.addSubscription(["agents"], (service, data) => {
            if (service === "agents.event")
                root._onEvent(data);
            else if (service === "agents.sessions")
                root.sessions = data || [];
            else if (service === "agents.agents")
                root.agents = data || [];
        });
        configure();
    }

    function configure() {
        BackendService.call("agents.configure", config, () => {
            root.connected = true;
            root.refresh();
        });
    }

    function refresh() {
        BackendService.call("agents.list_agents", {}, (res, err) => {
            if (!err && Array.isArray(res))
                root.agents = res;
        });
        BackendService.call("agents.sessions", {}, (res, err) => {
            if (!err && Array.isArray(res))
                root.sessions = res;
        });
    }

    function timeline(id) {
        if (!id)
            return null;
        if (!_timelines[id]) {
            _timelines[id] = {
                state: Timeline.newState(),
                model: listModel.createObject(root),
                loading: true
            };
            _load(id);
        }
        return _timelines[id];
    }

    function _load(id) {
        BackendService.call("agents.events", {
            session: id,
            since: 0
        }, (res, err) => {
            const tl = _timelines[id];
            if (!tl)
                return;
            tl.loading = false;
            if (err || !res)
                return;
            tl.state = Timeline.newState();
            tl.model.clear();
            for (const ev of res.events || [])
                _applyTo(tl, ev);
            timelineRevision++;
        });
    }

    function _applyTo(tl, ev) {
        const r = Timeline.apply(tl.state, ev);
        for (const op of r.ops) {
            if (op.op === "append")
                tl.model.append(op.block);
            else
                for (const k in op.fields)
                    tl.model.setProperty(op.index, k, op.fields[k]);
        }
        return r;
    }

    function _onEvent(ev) {
        eventReceived(ev);
        const tl = _timelines[ev.session];
        if (!tl)
            return; // not opened in the UI; the session list carries the summary
        if (tl.loading)
            return; // the history request returns everything up to now
        const r = _applyTo(tl, ev);
        if (r.resync)
            _load(ev.session);
        if (r.statusChanged || r.diffsChanged)
            timelineRevision++;
    }

    function create(agent, cwd, opts) {
        const o = opts || {};
        BackendService.call("agents.create", {
            agent: agent,
            cwd: cwd || Config.ai.agents.defaultCwd || Quickshell.env("HOME"),
            title: o.title || "",
            model: o.model || "",
            effort: o.effort || "",
            mode: o.mode || "agent",
            systemPrompt: o.systemPrompt || "",
            yolo: o.yolo === undefined ? null : !!o.yolo
        }, (res, err) => {
            if (err || !res) {
                console.warn("agents.create failed:", err);
                operationError(String(err || "create failed"));
                if (o.onError)
                    o.onError(err || "create failed");
                return;
            }
            const meta = res.session || res;
            root.sessions = [meta].concat(root.sessions.filter(s => s.id !== meta.id));
            if (o.activate !== false)
                root.activeId = meta.id;
            root.timeline(meta.id);
            root._rememberDir(meta.cwd);
            root.sessionCreated(meta);
            const accepted = !o.onCreated || o.onCreated(meta) !== false;
            if (o.prompt && accepted)
                root.send(meta.id, o.prompt, o.images || []);
        });
    }

    function _rememberDir(dir) {
        if (!dir)
            return;
        const list = (Config.ai.agents.recentDirs || []).filter(d => d !== dir);
        list.unshift(dir);
        Config.ai.agents.recentDirs = list.slice(0, 8);
    }

    function send(id, text, images, onResult) {
        BackendService.call("agents.send", {
            session: id,
            text: text,
            images: images || []
        }, (res, err) => {
            if (err)
                operationError(String(err));
            if (onResult)
                onResult(res, err);
        });
    }

    function respond(id, requestId, decision) {
        BackendService.call("agents.respond", {
            session: id,
            request: requestId,
            decision: decision
        });
    }

    function cancel(id) {
        BackendService.call("agents.cancel", {
            session: id
        });
    }

    function close(id) {
        BackendService.call("agents.close", {
            session: id
        });
    }

    function remove(id) {
        BackendService.call("agents.delete", {
            session: id
        }, () => root.refresh());
        if (_timelines[id]) {
            _timelines[id].model.destroy();
            delete _timelines[id];
        }
        sessions = sessions.filter(s => s.id !== id);
        if (activeId === id)
            activeId = "";
    }

    function update(id, fields) {
        BackendService.call("agents.update", Object.assign({
            session: id
        }, fields), (res, err) => {
            if (err)
                operationError(String(err));
            else if (res)
                sessions = sessions.map(s => s.id === id ? res : s);
        });
    }
}
