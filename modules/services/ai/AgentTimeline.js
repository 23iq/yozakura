.pragma library
.import "ToolMedia.js" as ToolMedia

// Reduces normalized agent events (backend/pkg/svc/agents, see Event) into UI
// blocks. The reducer is incremental: apply() returns operations the QML side
// applies to a ListModel, so streaming a token touches one row only.
//
// Block (flat, ListModel friendly):
//   {type: user|assistant|thinking|tool|permission|diff|error|notice,
//    key, text, tool, title, category, status, input (JSON string), output,
//    isError, path, diff, options (JSON string), decision, undo (JSON string), ts}
// tool.status: running|done|error|denied ; permission.status: pending|allowed|denied

function newState() {
    return {
        blocks: [],
        byKey: {},
        openText: -1,       // index of the assistant block receiving deltas
        openThinking: -1,
        lastSeq: 0,
        status: "idle",
        usage: null,
        pending: 0,         // unresolved permission requests
        diffs: [],          // [{path, diff, key}] latest diff per path (wide-mode pane)
        diffIndex: {}
    };
}

function _block(type, fields) {
    var b = {
        type: type, key: "", text: "", tool: "", title: "", category: "", status: "",
        input: "", output: "", isError: false, path: "", diff: "", options: "", decision: "", linked: false, undo: "", ts: 0
    };
    for (var k in fields)
        if (fields[k] !== undefined && fields[k] !== null)
            b[k] = fields[k];
    return b;
}

function _json(v) {
    if (v === undefined || v === null || v === "")
        return "";
    if (typeof v === "string")
        return v;
    try {
        return JSON.stringify(v);
    } catch (e) {
        return "";
    }
}

function _append(state, ops, block) {
    state.blocks.push(block);
    var index = state.blocks.length - 1;
    if (block.key)
        state.byKey[block.key] = index;
    ops.push({ op: "append", index: index, block: block });
    return index;
}

function _update(state, ops, index, fields) {
    var b = state.blocks[index];
    for (var k in fields)
        b[k] = fields[k];
    ops.push({ op: "update", index: index, fields: fields });
}

function _closeStreams(state) {
    state.openText = -1;
    state.openThinking = -1;
}

function _addDiff(state, path, diff, key) {
    var p = path || "";
    if (state.diffIndex[p] !== undefined) {
        state.diffs[state.diffIndex[p]] = { path: p, diff: diff, key: key || "" };
    } else {
        state.diffIndex[p] = state.diffs.length;
        state.diffs.push({ path: p, diff: diff, key: key || "" });
    }
}

// Returns {ops: [...], resync: bool, statusChanged: bool}
function apply(state, ev) {
    var ops = [];
    var result = { ops: ops, resync: false, statusChanged: false, diffsChanged: false };
    if (!ev || !ev.kind)
        return result;
    if (ev.seq) {
        if (ev.seq <= state.lastSeq)
            return result; // duplicate (replayed history overlapping the live stream)
        if (state.lastSeq > 0 && ev.seq > state.lastSeq + 1)
            result.resync = true;
        state.lastSeq = ev.seq;
    }
    var ts = ev.ts || 0;
    switch (ev.kind) {
    case "user":
        _closeStreams(state);
        _append(state, ops, _block("user", { text: ev.text || "", ts: ts }));
        break;
    case "text":
    case "thinking": {
        var isText = ev.kind === "text";
        var open = isText ? state.openText : state.openThinking;
        var type = isText ? "assistant" : "thinking";
        if (open >= 0 && open === state.blocks.length - 1) {
            var current = state.blocks[open].text;
            _update(state, ops, open, { text: ev.delta ? current + (ev.text || "") : (ev.text || "") });
        } else {
            var idx = _append(state, ops, _block(type, { text: ev.text || "", status: "streaming", ts: ts }));
            if (isText) {
                state.openText = idx;
                state.openThinking = -1;
            } else {
                state.openThinking = idx;
                state.openText = -1;
            }
        }
        break;
    }
    case "tool_call": {
        _closeStreams(state);
        var key = "tool:" + (ev.id || state.blocks.length);
        var fields = {
            key: key, tool: ev.tool || "", title: ev.title || ev.tool || "", category: ev.category || "other",
            status: "running", input: _json(ev.input), ts: ts
        };
        if (state.byKey[key] !== undefined) {
            _update(state, ops, state.byKey[key], { title: fields.title, input: fields.input, category: fields.category });
        } else {
            _append(state, ops, _block("tool", fields));
        }
        break;
    }
    case "tool_result": {
        var tkey = "tool:" + (ev.id || "");
        var ti = state.byKey[tkey];
        var upd = { output: ev.output || "", isError: !!ev.isError };
        var tname = ti !== undefined ? state.blocks[ti].tool : (ev.tool || "");
        if (ToolMedia.isYozakuraTool(tname))
            upd.undo = _json(ToolMedia.undoFrom("yozakura", upd.output, upd.isError));
        if (ti !== undefined) {
            if (state.blocks[ti].status !== "denied")
                upd.status = ev.isError ? "error" : "done";
            var pi = state.byKey["perm:" + (ev.id || "")];
            if (pi !== undefined && state.blocks[pi].status === "pending") {
                state.pending = Math.max(0, state.pending - 1);
                _update(state, ops, pi, { status: ev.isError ? "denied" : "allowed" });
            }
            _update(state, ops, ti, upd);
        } else {
            _append(state, ops, _block("tool", {
                key: tkey, tool: ev.tool || "", title: ev.title || ev.tool || "", category: ev.category || "other",
                status: ev.isError ? "error" : "done", output: upd.output, isError: upd.isError, undo: upd.undo || "", ts: ts
            }));
        }
        break;
    }
    case "diff": {
        var dkey = ev.id ? "tool:" + ev.id : "";
        _addDiff(state, ev.path || "", ev.diff || "", dkey);
        result.diffsChanged = true;
        var di = dkey ? state.byKey[dkey] : undefined;
        if (di !== undefined) {
            var prev = state.blocks[di].diff;
            _update(state, ops, di, { diff: prev ? prev + "\n" + (ev.diff || "") : (ev.diff || ""), path: ev.path || state.blocks[di].path });
        } else if (ev.path) {
            _closeStreams(state);
            _append(state, ops, _block("diff", { key: "diff:" + ev.path + ":" + (ev.seq || ts), path: ev.path, diff: ev.diff || "", ts: ts }));
        }
        break;
    }
    case "permission_request": {
        _closeStreams(state);
        var pkey = "perm:" + (ev.id || "");
        if (state.byKey[pkey] === undefined) {
            // The card replaces the tool row of the same call while it waits.
            var linkedTool = state.byKey["tool:" + (ev.id || "")];
            if (linkedTool !== undefined)
                _update(state, ops, linkedTool, { status: "ask" });
            var input = ev.input !== undefined ? ev.input : (linkedTool !== undefined ? state.blocks[linkedTool].input : "");
            _append(state, ops, _block("permission", {
                key: pkey, tool: ev.tool || "", title: ev.title || ev.tool || "", category: ev.category || "other",
                status: "pending", input: _json(input), options: _json(ev.options || ["allow", "allow_session", "deny"]),
                path: ev.path || "", diff: ev.diff || "", linked: linkedTool !== undefined, ts: ts
            }));
            state.pending++;
            result.statusChanged = true;
        }
        break;
    }
    case "permission_resolved": {
        var ri = state.byKey["perm:" + (ev.id || "")];
        var allowed = ev.decision === "allow" || ev.decision === "allow_session" || ev.decision === "auto";
        if (ri !== undefined) {
            if (state.blocks[ri].status === "pending")
                state.pending = Math.max(0, state.pending - 1);
            _update(state, ops, ri, { status: allowed ? "allowed" : "denied", decision: ev.decision || "" });
            var ti2 = state.byKey["tool:" + (ev.id || "")];
            if (ti2 !== undefined && state.blocks[ti2].status === "ask")
                _update(state, ops, ti2, { status: allowed ? "running" : "denied", decision: ev.decision || "" });
            result.statusChanged = true;
        } else if (ev.decision === "auto") {
            var ti3 = state.byKey["tool:" + (ev.id || "")];
            if (ti3 !== undefined)
                _update(state, ops, ti3, { decision: "auto" });
        }
        break;
    }
    case "status":
        state.status = ev.status || state.status;
        if (state.status !== "running")
            _closeStreams(state);
        result.statusChanged = true;
        break;
    case "error":
        _closeStreams(state);
        _append(state, ops, _block("error", { text: ev.message || ev.text || "", ts: ts }));
        break;
    case "done":
        _closeStreams(state);
        state.usage = ev.usage || null;
        // A finished turn resolves nothing still pending on the agent side.
        for (var i = 0; i < state.blocks.length; i++) {
            var b = state.blocks[i];
            if (b.type === "tool" && b.status === "running")
                _update(state, ops, i, { status: "done" });
            if (b.type === "assistant" || b.type === "thinking") {
                if (b.status === "streaming")
                    _update(state, ops, i, { status: "" });
            }
        }
        result.statusChanged = true;
        break;
    default:
        break;
    }
    return result;
}

// Replays a full event list into a fresh state (session reload).
function build(events) {
    var state = newState();
    for (var i = 0; i < events.length; i++)
        apply(state, events[i]);
    return state;
}

// Short label for a tool category (used by cards and permission prompts).
function categoryIcon(category) {
    switch (category) {
    case "read":
        return "eye";
    case "write":
        return "pencil";
    case "exec":
        return "terminal";
    case "network":
        return "globe";
    case "mcp":
        return "plug";
    default:
        return "wrench";
    }
}
