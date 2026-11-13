"""ConfigFile.qml: a file replaced on disk while an edit waits for its write.

A cancelled preset edit or a reverted trial has the backend put back the
config from before the session. An edit still waiting for its coalesced
write when that lands is merged into the restored file (onFileChanged), so
the cancelled edit would come back. flushPending() (Config.flushWrites,
called by PresetStudio before such a command) writes it first: the restore
then replaces it and nothing writes it again. FileView is stubbed as in
config-file-merge.test.py; the test plays the disk and the backend.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

failures: list[str] = []


def check(ok, msg):
    print(("PASS " if ok else "FAIL ") + msg)
    if not ok:
        failures.append(msg)


h = Harness("config-file-restore")
h.module("Quickshell.Io", {
    "Process": """QtObject {
    property var command: []
    property bool running: false
    signal exited(int exitCode, int exitStatus)
}""",
    "FileViewError": "QtObject { enum Value { Success, Unknown, FileNotFound, PermissionDenied, NotAFile } }",
    "FileView": """QtObject {
    property string path
    property bool atomicWrites
    property bool watchChanges
    property QtObject adapter
    property string content: ""
    property int writes: 0
    signal loaded
    signal loadFailed(var error)
    signal fileChanged
    signal adapterUpdated
    function text() { return content; }
    function setText(t) { content = t; }
    function reload() {}
    function writeAdapter() {
        writes++;
        content = JSON.stringify({ "roundness": adapter.roundness, "font": adapter.font });
    }
}""",
})
h.copy("config/JsonUtil.js")
h.copy("config/JsonUtil.js", dest="config")
h.copy("config/ConfigMerge.js")
h.copy("config/ConfigFile.qml")

SCENE = """import QtQuick
QtObject {
    id: store
    property string configDir: "/cfg"
    property string presetDir: "/preset"
    property int autoSaveDelay: 100000
    function autoSavePausedFor(name) { return false; }
    property ConfigFile theme: ConfigFile {
        store: store; name: "theme"
        adapter: QtObject { property int roundness: 0; property string font: "" }
        defaults: ({ "roundness": 0, "font": "" })
    }
    // The file on disk becomes `obj` (another process, the backend's restore):
    // its watcher fires, the reload it asks for lands.
    function replace(obj) {
        theme.content = JSON.stringify(obj);
        theme.fileChanged();
        theme.adapter.roundness = obj.roundness;
        theme.adapter.font = obj.font;
        theme.loaded();
    }
    function edit(r) { theme.adapter.roundness = r; theme.adapterUpdated(); }
}"""

BEFORE = "{ roundness: 8, font: 'Inter' }"

s = h.load(SCENE, auto_stub=False)
f = h.eval(s, "theme")
h.eval(f, "content = JSON.stringify(%s); adapter.roundness = 8; adapter.font = 'Inter'; loaded()" % BEFORE)
check(h.eval(f, "ready") is True, "loaded")

# What goes wrong without a flush: the restore lands under a waiting edit.
h.eval(s, "edit(20)")
check(h.eval(f, "saveTimer.running") is True, "the edit waits for its coalesced write")
h.eval(s, "replace(%s)" % BEFORE)
check(h.eval(f, "adapter.roundness") == 20, "unflushed, the waiting edit is merged over the restored file")
h.eval(f, "flushPending()")
check('"roundness":20' in h.eval(f, "content"), "...and written back: the cancel did not stick")

# The fix: flush first (PresetStudio.beforeRestore -> Config.flushWrites).
h.eval(s, "replace(%s)" % BEFORE)
h.eval(s, "edit(24)")
w0 = h.eval(f, "writes")
h.eval(f, "flushPending()")
check(h.eval(f, "writes") == w0 + 1 and '"roundness":24' in h.eval(f, "content"), "flushPending writes the waiting edit now")
check(h.eval(f, "saveTimer.running") is False, "...and nothing waits any more")
h.eval(s, "replace(%s)" % BEFORE)
check(h.eval(f, "adapter.roundness") == 8, "the restore then wins")
check(h.eval(f, "saveTimer.running") is False and h.eval(f, "writes") == w0 + 1,
      "...and nothing writes the cancelled edit again")
h.eval(f, "flushPending()")
check(h.eval(f, "writes") == w0 + 1, "flushPending with nothing waiting writes nothing")

if failures:
    print(f"config-file-restore: {len(failures)} failure(s)")
    sys.exit(1)
print("config-file-restore: ok")
