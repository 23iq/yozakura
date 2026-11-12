"""ConfigFile.qml: two processes writing one config file.

With performance.separateWindows the main shell and the Settings window
each hold the same domain (general, ai, ...) and each auto-saves it. An
edit still waiting for its write when the file changes on disk is merged
into the new contents (ConfigMerge.js): this process's changes since it
last read or wrote the file are laid over what the other process wrote,
instead of its whole adapter being written over it. writeMerged() (a
separate window's Apply with no main shell) re-reads the file first and
writes only what this process changed. FileView is stubbed as in
config-file-autosave.test.py; the test plays the disk.
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


h = Harness("config-file-merge")
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
    property int reloads: 0
    property var written: null
    signal loaded
    signal loadFailed(var error)
    signal fileChanged
    signal adapterUpdated
    function text() { return content; }
    function setText(t) { content = t; }
    function reload() { reloads++; }
    function writeAdapter() {
        writes++;
        written = { "model": adapter.model, "count": adapter.count, "sub": { "on": adapter.sub.on }, "map": adapter.map };
        content = JSON.stringify(written);
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
    property var pausedDomains: []
    property int autoSaveDelay: 100000
    property var files: ({})
    function registerFile(name, f) { files[name] = f; }
    function autoSavePausedFor(name) { return pausedDomains.indexOf(name) !== -1; }
    property ConfigFile general: ConfigFile {
        store: store; name: "general"
        adapter: QtObject {
            property string model: ""
            property int count: 0
            property QtObject sub: QtObject { property bool on: false }
            property var map: ({})
        }
        defaults: ({ "model": "", "count": 0, "sub": { "on": false }, "map": {} })
    }
    // The other process wrote `obj`: the reload this file asked for lands.
    function disk(obj) {
        general.content = JSON.stringify(obj);
        general.adapter.model = obj.model;
        general.adapter.count = obj.count;
        general.adapter.sub.on = obj.sub.on;
        general.adapter.map = obj.map;
        general.loaded();
    }
}"""

s = h.load(SCENE, auto_stub=False)
f = h.eval(s, "general")
check(h.eval(s, "files.general === general"), "the file registers itself with the store (Config.configFile)")

h.eval(s, "disk({ model: 'a', count: 1, sub: { on: false }, map: { keep: 1 } })")
check(h.eval(f, "ready") is True, "loaded")
check(h.eval(f, "synced.model") == "a", "the loaded contents are the merge base")

# This process edits model; its write waits (coalescing timer).
h.eval(f, "adapter.model = 'local'; adapterUpdated()")
check(h.eval(f, "saveTimer.running") is True, "the edit waits for its auto-save")

# Meanwhile the other process writes count, sub.on and the map.
r0 = h.eval(f, "reloads")
h.eval(f, "fileChanged()")
check(h.eval(f, "saveTimer.running") is False and h.eval(f, "reloads") == r0 + 1,
      "a change on disk under a waiting edit re-reads the file, the stale write is cancelled")
check(h.eval(f, "writes") == 0, "the whole stale adapter is not written over the other process's change")
h.eval(s, "disk({ model: 'a', count: 7, sub: { on: true }, map: { keep: 1, other: 2 } })")
check(h.eval(f, "adapter.model") == "local", "this process's edit is laid over the new contents")
check(h.eval(f, "adapter.count") == 7 and h.eval(f, "adapter.sub.on") is True,
      "the other process's edits (a key, a nested JsonObject key) are kept")
check(h.eval(f, "JSON.stringify(adapter.map)") == '{"keep":1,"other":2}', "a free-form map edited elsewhere is kept")
check(h.eval(f, "saveTimer.running") is True, "the merged result is written by the next auto-save")
h.eval(f, "autoSave()")
check(h.eval(f, "writes") == 1 and h.eval(f, "written.model") == "local" and h.eval(f, "written.count") == 7,
      "the file gets both edits")

# No pending edit: an external change is simply reloaded, nothing written.
h.eval(f, "fileChanged()")
h.eval(s, "disk({ model: 'cli', count: 7, sub: { on: true }, map: { keep: 1, other: 2 } })")
check(h.eval(f, "adapter.model") == "cli" and h.eval(f, "writes") == 1,
      "without a waiting edit the reload wins and nothing is written")

# writeMerged: only what this process changed, over the current file, at
# once even while auto-save of the domain is paused (a staged domain).
h.eval(s, "pausedDomains = ['general']")
h.eval(f, "adapter.count = 9; adapterUpdated()")
check(h.eval(f, "saveTimer.running") is False, "a paused domain does not auto-save")
r0 = h.eval(f, "reloads")
check(h.eval(f, "writeMerged()") is True and h.eval(f, "reloads") == r0 + 1, "writeMerged re-reads the file first")
h.eval(s, "disk({ model: 'main', count: 7, sub: { on: false }, map: {} })")
check(h.eval(f, "writes") == 2, "writeMerged writes at once")
check(h.eval(f, "written.count") == 9, "this process's change is written")
check(h.eval(f, "written.model") == "main" and h.eval(f, "written.sub.on") is False
      and h.eval(f, "JSON.stringify(written.map)") == "{}",
      "what the other process wrote meanwhile is not replaced by this process's older copy")

h.eval(f, "writeMerged()")
h.eval(s, "disk({ model: 'main', count: 9, sub: { on: false }, map: {} })")
check(h.eval(f, "writes") == 2, "nothing of this process's own to write: no write")

h.eval(f, "broken = true")
check(h.eval(f, "writeMerged()") is False, "a broken file is never written")

if failures:
    print(f"config-file-merge: {len(failures)} failure(s)")
    sys.exit(1)
print("config-file-merge: PASS")
