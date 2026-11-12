"""Notes tab (modules/widgets/dashboard/notes) behaviour, offscreen.

The real tab, components, Styling and Icons run against a fake file system
behind the Quickshell.Io Process stub (cat / rm / mkdir / `sh -c` scripts that
take paths as argv) and FileView stub (file writes), so the index.json and
note files it writes can be checked: create (rich text + markdown),
list/search, select + load, typing with debounced auto-save, rich text and
markdown formatting shortcuts, reorder, rename, delete, keyboard navigation
and Escape. Then the storage edge cases: a long note is saved (content never
goes through argv), writes are atomic, a failed save is kept dirty, a slow
read of the previous note never lands in the open one, back-to-back writes
all land, and index rewrites keep notes added by other writers. A failed
save is shown under the editor (retry / discard) and keeps the note open:
switching never drops its text, and the pending auto-save of the last
keystroke never writes it into the next note; nothing is saved while a note
loads.
"""
import json
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
from settings_env import SettingsEnv  # noqa: E402

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from waits import pump, settle, wait_until  # noqa: E402

from qmlharness import REPO  # noqa: E402

FAKE_FS = r"""pragma Singleton
QtObject {
    property var files: ({})
    property var log: []
    // FileView writes: [{ path, atomic, block }]
    property var writes: []
    property bool failWrites: false
    // cat of these paths waits for release() (a slow read)
    property var holdPaths: []
    property var held: []
    function release() {
        const h = held;
        held = [];
        h.forEach(f => f());
    }
    function run(cmd) {
        log.push(cmd.join(" "));
        if (cmd[0] === "mkdir")
            return { code: 0, out: "" };
        if (cmd[0] === "cat")
            return cmd[1] in files ? { code: 0, out: files[cmd[1]] } : { code: 1, out: "" };
        if (cmd[0] === "rm") {
            delete files[cmd[2]];
            return { code: 0, out: "" };
        }
        if (cmd[0] === "sh") {
            // The store passes paths and contents as argv: sh -c SCRIPT NAME ARGS...
            const a = cmd.slice(4);
            if (cmd[3] === "notes-init") {
                if (!(a[1] in files))
                    files[a[1]] = "";
                return { code: 0, out: "" };
            }
        }
        return { code: 127, out: "" };
    }
}"""

FAKE_PROCESS = """import FakeFs
QtObject {
    id: p
    property var command: []
    property bool running: false
    property var stdout: null
    signal exited(int code)
    onRunningChanged: {
        if (!running)
            return;
        Qt.callLater(function () {
            if (p.command[0] === "cat" && Fs.holdPaths.indexOf(p.command[1]) !== -1) {
                Fs.held.push(finish);
                return;
            }
            finish();
        });
    }
    function finish() {
        {
            const r = Fs.run(p.command);
            if (p.stdout && r.out !== "") {
                const lines = r.out.split("\\n");
                if (lines.length > 1 && lines[lines.length - 1] === "")
                    lines.pop();
                for (let i = 0; i < lines.length; i++)
                    p.stdout.read(lines[i]);
            }
            p.running = false;
            p.exited(r.code);
        }
    }
}"""

# Like Quickshell's FileView, setText() skips a write equal to the data the
# view holds (loaded, or last written); text() loads it when not prepared.
FAKE_FILEVIEW = """import FakeFs
QtObject {
    id: v
    property string path
    property bool preload: true
    property bool blockAllReads: false
    property bool atomicWrites: false
    property bool blockWrites: false
    property bool printErrors: true
    property string data: ""
    property bool prepared: false
    signal saveFailed(int error)
    onPathChanged: prepared = false
    function reload() { prepared = false; }
    function text() {
        if (!prepared) {
            data = Fs.files[v.path] ?? "";
            prepared = true;
        }
        return data;
    }
    function setText(t) {
        if (t === data)
            return;
        Fs.writes.push({ "path": v.path, "atomic": v.atomicWrites, "block": v.blockWrites });
        if (Fs.failWrites) {
            v.saveFailed(1);
            return;
        }
        Fs.files[v.path] = t;
        data = t;
    }
}"""

env = SettingsEnv("notes-tab")
h = env.h
qs = env.root / "qs"
notes_dir = qs / "modules/widgets/dashboard/notes"
shutil.copytree(REPO / "modules/widgets/dashboard/notes", notes_dir, dirs_exist_ok=True)
env._qmldir(notes_dir, "qs.modules.widgets.dashboard.notes")
# Auto-save waits 500 ms after the last keystroke; that the save happens is
# under test, not its delay: 80 ms here.
_tab = (notes_dir / "NotesTab.qml").read_text()
assert "id: saveDebounceTimer\n        interval: 500\n" in _tab
(notes_dir / "NotesTab.qml").write_text(_tab.replace("id: saveDebounceTimer\n        interval: 500\n",
                                                     "id: saveDebounceTimer\n        interval: 80\n"))
h.module("FakeFs", {"Fs": FAKE_FS})
h.module("Quickshell.Io", {"Process": FAKE_PROCESS, "FileView": FAKE_FILEVIEW,
                           "SplitParser": "QtObject { signal read(string data) }"})
h.module("qs.modules.services", {
    "Visibilities": "pragma Singleton\nQtObject { property var calls: []; "
                    "function setActiveModule(m) { calls = calls.concat([m]) } }"})

win = env.load("""
import QtQuick
import QtQuick.Window
import FakeFs
import qs.modules.services
import qs.modules.widgets.dashboard.notes
Window {
    width: 900; height: 420; visible: true; color: "black"
    NotesTab { objectName: "notes"; anchors.fill: parent; leftPanelWidth: 300 }
}""")
win.requestActivate()
tab = h.find(win, "notes")
fails: list[str] = []


def check(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


def ev(expr):
    return h.eval(tab, expr)


def js(expr):
    return json.loads(ev("JSON.stringify(" + expr + ")"))


def fs():
    return js("Fs.files")


def saved(path, text):
    """Wait for the debounced auto-save to write `text` to `path`."""
    wait_until(lambda: fs().get(path) == text and not ev("editorDirty"))


def index():
    return json.loads(fs()[ev("indexPath")])


def type_text(text):
    for ch in text:
        QTest.keyClick(win, Qt.Key(ord(ch.upper())))
    settle()


def keys(*seq, mod=Qt.NoModifier):
    for k in seq:
        QTest.keyClick(win, k, mod)
    settle()


wait_until(lambda: ev("indexPath") in fs() and js("filteredNotes.map(n => n.id)") == ["__create__"])

notes_path = ev("notesPath")
check(ev("indexPath") in fs(), "index.json created on start")
check(js("filteredNotes.map(n => n.id)") == ["__create__"], "empty index: only the create row")

# Create a rich text note: file + index entry, selected and loaded.
ev('createNewNote("Alpha", false)')
wait_until(lambda: len(js("allNotes")) == 1 and ev("currentNoteId") != "" and not ev("loadingNote")
           and "Alpha" in ev("currentNoteContent"))
alpha = js("allNotes")[0]["id"]
check(fs().get(f"{notes_path}/{alpha}.html") == "<h1>Alpha</h1><p></p>", "rich text note file written")
check(index()["notes"][alpha]["title"] == "Alpha" and index()["order"] == [alpha], "index has the note")
check(ev("currentNoteId") == alpha and not ev("currentNoteIsMarkdown"), "new note selected")
check(ev("currentNoteTitle") == "Alpha" and "Alpha" in ev("currentNoteContent"), "note content loaded")
check(not ev("loadingNote"), "loading finished")

# Create a markdown note (goes first).
ev('createNewNote("Beta", true)')
wait_until(lambda: len(js("allNotes")) == 2 and ev("currentNoteIsMarkdown") and not ev("loadingNote"))
beta = js("allNotes")[0]["id"]
check(fs().get(f"{notes_path}/{beta}.md") == "# Beta\n\n", "markdown note file written")
check(index()["order"] == [beta, alpha], "markdown note first in order")
check(ev("currentNoteId") == beta and ev("currentNoteIsMarkdown"), "markdown note selected")
check(js("filteredNotes.map(n => n.id)") == ["__create__", beta, alpha], "list: create row + 2 notes")

# The new note's editor has focus; typing auto-saves after the debounce.
# (the editor takes focus a moment after the note loads; until then the
# rich text editor of the previous note may still have it)
wait_until(lambda: ev("Window.activeFocusItem !== null && Window.activeFocusItem.textFormat === TextEdit.PlainText"))
type_text("hello")
saved(f"{notes_path}/{beta}.md", "hello# Beta\n")
check(fs()[f"{notes_path}/{beta}.md"] == "hello# Beta\n", f"markdown typing saved: {fs()[f'{notes_path}/{beta}.md']!r}")
check(not ev("editorDirty"), "editor clean after save")
check(index()["notes"][beta]["modified"] != "", "modified timestamp updated")

# Markdown shortcut: Ctrl+B inserts bold markers at the cursor.
QTest.keyClick(win, Qt.Key_B, Qt.ControlModifier)
saved(f"{notes_path}/{beta}.md", "hello****# Beta\n")
check(fs()[f"{notes_path}/{beta}.md"] == "hello****# Beta\n", f"ctrl+b markdown: {fs()[f'{notes_path}/{beta}.md']!r}")

QTest.keyClick(win, Qt.Key_Up, Qt.AltModifier)
saved(f"{notes_path}/{beta}.md", "# hello****# Beta\n")
check(fs()[f"{notes_path}/{beta}.md"] == "# hello****# Beta\n", "alt+up makes the line a heading")
QTest.keyClick(win, Qt.Key_Escape)
settle()

# Search filters and offers a "create <name>" row.
ev('searchText = "alp"')
settle()
rows = js("filteredNotes.map(n => [n.id, !!n.isCreateSpecificButton])")
check(rows == [["__create__", True], [alpha, False]], f"search 'alp': {rows}")
check(ev("selectedIndex") == 0, "first row selected while searching")
ev('searchText = ""')
settle()
check(ev("selectedIndex") == -1, "cleared search: nothing selected")

# Keyboard navigation through the search field.
ev("focusSearchInput()")
settle()
keys(Qt.Key_Down)
check(ev("selectedIndex") == 0, "Down selects the first row")
keys(Qt.Key_Down, Qt.Key_Down)
check(ev("selectedIndex") == 2 and ev("currentNoteId") == alpha, "Down x2 selects + loads Alpha")
wait_until(lambda: "Alpha" in ev("currentNoteContent") and not ev("loadingNote"))
check("Alpha" in ev("currentNoteContent") and not ev("currentNoteIsMarkdown"), "Alpha content loaded")

# Rich text editing: Tab focuses the editor, typing auto-saves.
keys(Qt.Key_Tab)
type_text("zz")
wait_until(lambda: "zz" in fs()[f"{notes_path}/{alpha}.html"] and not ev("editorDirty"))
check("zz" in fs()[f"{notes_path}/{alpha}.html"], "rich text typing saved")

# Rich text pre-format: Ctrl+B with no selection makes the next characters bold.
QTest.keyClick(win, Qt.Key_B, Qt.ControlModifier)
type_text("bb")
wait_until(lambda: "bb" in fs()[f"{notes_path}/{alpha}.html"] and not ev("editorDirty"))
saved = fs()[f"{notes_path}/{alpha}.html"]
check("font-weight" in saved and "bb" in saved, "ctrl+b pre-format bolds typed text")
QTest.keyClick(win, Qt.Key_Escape)
settle()

# Reorder with Ctrl+Up from the search field.
ev("focusSearchInput()")
settle()
keys(Qt.Key_Up, mod=Qt.ControlModifier)
check(index()["order"] == [alpha, beta], f"ctrl+up moves Alpha first: {index()['order']}")
check(js("filteredNotes.map(n => n.id)") == ["__create__", alpha, beta], "list follows the new order")
ev("selectedIndex = 1")
settle()

# Shift+Enter expands the options of the selected note; Down/Enter picks Rename.
keys(Qt.Key_Return, mod=Qt.ShiftModifier)
check(ev("expandedItemIndex") == 1, "shift+enter expands options")
keys(Qt.Key_Down)
check(ev("selectedOptionIndex") == 1, "Down moves to Rename")
keys(Qt.Key_Return)
check(ev("renameMode") and ev("noteToRename") == alpha, "Rename option enters rename mode")
check(ev("newNoteName") == "Alpha", "rename field prefilled")
ev('newNoteName = "Gamma"')
ev("confirmRenameNote()")
wait_until(lambda: index()["notes"][alpha]["title"] == "Gamma" and not ev("renameMode"))
check(index()["notes"][alpha]["title"] == "Gamma", "rename saved to index")
check(not ev("renameMode"), "rename mode left")
check(js("filteredNotes.map(n => n.title)")[1] == "Gamma", "renamed note listed")

# Delete mode via the API, confirm with Right + Enter on the tab.
ev(f'enterDeleteMode("{beta}")')
settle()
check(ev("deleteMode") and ev("noteToDelete") == beta, "delete mode entered")
keys(Qt.Key_Right)
check(ev("deleteButtonIndex") == 1, "Right highlights confirm")
keys(Qt.Key_Return)
wait_until(lambda: f"{notes_path}/{beta}.md" not in fs() and beta not in index()["notes"] and not ev("deleteMode"))
check(f"{notes_path}/{beta}.md" not in fs(), "note file removed")
check(index()["order"] == [alpha] and beta not in index()["notes"], "note removed from index")
check(not ev("deleteMode"), "delete mode left")

# --- Storage edge cases -------------------------------------------------------
store = next(c for c in tab.children() if c.property("noteExtension") is not None)


def st(expr):
    return h.eval(store, expr)


# A long note (over the 128 KiB argv limit) is saved whole; content never
# goes through argv; every file write is atomic and blocking (in order).
st('write("long", true, "x".repeat(200 * 1024))')
check(len(fs().get(f"{notes_path}/long.md", "")) == 200 * 1024, "200 KiB note saved")
check(not any("xxxxxxxxxx" in line for line in js("Fs.log")), "note content never passed as argv")
check(all(w["atomic"] and w["block"] for w in js("Fs.writes")), "all writes atomic + blocking")

# Back-to-back writes of two notes both land (a shared process dropped one).
st('write("n1", true, "one"); write("n2", true, "two")')
check(fs().get(f"{notes_path}/n1.md") == "one" and fs().get(f"{notes_path}/n2.md") == "two",
      "back-to-back writes both saved")
# Same text into two files, and over a file another writer changed since.
st('write("s1", true, "same"); write("s2", true, "same")')
check(fs().get(f"{notes_path}/s1.md") == "same" and fs().get(f"{notes_path}/s2.md") == "same",
      "same content written to a second file")
ev(f"Fs.files[{json.dumps(notes_path + '/s2.md')}] = 'changed elsewhere'")
st('write("s2", true, "same")')
check(fs().get(f"{notes_path}/s2.md") == "same", "a write over an external change is not skipped")

# A failed save keeps the note dirty and is reported; the next save retries.
ev(f'loadNoteContent("{alpha}")')
wait_until(lambda: ev("currentNoteId") == alpha and not ev("loadingNote"))
alpha_file = f"{notes_path}/{alpha}.html"
before = fs()[alpha_file]
# (the file differs from the editor, so the save has something to write)
ev(f"Fs.files[{json.dumps(alpha_file)}] = 'on disk'")
before = "on disk"
ev("Fs.failWrites = true")
ev("editorDirty = true")
ev("saveCurrentNote()")
check(ev("editorDirty") and ev("saveFailed"), "failed save: still dirty, saveFailed set")
check(fs()[alpha_file] == before, "failed save left the file as it was")
ev("Fs.failWrites = false")
ev("saveCurrentNote()")
check(not ev("editorDirty") and not ev("saveFailed"), "retry saves and clears the failure")

# A note added to index.json by another writer (quick note, MCP tool), with
# an unknown field, survives the tab's own index rewrites.
idx = index()
idx["order"].insert(0, "ext1")
idx["notes"]["ext1"] = {"title": "External", "created": "c", "modified": "m", "isMarkdown": True, "pinned": True}
idx["version"] = 7
ev(f"Fs.files[{json.dumps(ev('indexPath'))}] = {json.dumps(json.dumps(idx))}")
ev(f"Fs.files[{json.dumps(notes_path + '/ext1.md')}] = 'external'")
ev("saveNotesOrder()")
wait_until(lambda: "ext1" in index()["order"] and alpha in index()["order"] and not st("_indexBusy"))
check(index()["notes"]["ext1"].get("pinned") and index().get("version") == 7, "other writers' fields kept")
check(index()["order"] == ["ext1", alpha], f"external note kept first: {index()['order']}")

# Queued index updates all land (each one reads the index first).
st(f'setTitle("{alpha}", "T1"); touch("{alpha}"); setTitle("ext1", "T2")')
wait_until(lambda: index()["notes"][alpha]["title"] == "T1" and index()["notes"]["ext1"]["title"] == "T2")
check(index()["order"] == ["ext1", alpha], "queued title updates both saved")

# A slow read of the previous note never lands in the open one.
st("refresh()")
wait_until(lambda: "ext1" in js("allNotes.map(n => n.id)"))
ev('loadNoteContent("ext1")')
wait_until(lambda: ev("currentNoteContent") == "external" and not ev("loadingNote"))
ev(f"Fs.holdPaths = [{json.dumps(alpha_file)}]")
ev(f'loadNoteContent("{alpha}")')
ev('loadNoteContent("ext1")')
wait_until(lambda: not ev("loadingNote") and ev("currentNoteId") == "ext1")
ev("Fs.holdPaths = []")
ev("Fs.release()")
settle()
check(ev("currentNoteId") == "ext1" and ev("currentNoteContent") == "external",
      f"late read of the previous note ignored: {ev('currentNoteContent')[:40]!r}")
ev("editorDirty = true")
ev("saveCurrentNote()")
check(fs()[f"{notes_path}/ext1.md"] == "external",
      f"the open note keeps its own content when saved: {fs()[f'{notes_path}/ext1.md'][:40]!r}")

# --- Save failures -------------------------------------------------------------
en = json.loads((REPO / "translations/en.json").read_text())
notice = h.find(win, "noteSaveNotice")
failed_chip = h.find(win, "noteSaveFailed")
ext1_file = f"{notes_path}/ext1.md"
alpha_file = f"{notes_path}/{alpha}.html"


def open_note(note_id, text):
    """Select the note in the list (as a click does) and wait for its content."""
    ids = js("filteredNotes.map(n => n.id)")
    if note_id in ids and ev("selectedIndex") != ids.index(note_id):
        ev(f"selectedIndex = {ids.index(note_id)}")
    else:
        ev(f'loadNoteContent("{note_id}")')
    wait_until(lambda: ev("currentNoteId") == note_id and not ev("loadingNote") and text in ev("currentNoteContent"))


# A second rich text note: a switch target with the same editor as Alpha.
ev('createNewNote("Delta", false)')
wait_until(lambda: "Delta" in js("allNotes.map(n => n.title)") and not ev("loadingNote") and "Delta" in ev("currentNoteContent"))
delta = next(n["id"] for n in js("allNotes") if n["title"] == "Delta")
delta_file = f"{notes_path}/{delta}.html"
delta_text = fs()[delta_file]

# A failed save is visible in the tab, with a translated message.
open_note(alpha, "")
check(not notice.property("visible"), "no notice while saves work")
ev("Fs.failWrites = true")
ev("focusEditor()")
settle()
type_text("k")
wait_until(lambda: ev("saveFailed"))
check(notice.property("visible") and failed_chip.property("text") == en["notes.save_failed"],
      "a failed save is shown under the editor")

# Switching notes after a failed save keeps the note open with its text;
# the auto-save of the last keystroke does not follow into the next note.
debounce = next(c for c in tab.children() if c.property("interval") == 80 and c.property("repeat") is False)
debounce.setProperty("interval", 400)  # the switch comes well before it fires
ev(f"Fs.holdPaths = [{json.dumps(delta_file)}]")
type_text("w")  # a keystroke: the auto-save is pending
check(debounce.property("running"), "auto-save pending after a keystroke")
alpha_text = st("editorPane.text(false)")
ev(f"selectedIndex = {js('filteredNotes.map(n => n.id)').index(delta)}")
settle()
ev("Fs.failWrites = false")  # the disk works again before the debounce would fire
check(not debounce.property("running"), "the switch stops the pending auto-save")
pump(600)  # the debounce time passes while the other note would still load
ev("Fs.release(); Fs.holdPaths = []")
settle()
debounce.setProperty("interval", 80)
check(ev("currentNoteId") == alpha, "a failed save keeps the note open on a switch")
check(st("editorPane.text(false)") == alpha_text and ev("editorDirty"), "its unsaved text stays in the editor")
check(fs()[delta_file] == delta_text, f"the other note is not overwritten: {fs()[delta_file][:60]!r}")
check(ev("selectedIndex") == js("filteredNotes.map(n => n.id)").index(alpha), "the selection stays on the open note")
check(notice.property("visible"), "the failure stays visible")

# Retry: saved, the notice goes, switching works again.
h.eval(notice, "retry()")
check(not ev("saveFailed") and not ev("editorDirty") and not notice.property("visible"), "retry saves and hides the notice")
check("w" in fs()[alpha_file], "the retried save wrote the text")
open_note(delta, "Delta")
check(fs()[delta_file] == delta_text, "switching after the retry leaves the other note alone")

# Discard: the note reloads from disk and can be left.
open_note(alpha, "")
# (the file differs from the editor, so the save has something to write)
on_disk = "<p>on disk</p>"
ev(f"Fs.files[{json.dumps(alpha_file)}] = {json.dumps(on_disk)}")
ev("Fs.failWrites = true")
ev("editorDirty = true")
ev("saveCurrentNote()")
check(notice.property("visible"), "failure shown again")
ev("Fs.failWrites = false")
h.eval(notice, "discard()")
wait_until(lambda: not ev("loadingNote") and not ev("editorDirty"))
check(not ev("saveFailed") and not notice.property("visible"), "discard clears the failure")
check(ev("currentNoteContent") == on_disk and fs()[alpha_file] == on_disk, "discard reloads the note from disk")
open_note("ext1", "external")
check(ev("currentNoteId") == "ext1", "after a discard the switch goes through")

# Nothing is saved while a note loads (the editor still shows the previous one).
open_note(alpha, "")
ev(f"Fs.holdPaths = [{json.dumps(ext1_file)}]")
ev('loadNoteContent("ext1")')
check(ev("loadingNote"), "ext1 is loading")
n_writes = len(js("Fs.writes"))
ev("editorDirty = true")
ev("saveCurrentNote()")
check(len(js("Fs.writes")) == n_writes, "no save while a note loads")
ev("Fs.release(); Fs.holdPaths = []")
wait_until(lambda: not ev("loadingNote"))
check(fs()[ext1_file] == "external" and ev("currentNoteContent") == "external", "the loading note is intact")

# Escape (no mode active) closes the module.
ev("focusSearchInput()")
settle()
keys(Qt.Key_Escape)
check(js("Visibilities.calls") == [""], f"Escape closes the module: {js('Visibilities.calls')}")

if fails:
    print(f"{len(fails)} failure(s)")
h.exit(1 if fails else 0)
