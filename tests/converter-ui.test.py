#!/usr/bin/env python3
"""The file converter window (modules/converter), offscreen: dropped files
become rows with the proposed target, the picker changes one row or a whole
kind, Convert starts the convertible rows, job events drive progress, done
and error states, Esc asks to close, and files can still be dropped while
some are listed.

The real ConverterView / ConverterState / ConverterModel.js run against a
scripted BackendService (tests/lib/converter_env.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from converter_env import ConverterEnv  # noqa: E402

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from waits import settle, wait_until  # noqa: E402

failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)
        print("FAIL:", msg)


env = ConverterEnv("converter-ui", overrides={"theme": {"animDuration": 0}})
h = env.h
win = env.scene()
view = h.find(win, "view")
D = "/home/user/Downloads/"


def ev(expr):
    return h.eval(view, expr)


def js(expr, obj=None):
    """A JS value as plain Python (arrays and objects through JSON)."""
    return json.loads(h.eval(obj or view, "JSON.stringify(%s)" % expr) or "null")


def calls(method):
    return js("BackendService.calls.filter(c => c.method === '%s')" % method)


def walk(root, name):
    """Delegates are not QObject children of the list: walk the visual tree."""
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = walk(c, name)
        if found is not None:
            return found
    return None


def item(name):
    return walk(win.findChild(QQuickItem, "view"), name)


def row(path):
    return item("row:" + path)


def emit(job):
    ev("BackendService.emit('convert.job', %s)" % json.dumps(job))
    settle()


# empty: the drop zone
check(ev("converter.empty") and item("dropZone").property("visible"), "empty state shows the drop zone")

# drop three files (one unknown): rows with the proposed targets
ev("converter.addUrls(%s)" % json.dumps(["file://" + D + "holiday-photo.jpg", "file://" + D + "podcast-episode.flac",
                                         "file://" + D + "mystery.bin"]))
settle()
check(len(calls("convert.probe")) == 1, "one probe for the drop")
check(wait_until(lambda: row(D + "holiday-photo.jpg") is not None), "jpg row appears")
check(not item("dropZone").property("visible"), "drop zone hidden once files are listed")
check(h.eval(row(D + "holiday-photo.jpg"), "row.target") == "png", "jpg proposes png")
check(h.eval(row(D + "podcast-episode.flac"), "row.target") == "mp3", "flac proposes mp3")
check(h.eval(row(D + "mystery.bin"), "phase") == "invalid", "unknown file is marked")
check(h.eval(row(D + "mystery.bin"), "subtitle") == "Unknown format", "unknown file says why")

# the drop area stays active: a second drop adds, a duplicate is ignored
ev("converter.addUrls(%s)" % json.dumps(["file://" + D + "screenshot.png", "file://" + D + "holiday-photo.jpg"]))
settle()
check(ev("converter.rows.length") == 4, "second drop adds only the new file")
# two images: a kind header
keys = js("converter.rows.map(r => r.path)")
check(len(keys) == 4, "four rows")
check(item("kindChip") is not None, "a header appears over two images")

# picker on a row: popular first, a chosen target sticks
ev("pickRow('%s', null)" % (D + "holiday-photo.jpg"))
settle()
picker = item("picker")
check(picker.property("shown"), "picker opens")
sections = js("sections.map(s => s.popular ? 'popular' : s.kind)", picker)
check(sections and sections[0] == "popular", "popular targets first: %s" % sections)
webp = item("pick_webp")
check(webp is not None, "webp offered for a jpg")
h.eval(webp, "clicked()")
settle()
check(not picker.property("shown"), "picker closes on a choice")
check(h.eval(row(D + "holiday-photo.jpg"), "row.target") == "webp", "row target changed to webp")
check(ev("converter.showQuality"), "a lossy target shows the quality control")

# picker for the whole kind
ev("pickKind('image')")
settle()
h.eval(item("pick_bmp"), "clicked()")
settle()
check(h.eval(row(D + "holiday-photo.jpg"), "row.target") == "bmp" and h.eval(row(D + "screenshot.png"), "row.target") == "bmp",
      "the header changes every image")

# an unavailable target says which tool it needs and is not taken
md = {"path": D + "meeting-notes.md"}
ev("converter.add(['%s'])" % md["path"])
settle()
check(h.eval(row(D + "meeting-notes.md"), "phase") == "unavailable", "md -> pdf without pandoc is unavailable")
check("pandoc" in h.eval(row(D + "meeting-notes.md"), "subtitle"), "unavailable row names the tool")
ev("pickRow('%s', null)" % md["path"])
settle()
h.eval(item("pick_docx"), "clicked()")
settle()
check(picker.property("shown") and "pandoc" in item("pickerHint").property("text"), "choosing a missing tool's target explains")
QTest.keyClick(win, Qt.Key_Escape)
settle()
check(not picker.property("shown"), "Esc closes the picker")
check(h.eval(row(D + "meeting-notes.md"), "row.target") == "pdf", "the unavailable choice did not stick")

# Convert (Enter): only convertible rows start
before = len(calls("convert.start"))
QTest.keyClick(win, Qt.Key_Return)
settle()
starts = calls("convert.start")
check(len(starts) == before + 1, "Enter converts")
items = starts[-1]["params"]["items"] if starts else []
check(sorted(i["path"] for i in items) == sorted([D + "holiday-photo.jpg", D + "podcast-episode.flac", D + "screenshot.png"]),
      "start covers the convertible rows: %s" % items)
check(starts and starts[-1]["params"]["quality"] == "balanced", "quality from system.converter.quality")
check(h.eval(row(D + "holiday-photo.jpg"), "phase") == "queued", "rows queued")
check(item("rowProgress") is not None, "progress line exists")

# progress, done, error
emit({"id": "c1", "path": D + "holiday-photo.jpg", "to": "bmp", "state": "running", "progress": 0.4})
check(h.eval(row(D + "holiday-photo.jpg"), "subtitle") == "40%", "progress shown")
emit({"id": "c1", "path": D + "holiday-photo.jpg", "to": "bmp", "state": "done", "progress": 1,
      "output": D + "holiday-photo.bmp"})
check(h.eval(row(D + "holiday-photo.jpg"), "subtitle") == "Saved as holiday-photo.bmp", "done shows the result")
emit({"id": "c2", "path": D + "podcast-episode.flac", "to": "mp3", "state": "failed",
      "error": "Error while decoding stream: Invalid data found when processing input", "code": "tool_failed"})
check(h.eval(row(D + "podcast-episode.flac"), "phase") == "failed", "failed state")
check(h.eval(row(D + "podcast-episode.flac"), "subtitle") == "Conversion failed", "failed subtitle")
check("Invalid data" in h.eval(row(D + "podcast-episode.flac"), "errorText"), "the short error is shown")
check(ev("converter.startCount") == 1, "a failed row can be converted again")

# copy and reveal of a done row
ev("converter.copy('%s')" % (D + "holiday-photo.bmp"))
check(calls("convert.copy")[-1]["params"]["path"] == D + "holiday-photo.bmp", "copy asks the backend")

# paste: nothing on the clipboard is a notice
ev("BackendService.pasteError = 'no file on the clipboard'; BackendService.pasteCode = 'clipboard_no_file'")
QTest.keyClick(win, Qt.Key_V, Qt.ControlModifier)
settle()
check(ev("converter.notice") == "No file on the clipboard", "Ctrl+V with nothing says so")
ev("BackendService.pasteError = ''")
ev("BackendService.pasteReply = ({ paths: ['%s'] })" % (D + "settings.json"))
QTest.keyClick(win, Qt.Key_V, Qt.ControlModifier)
settle()
check(row(D + "settings.json") is not None, "Ctrl+V adds the clipboard's file")
check(h.eval(row(D + "settings.json"), "row.target") == "yaml", "json proposes yaml")

# remove and clear all
h.eval(row(D + "settings.json"), "converter.remove(path)")
settle()
check(row(D + "settings.json") is None, "remove drops the row")
closed = []
view.closeRequested.connect(lambda: closed.append(1))
QTest.keyClick(win, Qt.Key_Escape)
check(closed, "Esc asks to close the window")
ev("converter.clearAll()")
settle()
check(ev("converter.empty") and item("dropZone").property("visible"), "clear all returns to the drop zone")

# stale and early job events: re-add a converted file and convert it again
# while the start reply is held back. Replays of older jobs (this window's
# removed row, another window's job) never touch the row; the new job's
# event that beats the reply is applied once the reply names it.
ev("converter.add(['%s'])" % (D + "holiday-photo.jpg"))
settle()
ev("BackendService.deferStart = true")
QTest.keyClick(win, Qt.Key_Return)
settle()
nxt = "c%d" % ev("BackendService.seq")
check(h.eval(row(D + "holiday-photo.jpg"), "phase") == "pending", "row pending until the reply")
emit({"id": "c1", "path": D + "holiday-photo.jpg", "to": "png", "state": "done", "output": D + "holiday-photo.png"})
emit({"id": "x5", "path": D + "holiday-photo.jpg", "to": "png", "state": "done", "output": D + "other.png"})
emit({"id": nxt, "path": D + "holiday-photo.jpg", "to": "png", "state": "done", "progress": 1,
      "output": D + "holiday-photo (1).png"})
check(h.eval(row(D + "holiday-photo.jpg"), "phase") == "pending", "replayed or early events do not take the pending row")
ev("BackendService.flushStart()")
settle()
check(h.eval(row(D + "holiday-photo.jpg"), "subtitle") == "Saved as holiday-photo (1).png",
      "the early event of the new job applies after the reply: %s" % h.eval(row(D + "holiday-photo.jpg"), "subtitle"))
# a reconnect replays the same job: still the same result
emit({"id": nxt, "path": D + "holiday-photo.jpg", "to": "png", "state": "done", "progress": 1,
      "output": D + "holiday-photo (1).png"})
check(h.eval(row(D + "holiday-photo.jpg"), "subtitle") == "Saved as holiday-photo (1).png", "replay of own job is harmless")
ev("BackendService.deferStart = false")

# Config and the Quickshell stub (execDetached is recorded in `detached`)
# from a context that imports them
probe = env.load("""
import QtQuick
import Quickshell
import qs.config
QtObject {
    function setOpenFolder(v) { Config.system.converter.openFolder = v }
    function detached() { return JSON.stringify(Quickshell.detached) }
}""")


def detached():
    return json.loads(h.eval(probe, "detached()"))


def focused():
    it = win.activeFocusItem()
    return it.objectName() if it is not None else None


def key(k, mod=Qt.NoModifier):
    QTest.keyClick(win, k, mod)
    settle()


def reset(paths=()):
    ev("converter.clearAll()")
    settle()
    if paths:
        ev("converter.add(%s)" % json.dumps(list(paths)))
        settle()


# a thumbnail URL is percent-encoded: '#' is not a fragment
odd = "/home/user/My #1 shots/screenshot.png"
reset([odd])
art = walk(row(odd), "rowArt")
check(art is not None and "%231" in h.eval(art, "String(source)"), "thumbnail URL encodes '#': %s" % (art and h.eval(art, "String(source)")))

# a pending row (start sent, reply not back) cannot change; Stop and Remove
# on it cancel its job once the reply names it
reset([D + "holiday-photo.jpg", D + "screenshot.png"])
cancels = len(calls("convert.cancel"))
ev("BackendService.deferStart = true")
ev("converter.convert()")
settle()
photo = row(D + "holiday-photo.jpg")
check(h.eval(photo, "phase") == "pending" and not h.eval(photo, "editable"), "pending row is not editable")
check(not walk(photo, "targetChip").property("visible") and walk(photo, "targetLabel").property("visible"),
      "a pending row shows its target as text, not a chip")
check(h.eval(photo, "working") and walk(photo, "removeButton").property("tooltip") == "Stop", "a pending row offers Stop")
ev("pickRow('%s', null)" % (D + "holiday-photo.jpg"))
check(not picker.property("shown"), "no picker for a pending row")
h.eval(photo, "removeOrStop(null)")
ev("converter.remove('%s')" % (D + "screenshot.png"))
settle()
check(len(calls("convert.cancel")) == cancels, "nothing to cancel before the reply")
ev("BackendService.flushStart()")
settle()
seq = ev("BackendService.seq")
cancelled = sorted(c["params"]["id"] for c in calls("convert.cancel")[cancels:])
check(cancelled == sorted(["c%d" % (seq - 1), "c%d" % seq]), "stopped and removed pending rows cancel their jobs: %s" % cancelled)
ev("BackendService.deferStart = false")

# "show files when done": the batch ends with a failure after a success -> reveal
reset([D + "holiday-photo.jpg", D + "screenshot.png"])
h.eval(probe, "setOpenFolder(true)")
shown = len(detached())
ev("converter.convert()")
settle()
seq = ev("BackendService.seq")
emit({"id": "c%d" % (seq - 1), "path": D + "holiday-photo.jpg", "to": "png", "state": "done", "progress": 1,
      "output": D + "holiday-photo.png"})
check(len(detached()) == shown, "no reveal while a job still runs")
emit({"id": "c%d" % seq, "path": D + "screenshot.png", "to": "jpg", "state": "failed", "error": "cannot write to /ro",
      "code": "no_write", "errorArgs": ["/ro"]})
opened = detached()
check(len(opened) == shown + 1 and opened[-1][4] == "file://" + D + "holiday-photo.png",
      "the batch's result is revealed when its last job fails: %s" % opened[shown:])
check(h.eval(row(D + "screenshot.png"), "errorText") == "Cannot write to /ro", "a known job error is translated")
h.eval(probe, "setOpenFolder(false)")

# errors by their code, never by the English message
ev("BackendService.pasteError = 'cannot read the clipboard'; BackendService.pasteCode = 'clipboard_unavailable'")
key(Qt.Key_V, Qt.ControlModifier)
check("wl-clipboard" in ev("converter.notice"), "a missing wl-paste says so: %s" % ev("converter.notice"))
ev("BackendService.pasteError = 'the clipboard is empty'; BackendService.pasteCode = 'clipboard_empty'")
key(Qt.Key_V, Qt.ControlModifier)
check(ev("converter.notice") == "The clipboard is empty", "an empty clipboard says so: %s" % ev("converter.notice"))
ev("BackendService.pasteError = 'unknown method: convert.paste'; BackendService.pasteCode = 'unknown_method'")
key(Qt.Key_V, Qt.ControlModifier)
check(ev("converter.notice") == "The converter service is not running: restart the shell", "a missing service says so")
ev("BackendService.pasteError = 'output folder /o does not exist'; BackendService.pasteCode = 'out_dir';"
   " BackendService.pasteArgs = ['/o']")
key(Qt.Key_V, Qt.ControlModifier)
check(ev("converter.notice") == "The output folder /o does not exist", "a code's arguments fill the line: %s" % ev("converter.notice"))
ev("BackendService.pasteError = 'the clipboard is empty'; BackendService.pasteCode = ''; BackendService.pasteArgs = []")
key(Qt.Key_V, Qt.ControlModifier)
check(ev("converter.notice") == "Something went wrong: the clipboard is empty",
      "a message without a code is not matched: %s" % ev("converter.notice"))
ev("BackendService.pasteError = 'x'; BackendService.pasteCode = 'some_future_code'")
key(Qt.Key_V, Qt.ControlModifier)
check(ev("converter.notice") == "Something went wrong: x", "an unknown code falls back: %s" % ev("converter.notice"))
ev("BackendService.pasteError = ''; BackendService.pasteCode = ''")

# keyboard: Tab reaches the toolbar and the drop zone; Ctrl+O, Enter on the
# drop zone open the chooser; Delete removes the row in focus
reset()
view.forceActiveFocus()
key(Qt.Key_Tab)
check(focused() == "addButton", "Tab reaches Add files first: %s" % focused())
key(Qt.Key_Tab)
check(focused() == "pasteButton", "then Paste: %s" % focused())
key(Qt.Key_Tab)
check(focused() == "dropZone", "then the drop zone: %s" % focused())
key(Qt.Key_Return)
check(ev("chooser.running"), "Enter on the drop zone opens the file chooser")
ev("chooser.running = false")
view.forceActiveFocus()
key(Qt.Key_O, Qt.ControlModifier)
check(ev("chooser.running"), "Ctrl+O opens the file chooser")
ev("chooser.running = false")

reset([D + "holiday-photo.jpg", D + "screenshot.png", D + "podcast-episode.flac"])
remove = walk(row(D + "screenshot.png"), "removeButton")
check(h.eval(remove, "focusable") and h.eval(item("clearButton"), "focusable"),
      "row and toolbar buttons are focusable")
walk(row(D + "screenshot.png"), "targetChip").forceActiveFocus()
key(Qt.Key_Delete)
check(row(D + "screenshot.png") is None, "Delete removes the row in focus")
check(focused() not in (None, ""), "the focus moves on after Delete: %s" % focused())

# the picker: opens on the current target, Tab stays inside, Esc returns
# the focus to the chip that opened it
chip = walk(row(D + "holiday-photo.jpg"), "targetChip")
check(h.eval(chip, "isButton"), "the target chip reads as a button")
chip.forceActiveFocus()
key(Qt.Key_Return)
check(picker.property("shown") and focused() == "pick_png", "the picker focuses the current target: %s" % focused())
key(Qt.Key_Backtab, Qt.ShiftModifier)
last = focused()
check(last is not None and last.startswith("pick_") and last != "pick_png", "Shift+Tab from the first chip wraps to the last: %s" % last)
key(Qt.Key_Tab)
check(focused() == "pick_png", "Tab from the last chip wraps to the first: %s" % focused())
key(Qt.Key_Escape)
check(not picker.property("shown") and win.activeFocusItem() == chip, "Esc returns the focus to the chip: %s" % focused())

if failures:
    print(f"{len(failures)} failure(s)")
    sys.exit(1)
print("converter-ui: ok")
