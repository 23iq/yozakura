"""An AI's routine_run of a routine with confirm-required steps (closing
windows, keybind edits, command lines) always asks, offers no "for
session", and the shell grants that one run (routines.grant) before the
call; a harmless routine follows the policy."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-chat-routine-confirm")
h.module("qs.modules.services", {
    "I18n": '''pragma Singleton
import QtQuick
QtObject { function t(key) { return key } }''',
    "RoutinesService": '''pragma Singleton
import QtQuick
QtObject {
    property var routines: [
        {id: "closer", name: "Closer", steps: [{kind: "tool", tool: "app_close", args: {app: "x"}}]},
        {id: "calm", name: "Calm", steps: [{kind: "tool", tool: "dnd_set", args: {enabled: true}}]}
    ]
}''',
    "BackendService": '''pragma Singleton
import QtQuick
QtObject {
    property var calls: []
    function call(method, params, cb) { calls = calls.concat([{method: method, params: params}]); if (cb) cb({}, null); }
}''',
})
path = h.copy("modules/services/ai/ChatSession.qml", dest="modules/services/ai")
(path.parent / "ChatRequest.qml").write_text('''import QtQuick
QtObject {
    property var model
    property string apiKey
    property string customCurl
    property string system
    property var messages
    property var tools
    property string effort
    property int numCtx
    property string usageSession
    property string usageSpace
    signal delta(string text, string thinking)
    signal finished(var result)
    function start() {}
    function abort() {}
}''')
obj = h.load(path)
h.eval(obj, """
    tools = [{name: 'yozakura__routine_run', server: 'yozakura', tool: 'routine_run', annotations: {}}];
    policy = {yolo: true, autoApprove: ['read', 'mcp']};
    busy = true;
    callTool = (server, tool, args, cb) => {
        BackendService.calls = BackendService.calls.concat([{method: 'tool:' + tool, params: args}]);
        cb({text: '{}', isError: false});
    };
    append({role: 'assistant', content: '', status: 'done', toolCalls: [
        {id: 'a', name: 'yozakura__routine_run', server: 'yozakura', tool: 'routine_run', args: {id: 'closer'}, status: 'pending'},
        {id: 'b', name: 'yozakura__routine_run', server: 'yozakura', tool: 'routine_run', args: {id: 'calm'}, status: 'pending'}]});
    _processTools(0);
""")


def calls():
    return json.loads(h.eval(obj, "JSON.stringify(BackendService.calls)"))


def call_state():
    return {c["id"]: c for c in json.loads(h.eval(obj, "rows.get(0).toolCalls"))}


state = call_state()
assert state["a"]["status"] == "ask" and state["a"]["confirm"] is True, state["a"]
assert state["b"]["status"] == "done", "a harmless routine follows YOLO"
assert [c["method"] for c in calls()] == ["tool:routine_run"]
h.eval(obj, "respond(0, 'a', 'allow_session')")
assert [c["method"] for c in calls()] == ["tool:routine_run", "routines.grant", "tool:routine_run"], calls()
assert calls()[1]["params"] == {"id": "closer"}
assert call_state()["a"]["status"] == "done"
assert h.eval(obj, "JSON.stringify(_sessionRules)") == "{}", "a confirm call never becomes a session rule"
print("ai-chat-routine-confirm: ok")
h.exit(0)
