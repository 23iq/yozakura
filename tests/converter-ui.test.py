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
      "error": "Error while decoding stream: Invalid data found when processing input"})
check(h.eval(row(D + "podcast-episode.flac"), "phase") == "failed", "failed state")
check(h.eval(row(D + "podcast-episode.flac"), "subtitle") == "Conversion failed", "failed subtitle")
check("Invalid data" in h.eval(row(D + "podcast-episode.flac"), "errorText"), "the short error is shown")
check(ev("converter.startCount") == 1 + 0, "a failed row can be converted again")

# copy and reveal of a done row
ev("converter.copy('%s')" % (D + "holiday-photo.bmp"))
check(calls("convert.copy")[-1]["params"]["path"] == D + "holiday-photo.bmp", "copy asks the backend")

# paste: nothing on the clipboard is a notice
ev("BackendService.pasteError = 'no file on the clipboard'")
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

if failures:
    print(f"{len(failures)} failure(s)")
    sys.exit(1)
print("converter-ui: ok")
