"""Rapid history selection and edits keep their own file identities."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-chat-store")
h.module("Quickshell", {"Placeholder": "QtObject {}"})
h.module("qs.modules.globals", {})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property bool running: false; property QtObject stdout; signal exited(int exitCode, int exitStatus) }",
    "StdioCollector": "QtObject { property string text; signal streamFinished() }",
    "FileView": "QtObject { property string path; property bool atomicWrites; property bool blockWrites; property bool printErrors; property var writes: []; function setText(text) { writes = writes.concat([{path: path, text: text}]); } }",
})
h.copy("modules/services/ai/ChatStore.qml", siblings=False)
root = h.load('''Item {
    id: host
    property var loaded: []
    ChatStore {
        objectName: "store"
        onLoaded: (id, data) => host.loaded = host.loaded.concat([{id: id, title: data.title}])
    }
}''', auto_stub=False)
store = h.find(root, "store")
h.eval(store, "load('first'); load('second')")
# The second selection must not relabel the running first load.
h.eval(store, 'reader.stdout.text = \'{"id":"first","title":"First"}\'; reader.stdout.streamFinished()')
assert h.eval(root, "loaded.length") == 0
h.eval(store, "reader.running = false; reader.exited(0, 0)")
h.app.processEvents()
assert h.eval(store, "reader.command[1].endsWith('/second.json')") is True
h.eval(store, 'reader.stdout.text = \'{"id":"second","title":"Second"}\'; reader.stdout.streamFinished()')
assert h.eval(root, "JSON.stringify(loaded)") == '[{"id":"second","title":"Second"}]'
h.eval(store, "reader.running = false; reader.exited(0, 0)")
h.app.processEvents()
# Pin and rename rapidly, including two edits to the same file.
h.eval(store, "setPinned('first', true); rename('second', 'Renamed'); rename('first', 'Latest')")
h.eval(store, 'pinner.stdout.text = \'{"id":"first","title":"First"}\'; pinner.stdout.streamFinished()')
assert h.eval(store, "JSON.parse(writer.writes[0].text).pinned") is True
h.eval(store, "pinner.running = false; pinner.exited(0, 0)")
h.app.processEvents()
assert h.eval(store, "pinner.command[1].endsWith('/second.json')") is True
h.eval(store, 'pinner.stdout.text = \'{"id":"second","title":"Second"}\'; pinner.stdout.streamFinished()')
assert h.eval(store, "JSON.parse(writer.writes[1].text).title") == "Renamed"
h.eval(store, "pinner.running = false; pinner.exited(0, 0)")
h.app.processEvents()
assert h.eval(store, "pinner.command[1].endsWith('/first.json')") is True
h.eval(store, 'pinner.stdout.text = \'{"id":"first","title":"First","pinned":true}\'; pinner.stdout.streamFinished()')
assert h.eval(store, "JSON.parse(writer.writes[2].text).title") == "Latest"
assert h.eval(store, "JSON.parse(writer.writes[2].text).pinned") is True
print("PASS: history load identity and queued pin/rename edits")
