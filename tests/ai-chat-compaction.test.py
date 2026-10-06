"""Compaction of a real ChatSession by the real ChatCompactor (stub transport):
the summary row lands before the kept turns, later requests only carry the
summary and the rows after it, the context size is re-estimated, an aborted
compaction reports `aborted`, and the session tracks per-turn context usage."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-chat-compaction")
h.module("qs.modules.services", {"I18n": '''pragma Singleton
import QtQuick
QtObject { function t(key) { return key } }'''})
session = h.copy("modules/services/ai/ChatSession.qml", dest="modules/services/ai")
h.copy("modules/services/ai/ChatCompactor.qml", dest="modules/services/ai")
(session.parent / "ChatRequest.qml").write_text('''import QtQuick
QtObject {
    property var model
    property string apiKey
    property string customCurl
    property string system
    property var messages
    property var tools
    property string effort
    property int numCtx
    signal delta(string text, string thinking)
    signal finished(var result)
    Component.onCompleted: Log.requests = Log.requests.concat([this])
    function start() {}
    function abort() { finished({aborted: true}) }
}''')
(session.parent / "Log.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property var requests: [] }\n")
(session.parent / "qmldir").write_text("singleton Log 1.0 Log.qml\n")
obj = h.load(h.write('''import QtQuick
import "../modules/services/ai"
Item {
    property ChatSession chat: ChatSession { persist: false; effort: "high"; numCtx: 32768 }
    property ChatCompactor compactor: ChatCompactor {}
    property var result: null
    function last() { return Log.requests[Log.requests.length - 1]; }
    function turn(text, answer, usage) {
        chat.send(text, []);
        last().delta(answer, "");
        last().finished({text: answer, toolCalls: [], usage: usage});
    }
    function compact(keep) {
        compactor.run(chat, chat.model, "", "", keep, (ok, err, aborted) => result = {ok: ok, err: err, aborted: !!aborted});
    }
}''', name="Scene.qml"))

h.eval(obj, "chat.model = {id:'openai:gpt-5', name:'gpt-5', provider:'openai', model:'gpt-5'}")
h.eval(obj, "turn('q1', 'a1', {inputTokens: 1000, outputTokens: 50})")
assert h.eval(obj, "last().effort") == "high" and h.eval(obj, "last().numCtx") == 32768, "requests carry effort and num_ctx"
assert h.eval(obj, "chat.contextTokens") == 1050, "context = prompt + answer of the last turn"
h.eval(obj, "turn('q2', 'a2', {inputTokens: 3000, outputTokens: 100})")
h.eval(obj, "turn('q3', 'a3', {inputTokens: 5000, outputTokens: 100})")
assert h.eval(obj, "chat.contextTokens") == 5100

# Abort: nothing changes and the caller knows it was aborted.
h.eval(obj, "compact(1)")
assert h.eval(obj, "chat.compacting") is True
assert h.eval(obj, "chat.send('blocked', [])") is False, "no sending while compacting"
h.eval(obj, "compactor.abort()")
assert h.eval(obj, "result.aborted") is True and h.eval(obj, "chat.compacting") is False
assert h.eval(obj, "chat.rows.count") == 6

# Compaction keeps the last turn and summarises the two before it.
h.eval(obj, "compact(1)")
prompt = h.eval(obj, "last().messages[0].content")
assert "User: q1" in prompt and "Assistant: a2" in prompt and "q3" not in prompt, prompt
assert h.eval(obj, "last().tools.length") == 0
h.eval(obj, "last().finished({text: '- the user plans a trip', toolCalls: []})")
assert h.eval(obj, "result.ok") is True
assert h.eval(obj, "chat.rows.count") == 7
assert h.eval(obj, "chat.rows.get(4).role") == "summary", "summary goes before the kept turn"
assert h.eval(obj, "chat.rows.get(5).content") == "q3"
assert h.eval(obj, "chat.contextTokens") < 100, "context re-estimated after compaction"

# Next request: summary + kept turn + new message only.
h.eval(obj, "chat.send('q4', [])")
msgs = h.eval(obj, "JSON.stringify(last().messages.map(m => m.content))")
assert "the user plans a trip" in msgs and "q1" not in msgs and "q3" in msgs and "q4" in msgs, msgs
print("ai-chat-compaction: ok")
h.exit(0)
