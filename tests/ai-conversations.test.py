"""Independent conversations and stale transport responses through real QML services."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-conversations")
h.copy("modules/services/ai/ConversationSessions.qml")
obj = h.load('''import QtQuick
Item {
    property Component factory: Component {
        QtObject {
            property string chatId: ""
            property string mode: "chat"
            property string engineId: ""
            property bool busy: false
            property string title: ""
            property bool pinned: false
            property double created: 0
            signal changed
            function load(data) { title = data.title || ""; }
            function stop() { busy = false; }
        }
    }
    ConversationSessions {
        id: pool
        objectName: "pool"
        makeSession: (kind, persist) => factory.createObject(parent, { mode: kind })
    }
}''')
pool = h.find(obj, "pool")

h.eval(pool, "newSession('chat', true, 'openai:a'); active.busy = true; active.title = 'Running'")
first = h.eval(pool, "active.chatId")
h.eval(pool, "newSession('chat', true, 'ollama:b')")
second = h.eval(pool, "active.chatId")
assert first != second, "new conversations need unique identities"
assert h.eval(pool, "sessions[0].busy"), "selecting another chat must preserve running work"
h.eval(pool, f"select('{first}')")
assert h.eval(pool, "active.title") == "Running"
h.eval(pool, f"setDraft('{first}', 'first draft', [{{type:'text',text:'context'}}]); setDraft('{second}', 'second draft', [])")
assert h.eval(pool, f"draft('{first}').text") == "first draft"
assert h.eval(pool, f"draft('{second}').text") == "second draft"
h.eval(pool, f"setScroll('{first}', 120); setScroll('{second}', 30)")
assert h.eval(pool, f"scroll('{first}')") == 120
assert h.eval(pool, f"scroll('{second}')") == 30
h.eval(pool, f"open({{id:'{first}', model:'wrong', title:'Stale disk'}})")
assert h.eval(pool, "active.title") == "Running", "disk reload must not overwrite live work"
h.eval(pool, f"setDraft('chat:{first}', 'removed draft', []); setScroll('chat:{first}', 99)")
h.eval(pool, f"setDraft('chat:{second}', 'kept draft', []); remove('{first}')")
assert h.eval(pool, f"draft('chat:{first}').text") == "", "remove must clear the actual UI draft key"
assert h.eval(pool, f"scroll('chat:{first}')") == 0
assert h.eval(pool, f"draft('{first}').text") == "", "clear legacy draft keys too"
assert h.eval(pool, f"draft('chat:{second}').text") == "kept draft"
assert h.eval(pool, "active === null") is True, "facade decides the visible replacement without switching an agent"
assert h.eval(pool, "sessions.length") == 1
print("ai-conversations: ok")
h.exit(0)
