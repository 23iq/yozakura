"""A cancelled transport cannot write into a cleared or restarted conversation."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-chat-cancel")
h.module("qs.modules.services", {"I18n": '''pragma Singleton
import QtQuick
QtObject { function t(key) { return key } }'''})
path = h.copy("modules/services/ai/ChatSession.qml", dest="modules/services/ai")
(path.parent / "ChatRequest.qml").write_text('''import QtQuick
QtObject {
    property var model
    property string apiKey
    property string customCurl
    property string system
    property var messages
    property var tools
    signal delta(string text, string thinking)
    signal finished(var result)
    function start() {}
    function abort() {}
}''')
obj = h.load(path)
h.eval(obj, "model = {id:'openai:test', name:'test', provider:'openai',model:'test'}; send('first', [])")
h.eval(obj, "var old = _request; stop(); clear(); send('second', []); old.delta('stale', ''); old.finished({text:'stale',toolCalls:[]})")
assert h.eval(obj, "rows.count") == 2
assert h.eval(obj, "rows.get(1).content") == "", "late deltas must not enter the new reply"
assert h.eval(obj, "busy"), "old completion must not end the new request"
print("ai-chat-cancel: ok")
h.exit(0)
