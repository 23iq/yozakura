import QtQuick
import qs.modules.services
import "Providers.js" as Providers
import "Permissions.js" as Permissions
import "ChatRows.js" as ChatRows
import "ToolMedia.js" as ToolMedia
import "ContextMath.js" as ContextMath
import "../../aicenter/lib/Markdown.js" as Markdown

// A conversation with an API/local model, including the MCP tool loop.
// `rows` (ListModel) is what the UI renders; complex fields are JSON strings
// so a streamed token updates a single row:
//   role: user|assistant|notice|error|summary ; content ; thinking ; model ; status
//   signature: Anthropic thinking signature (sent back in tool loops)
//   summary rows replace everything before them in requests (compaction)
//   attachments: JSON [{type, mimeType, base64, name, kind, text}]
//   toolCalls:   JSON [{id, name, server, tool, args, title, category, status, result, isError}]
//                status: pending|ask|running|done|denied|error
QtObject {
    id: root

    property string chatId: Date.now().toString()
    property string title: ""
    property bool pinned: false
    property string mode: "chat"          // chat | quick | oneshot (legacy files: shell = chat)
    property double created: Date.now()
    property double updated: created
    property string engineId: ""
    property var model: null              // catalog entry {provider, model, name, ...}
    property string apiKey: ""
    property string customCurl: ""
    property string system: ""
    property var tools: []                // [{name (api name), description, parameters, server, tool, annotations}]
    property var policy: ({
            autoApprove: ["read"]
        })
    property int maxRounds: 8
    property bool persist: true
    // Unified effort level (Effort.js) and Ollama num_ctx for requests.
    property string effort: ""
    property int numCtx: 0
    // Conversation size after the last turn (prompt + answer tokens) and
    // the last request's usage {inputTokens, outputTokens, cachedTokens}.
    property int contextTokens: 0
    property var lastUsage: null
    property bool compacting: false

    // Wired by the owner: call(server, tool, args, cb(result {text, isError, images}))
    property var callTool: null
    // Images returned by tool calls ({callId: [attachments]}), in memory
    // only: sent to vision models after the tool results (ToolMedia.js).
    property var toolImages: ({})

    property ListModel rows: ListModel {}
    property bool busy: false
    property int pendingApprovals: 0
    property var _request: null
    property int _round: 0
    property int _generation: 0
    property var _sessionRules: ({})

    signal changed
    signal saveRequested(var data)
    signal turnFinished(string text, string error)

    readonly property Component requestFactory: Component {
        ChatRequest {}
    }

    function clear() {
        stop();
        rows.clear();
        chatId = Date.now().toString();
        title = "";
        pinned = false;
        created = Date.now();
        contextTokens = 0;
        lastUsage = null;
        _sessionRules = {};
        changed();
    }

    function _json(v) {
        try {
            return JSON.stringify(v === undefined ? null : v);
        } catch (e) {
            return "null";
        }
    }

    function _parse(s, fallback) {
        if (!s)
            return fallback;
        try {
            return JSON.parse(s);
        } catch (e) {
            return fallback;
        }
    }

    function _rowData(row) {
        return {
            role: row.role || "notice",
            content: row.content || "",
            thinking: row.thinking || "",
            signature: row.signature || "",
            model: row.model || "",
            status: row.status || "",
            attachments: _json(row.attachments || []),
            toolCalls: _json(row.toolCalls || []),
            ts: row.ts || Date.now()
        };
    }

    function append(row) {
        rows.append(_rowData(row));
        return rows.count - 1;
    }

    // Compaction result: a summary row at `index` stands in for every row
    // before it in later requests (the rows stay visible).
    function insertSummary(index, text) {
        rows.insert(Math.max(0, Math.min(index, rows.count)), _rowData({
            role: "summary",
            content: text
        }));
        contextTokens = ContextMath.estimateTokens(toMessages(), system);
        _save();
    }

    function notice(text) {
        append({
            role: "notice",
            content: text
        });
    }

    function _rows() {
        const out = [];
        for (let i = 0; i < rows.count; i++)
            out.push(rows.get(i));
        return out;
    }

    // Canonical conversation for the provider (expands tool results).
    function toMessages() {
        const see = ToolMedia.canSee(model, model ? Providers.provider(model.provider) : null);
        return ChatRows.toMessages(_rows(), {
            images: see ? toolImages : null
        });
    }

    function serialize() {
        return {
            version: 2,
            id: chatId,
            title: title,
            pinned: pinned,
            mode: mode,
            model: engineId || (model ? model.id : ""),
            contextTokens: contextTokens,
            created: created,
            updated: Date.now(),
            messages: ChatRows.toStored(_rows())
        };
    }

    function load(data) {
        stop();
        rows.clear();
        chatId = data.id || chatId;
        title = data.title || "";
        pinned = !!data.pinned;
        created = data.created || Date.now();
        updated = data.updated || created;
        engineId = data.model || "";
        contextTokens = data.contextTokens || 0;
        lastUsage = null;
        for (const row of ChatRows.fromStored(data))
            append(row);
        changed();
    }

    function send(text, attachments) {
        if (busy || compacting || (!text.trim() && (!attachments || attachments.length === 0)))
            return false;
        if (!title)
            title = Markdown.preview(text, 48);
        append({
            role: "user",
            content: text,
            attachments: attachments || []
        });
        _round = 0;
        _startRound();
        return true;
    }

    function retry(index) {
        if (busy || compacting || index < 0 || index >= rows.count)
            return;
        let cut = index;
        while (cut > 0 && rows.get(cut).role !== "user")
            cut--;
        if (rows.get(cut).role === "user")
            cut++;
        rows.remove(cut, rows.count - cut);
        _round = 0;
        _startRound();
    }

    function editMessage(index, text) {
        if (index < 0 || index >= rows.count)
            return;
        rows.setProperty(index, "content", text);
        _save();
    }

    function stop() {
        _generation++;
        const request = _request;
        _request = null;
        if (request)
            request.abort();
        for (let i = 0; i < rows.count; i++) {
            const calls = _parse(rows.get(i).toolCalls, []);
            let touched = false;
            for (const c of calls) {
                if (c.status === "ask" || c.status === "pending") {
                    c.status = "denied";
                    c.result = "Cancelled by the user.";
                    touched = true;
                }
            }
            if (touched)
                rows.setProperty(i, "toolCalls", _json(calls));
        }
        pendingApprovals = 0;
        busy = false;
        _save();
    }

    function _startRound() {
        if (!model) {
            append({
                role: "error",
                content: "No model selected"
            });
            return;
        }
        busy = true;
        _round++;
        const index = append({
            role: "assistant",
            content: "",
            model: model.name,
            status: "streaming"
        });
        const req = requestFactory.createObject(root, {
            model: model,
            apiKey: apiKey,
            customCurl: customCurl,
            system: system,
            effort: effort,
            numCtx: numCtx,
            usageSession: chatId,
            messages: toMessages(),
            tools: _round <= maxRounds ? tools.map(t => ({
                        name: t.name,
                        description: t.description,
                        parameters: t.parameters
                    })) : []
        });
        _request = req;
        const generation = _generation;
        req.delta.connect((text, thinking) => {
            if (generation !== _generation || _request !== req)
                return;
            const r = rows.get(index);
            if (text)
                rows.setProperty(index, "content", r.content + text);
            if (thinking)
                rows.setProperty(index, "thinking", r.thinking + thinking);
        });
        req.finished.connect(result => {
            if (generation !== _generation || _request !== req) {
                req.destroy();
                return;
            }
            _request = null;
            req.destroy();
            rows.setProperty(index, "status", "");
            if (result.signature)
                rows.setProperty(index, "signature", result.signature);
            _trackContext(result.usage);
            if (result.error) {
                busy = false;
                if (!rows.get(index).content)
                    rows.remove(index);
                append({
                    role: "error",
                    content: result.error
                });
                turnFinished("", result.error);
                _save();
                return;
            }
            if (result.aborted) {
                busy = false;
                _save();
                turnFinished(rows.get(index).content, "");
                return;
            }
            const calls = (result.toolCalls || []).map(c => _describeCall(c));
            if (calls.length > 0) {
                rows.setProperty(index, "toolCalls", _json(calls));
                _processTools(index);
            } else {
                busy = false;
                _save();
                turnFinished(rows.get(index).content, "");
            }
        });
        req.start();
    }

    // Ollama reports only the tokens it had to evaluate (cached prefixes
    // are not counted), so an estimate of the conversation is the floor.
    function _trackContext(usage) {
        if (usage)
            lastUsage = usage;
        const estimate = ContextMath.estimateTokens(toMessages(), system);
        const reported = ContextMath.usedFromUsage(usage);
        contextTokens = reported > 0 ? (model && model.provider === "ollama" ? Math.max(reported, estimate) : reported) : estimate;
    }

    function _toolDef(name) {
        for (const t of tools)
            if (t.name === name)
                return t;
        return null;
    }

    function _describeCall(c) {
        const def = _toolDef(c.name);
        const info = def ? {
            name: def.tool,
            server: def.server,
            annotations: def.annotations
        } : {
            name: c.name
        };
        return {
            id: c.id,
            name: c.name,
            args: c.args,
            server: def ? def.server : "",
            tool: def ? def.tool : c.name,
            title: Permissions.summarize(def ? def.tool : c.name, c.args, (key, values) => I18n.t.apply(I18n, [key].concat(values)), def ? def.server : ""),
            category: Permissions.category(info),
            status: "pending",
            result: "",
            isError: false
        };
    }

    function _processTools(index) {
        const calls = _parse(rows.get(index).toolCalls, []);
        let waiting = 0;
        for (const c of calls) {
            if (c.status !== "pending")
                continue;
            // Calls that always ask get a card without "for session".
            c.confirm = Permissions.mustConfirm({
                name: c.tool,
                server: c.server
            });
            const def = _toolDef(c.name);
            if (!def) {
                c.status = "error";
                c.isError = true;
                c.result = "Unknown tool: " + c.name;
                continue;
            }
            const decision = Permissions.decide({
                name: def.tool,
                server: def.server,
                annotations: def.annotations
            }, Object.assign({}, policy, {
                sessionRules: _sessionRules
            }));
            if (decision === "allow")
                _runCall(index, c.id);
            else {
                c.status = "ask";
                waiting++;
            }
        }
        rows.setProperty(index, "toolCalls", _json(_merge(index, calls)));
        pendingApprovals = _countAsk();
        _maybeContinue(index);
    }

    // Keeps statuses already advanced by async calls when writing back a list.
    function _merge(index, calls) {
        const current = _parse(rows.get(index).toolCalls, []);
        return calls.map(c => {
            const cur = current.find(x => x.id === c.id);
            return cur && (cur.status === "running" || cur.status === "done" || cur.status === "error") && c.status !== "denied" ? cur : c;
        });
    }

    function _countAsk() {
        let n = 0;
        for (let i = 0; i < rows.count; i++)
            for (const c of _parse(rows.get(i).toolCalls, []))
                if (c.status === "ask")
                    n++;
        return n;
    }

    function _setCall(index, id, fields) {
        const calls = _parse(rows.get(index).toolCalls, []);
        for (const c of calls)
            if (c.id === id)
                Object.assign(c, fields);
        rows.setProperty(index, "toolCalls", _json(calls));
        return calls;
    }

    function _runCall(index, id) {
        const generation = _generation;
        const calls = _setCall(index, id, {
            status: "running"
        });
        const c = calls.find(x => x.id === id);
        if (!callTool) {
            _setCall(index, id, {
                status: "error",
                isError: true,
                result: "Tools are unavailable (backend not connected)."
            });
            _maybeContinue(index);
            return;
        }
        callTool(c.server, c.tool, c.args || {}, res => {
            if (generation !== _generation)
                return;
            const text = res ? String(res.text || "") : "";
            const failed = !!(res && res.isError);
            if (res && res.images && res.images.length)
                toolImages = Object.assign({}, toolImages, {
                    [id]: res.images
                });
            _setCall(index, id, {
                status: failed ? "error" : "done",
                isError: failed,
                result: text,
                undo: ToolMedia.undoFrom(c.server, text, failed)
            });
            _maybeContinue(index);
        });
    }

    // decision: allow | allow_session | deny
    function respond(index, id, decision) {
        const calls = _parse(rows.get(index).toolCalls, []);
        const c = calls.find(x => x.id === id);
        if (!c || c.status !== "ask")
            return;
        if (decision === "deny") {
            _setCall(index, id, {
                status: "denied",
                isError: true,
                result: "The user denied this tool call."
            });
        } else {
            if (decision === "allow_session")
                _sessionRules[Permissions.ruleKey({
                        server: c.server,
                        name: c.tool
                    })] = true;
            _runCall(index, id);
            // Session rule may unlock other waiting calls of the same tool.
            if (decision === "allow_session")
                for (const other of calls)
                    if (other.id !== id && other.status === "ask" && other.tool === c.tool && other.server === c.server)
                        _runCall(index, other.id);
        }
        pendingApprovals = _countAsk();
        _maybeContinue(index);
    }

    function _maybeContinue(index) {
        const calls = _parse(rows.get(index).toolCalls, []);
        if (calls.some(c => c.status === "pending" || c.status === "running" || c.status === "ask"))
            return;
        if (!busy)
            return;
        if (_round >= maxRounds) {
            busy = false;
            notice("Stopped after " + maxRounds + " tool rounds.");
            _save();
            return;
        }
        _startRound();
    }

    function _save() {
        updated = Date.now();
        changed();
        if (persist && rows.count > 0)
            saveRequested(serialize());
    }
}
