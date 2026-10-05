"""Notes tab (modules/widgets/dashboard/notes) behaviour, offscreen.

The real tab, components, Styling and Icons run against a fake file system
behind the Quickshell.Io Process stub (cat / rm / `sh -c` scripts that take
paths and contents as argv), so the index.json and note files it writes can be
checked: create (rich text + markdown), list/search, select + load, typing
with debounced auto-save, rich text and markdown formatting shortcuts,
reorder, rename, delete, keyboard navigation and Escape.
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

from qmlharness import REPO  # noqa: E402

FAKE_FS = r"""pragma Singleton
QtObject {
    property var files: ({})
    property var log: []
    function run(cmd) {
        log.push(cmd.join(" "));
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
            if (cmd[3] === "notes-write") {
                files[a[0]] = a[1];
                return { code: 0, out: "" };
            }
            if (cmd[3] === "notes-create") {
                files[a[1]] = a[2];
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
        });
    }
}"""

env = SettingsEnv("notes-tab")
h = env.h
qs = env.root / "qs"
notes_dir = qs / "modules/widgets/dashboard/notes"
shutil.copytree(REPO / "modules/widgets/dashboard/notes", notes_dir, dirs_exist_ok=True)
env._qmldir(notes_dir, "qs.modules.widgets.dashboard.notes")
h.module("FakeFs", {"Fs": FAKE_FS})
h.module("Quickshell.Io", {"Process": FAKE_PROCESS, "SplitParser": "QtObject { signal read(string data) }"})
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


def settle(ms=60):
    QTest.qWait(ms)


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


settle(150)

notes_path = ev("notesPath")
check(ev("indexPath") in fs(), "index.json created on start")
check(js("filteredNotes.map(n => n.id)") == ["__create__"], "empty index: only the create row")

# Create a rich text note: file + index entry, selected and loaded.
ev('createNewNote("Alpha", false)')
settle(200)
alpha = js("allNotes")[0]["id"]
check(fs().get(f"{notes_path}/{alpha}.html") == "<h1>Alpha</h1><p></p>", "rich text note file written")
check(index()["notes"][alpha]["title"] == "Alpha" and index()["order"] == [alpha], "index has the note")
check(ev("currentNoteId") == alpha and not ev("currentNoteIsMarkdown"), "new note selected")
check(ev("currentNoteTitle") == "Alpha" and "Alpha" in ev("currentNoteContent"), "note content loaded")
check(not ev("loadingNote"), "loading finished")

# Create a markdown note (goes first).
ev('createNewNote("Beta", true)')
settle(200)
beta = js("allNotes")[0]["id"]
check(fs().get(f"{notes_path}/{beta}.md") == "# Beta\n\n", "markdown note file written")
check(index()["order"] == [beta, alpha], "markdown note first in order")
check(ev("currentNoteId") == beta and ev("currentNoteIsMarkdown"), "markdown note selected")
check(js("filteredNotes.map(n => n.id)") == ["__create__", beta, alpha], "list: create row + 2 notes")

# The new note's editor has focus; typing auto-saves after the debounce.
type_text("hello")
settle(700)
check(fs()[f"{notes_path}/{beta}.md"] == "hello# Beta\n", f"markdown typing saved: {fs()[f'{notes_path}/{beta}.md']!r}")
check(not ev("editorDirty"), "editor clean after save")
check(index()["notes"][beta]["modified"] != "", "modified timestamp updated")

# Markdown shortcut: Ctrl+B inserts bold markers at the cursor.
QTest.keyClick(win, Qt.Key_B, Qt.ControlModifier)
settle(700)
check(fs()[f"{notes_path}/{beta}.md"] == "hello****# Beta\n", f"ctrl+b markdown: {fs()[f'{notes_path}/{beta}.md']!r}")

QTest.keyClick(win, Qt.Key_Up, Qt.AltModifier)
settle(700)
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
settle(100)
check("Alpha" in ev("currentNoteContent") and not ev("currentNoteIsMarkdown"), "Alpha content loaded")

# Rich text editing: Tab focuses the editor, typing auto-saves.
keys(Qt.Key_Tab)
type_text("zz")
settle(700)
check("zz" in fs()[f"{notes_path}/{alpha}.html"], "rich text typing saved")

# Rich text pre-format: Ctrl+B with no selection makes the next characters bold.
QTest.keyClick(win, Qt.Key_B, Qt.ControlModifier)
type_text("bb")
settle(700)
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
settle(100)

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
settle(200)
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
settle(200)
check(f"{notes_path}/{beta}.md" not in fs(), "note file removed")
check(index()["order"] == [alpha] and beta not in index()["notes"], "note removed from index")
check(not ev("deleteMode"), "delete mode left")

# Escape (no mode active) closes the module.
ev("focusSearchInput()")
settle()
keys(Qt.Key_Escape)
check(js("Visibilities.calls") == [""], f"Escape closes the module: {js('Visibilities.calls')}")

if fails:
    print(f"{len(fails)} failure(s)")
h.exit(1 if fails else 0)
