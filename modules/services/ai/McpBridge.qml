import QtQuick
import qs.config
import qs.modules.services

// QML side of the backend "mcp" service: imported/built-in MCP servers, their
// tools (exposed to chat models with tool calling) and tool calls.
QtObject {
    id: root

    // [{name, source, project, transport, command, args, url, envKeys, enabled}]
    property var servers: []
    // [{server, name, description, inputSchema, readOnly, annotations}]
    property var allTools: []
    property bool ready: false
    property string error: ""

    readonly property var config: ({
            disabled: Config.ai.mcp.disabled || [],
            sources: {
                claude: Config.ai.mcp.importClaude,
                codex: Config.ai.mcp.importCodex,
                opencode: Config.ai.mcp.importOpencode
            },
            yozakura: Config.ai.mcp.yozakura
        })
    onConfigChanged: if (ready)
        configure()

    function configure() {
        BackendService.call("mcp.configure", config, (res, err) => {
            root.ready = true;
            root.error = err || "";
            root.refresh();
        });
    }

    // Cheap refresh: the server list and the built-in (in-process) tools.
    // Imported servers are only started by loadAll(), on the first chat
    // message that may use them, or by the settings tools viewer.
    function refresh() {
        BackendService.call("mcp.servers", {}, (res, err) => {
            if (!err && Array.isArray(res))
                root.servers = res;
        });
        if (allLoaded) {
            allLoaded = false;
            loadAll(() => {});
            return;
        }
        BackendService.call("mcp.all_tools", {
            servers: ["yozakura"]
        }, (res, err) => {
            if (!err && Array.isArray(res) && !root.allLoaded)
                root.allTools = res;
        });
    }

    property bool allLoaded: false
    property bool _loading: false
    property var _waiters: []

    // Tools of every enabled server (starts their processes once).
    function loadAll(cb) {
        if (allLoaded) {
            cb();
            return;
        }
        _waiters = _waiters.concat([cb]);
        if (_loading)
            return;
        _loading = true;
        BackendService.call("mcp.all_tools", {}, (res, err) => {
            root._loading = false;
            if (!err && Array.isArray(res)) {
                root.allTools = res;
                root.allLoaded = true;
            }
            const w = root._waiters;
            root._waiters = [];
            for (const f of w)
                f();
        });
    }

    function serverTools(name, cb) {
        BackendService.call("mcp.tools", {
            server: name
        }, (res, err) => cb(Array.isArray(res) ? res : [], err || ""));
    }

    function setEnabled(name, enabled) {
        const list = (Config.ai.mcp.disabled || []).filter(n => n !== name);
        if (!enabled)
            list.push(name);
        Config.ai.mcp.disabled = list;
    }

    function isEnabled(name) {
        return (Config.ai.mcp.disabled || []).indexOf(name) < 0;
    }

    function _apiName(server, tool) {
        const raw = server === "yozakura" ? tool : server + "__" + tool;
        return raw.replace(/[^A-Za-z0-9_-]/g, "_").substring(0, 64);
    }

    // Tool definitions for a ChatSession. scope: "all" | "yozakura"
    function toolsFor(scope) {
        const out = [];
        for (const t of allTools) {
            if (scope === "yozakura" && t.server !== "yozakura")
                continue;
            out.push({
                name: _apiName(t.server, t.name),
                description: t.description || "",
                parameters: t.inputSchema || {
                    type: "object",
                    properties: {}
                },
                server: t.server,
                tool: t.name,
                annotations: Object.assign({}, t.annotations || {}, t.readOnly ? {
                    readOnlyHint: true
                } : {})
            });
        }
        return out;
    }

    function call(server, tool, args, cb) {
        BackendService.call("mcp.call", {
            server: server,
            tool: tool,
            arguments: args || {}
        }, (res, err) => {
            if (err)
                cb({
                    text: String(err),
                    isError: true
                });
            else
                cb({
                    text: res ? (res.text || "") : "",
                    isError: !!(res && res.isError)
                });
        });
    }
}
