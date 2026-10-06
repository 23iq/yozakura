import QtQuick
import qs.modules.services

// A minimal-profile CLI exchange with the same rows/signals as an HTTP chat.
QtObject {
    id: root

    property var owner
    property var model
    property string chatId: ""
    property string engineId: model ? model.id : ""
    property string system: ""
    property string cwd: ""
    property string nativeModel: ""
    property string effort: ""
    property bool busy: false
    property bool persist: true
    property string title: ""
    property string mode: "oneshot"
    property var rows: ListModel {}
    property string _sessionId: ""
    property int _reply: -1
    property bool _disposed: false
    property int _generation: 0
    property bool _stopping: false

    signal changed
    signal turnFinished(string text, string error)

    function fail(message) {
        if (!busy)
            return;
        rows.append({
            role: "error",
            content: message,
            thinking: "",
            toolCalls: "[]",
            attachments: "[]",
            model: ""
        });
        busy = false;
        changed();
        turnFinished("", message);
    }

    function send(text, attachments) {
        if (busy || _stopping || !owner || !model)
            return false;
        const info = owner.agents.find(a => a.id === model.agent);
        const input = owner.prepareInput(text, attachments, info ? info.capabilities : null);
        if (input.error)
            return false;
        rows.append({
            role: "user",
            content: text,
            thinking: "",
            toolCalls: "[]",
            attachments: JSON.stringify(attachments || []),
            model: ""
        });
        title = title || text.substring(0, 60);
        _reply = rows.count;
        rows.append({
            role: "assistant",
            content: "",
            thinking: "",
            toolCalls: "[]",
            attachments: "[]",
            model: model.name
        });
        busy = true;
        const generation = ++_generation;
        const submit = id => owner.send(id, input.prompt, input.images, (res, err) => {
                if (err && generation === _generation && !_disposed)
                    fail(String(err));
            });
        if (_sessionId) {
            submit(_sessionId);
        } else {
            owner.create(model.agent, cwd, {
                mode: "oneshot",
                model: nativeModel,
                effort: effort,
                systemPrompt: system,
                activate: false,
                yolo: false,
                onCreated: meta => {
                    if (_disposed || generation !== _generation) {
                        owner.close(meta.id);
                        return;
                    }
                    _sessionId = meta.id;
                    chatId = meta.id;
                    if (busy)
                        submit(meta.id);
                },
                onError: error => {
                    if (generation === _generation && !_disposed)
                        fail(String(error));
                }
            });
        }
        return true;
    }

    function stop() {
        ++_generation;
        _stopping = !!_sessionId && busy;
        busy = false;
        changed();
        if (_sessionId)
            owner.cancel(_sessionId);
    }

    property Connections events: Connections {
        target: root.owner
        function onEventReceived(ev) {
            if (ev.session !== root._sessionId)
                return;
            if (ev.kind === "status" && (ev.status === "idle" || ev.status === "exited"))
                root._stopping = false;
            if (!root.busy)
                return;
            if (ev.kind === "text" || ev.kind === "thinking") {
                const field = ev.kind === "text" ? "content" : "thinking";
                const before = root.rows.get(root._reply)[field];
                root.rows.setProperty(root._reply, field, ev.delta ? before + (ev.text || "") : (ev.text || ""));
                root.changed();
            } else if (ev.kind === "error") {
                root.fail(ev.message || ev.text || "Agent request failed");
            } else if (ev.kind === "done") {
                root.busy = false;
                root.changed();
                root.turnFinished(root.rows.get(root._reply).content, "");
            }
        }
    }

    Component.onDestruction: {
        _disposed = true;
        ++_generation;
        if (_sessionId && busy)
            owner.cancel(_sessionId);
    }
}
