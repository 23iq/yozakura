"""Desktop widgets (modules/desktop/widgets) and the Desktop & Clock settings
page, offscreen in a private Xvfb (tests/lib/settings_env.py: real Config
defaults, Colors, Styling, components; services stubbed).

Desktop canvas: every widget type loads; edit mode shows the backdrop and
toolbar; dragging and resizing with the mouse snap to the grid and commit
relative coordinates; editing one widget keeps the other delegates (no
recreation); remove and add (free spot clear of the depth clock); overlap
warning over the clock area; windows covering a widget hide it and stop it;
the note saves its text into its options.
Settings page: add/option/remove through SettingsStore (staged), the clock
style gallery and the ink swatches write their keys, and nothing logs a QML
error.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt, qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

errors: list[str] = []


def _capture(_mode, _ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:", "is not installed", "unavailable")):
        errors.append(msg)


qInstallMessageHandler(_capture)

W, H = 1280, 720
WIDGETS = [
    {"id": "n1", "type": "note", "monitor": "", "x": 0.05, "y": 0.1, "w": 0.2, "h": 0.3, "options": {"text": "hello"}},
    {"id": "s1", "type": "system", "monitor": "", "x": 0.6, "y": 0.1, "w": 0.3, "h": 0.3, "options": {}},
    {"id": "m1", "type": "media", "monitor": "", "x": 0.05, "y": 0.6, "w": 0.35, "h": 0.2, "options": {}},
    {"id": "c1", "type": "calendar", "monitor": "", "x": 0.45, "y": 0.5, "w": 0.2, "h": 0.4, "options": {}},
    {"id": "w1", "type": "weather", "monitor": "", "x": 0.7, "y": 0.6, "w": 0.25, "h": 0.25, "options": {}},
]

env = SettingsEnv("desktop-widgets", overrides={"desktop": {"widgets": WIDGETS, "widgetGrid": 24}, "theme": {"animDuration": 0}},
                  wallpaper={"dir": "/walls", "scanDirs": ["/walls"], "paths": ["/walls/a.jpg"], "current": "/walls/a.jpg"})
h = env.h
win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.desktop.widgets
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {{
    id: w
    width: {W}; height: {H}; visible: true; color: "#202020"
    property var shellRef: null
    function findItem(name, from) {{
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    DesktopWidgetsCanvas {{
        id: canvas
        objectName: "canvas"
        anchors.fill: parent
        bounds: ({{ x: 16, y: 16, w: {W} - 32, h: {H} - 32 }})
    }}
}}""")
canvas = h.find(win, "canvas")


def ev(expr: str, obj=None):
    return h.eval(obj or canvas, expr)


def settle(ms: int = 120) -> None:
    QTest.qWait(ms)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        if errors:
            print("QML errors:\n  " + "\n  ".join(errors), file=sys.stderr)
        sys.exit(1)


def frame(wid: str):
    return ev(f'w.findItem("widgetFrame:{wid}")')


def widgets() -> list:
    return json.loads(ev("JSON.stringify(Config.desktop.widgets)"))


def center(item) -> QPoint:
    p = h.eval(item, "mapToItem(null, width / 2, height / 2)")
    return QPoint(int(p.x()), int(p.y()))


def drag(p0: QPoint, p1: QPoint) -> None:
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, p0)
    for i in range(1, 9):
        QTest.mouseMove(win, QPoint(p0.x() + (p1.x() - p0.x()) * i // 8, p0.y() + (p1.y() - p0.y()) * i // 8))
        settle(10)
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, p1)
    settle(60)


settle(300)

# Every type renders inside its frame, at its relative geometry.
for w in WIDGETS:
    f = frame(w["id"])
    check(f is not None, f"frame {w['id']}")
    check(h.eval(f, "visible") is True, f"{w['id']} visible")
    check(h.eval(f, "body !== null"), f"{w['id']} type loaded")
    check(round(h.eval(f, "x")) == round(w["x"] * W) and round(h.eval(f, "width")) == round(w["w"] * W), f"{w['id']} geometry")
check(ev("DesktopWidgets.editMode") is False and h.eval(frame("n1"), "body.editing") is False, "normal mode")
check(h.eval(frame("n1"), "body.saved") == "hello", "note text from options")
check(ev("SystemResources.consumers[w.findItem('widgetFrame:s1').body.consumerKey]") is True,
      "system widget registered with SystemResources while shown")

# Edit mode: backdrop + toolbar, content does not take input.
ev("DesktopWidgets.editMode = true")
settle(100)
check(h.eval(frame("n1"), "body.editing") is True, "edit mode reaches the widget")
check(ev("w.findItem('removeWidget') !== null"), "remove buttons shown")

# Drag the note by (+100, +50): snapped to the 24px grid relative to the bounds.
n1 = frame("n1")
s1_obj = frame("s1")
p0 = center(n1)
x0, y0 = h.eval(n1, "x"), h.eval(n1, "y")
drag(p0, QPoint(p0.x() + 100, p0.y() + 50))
moved = next(w for w in widgets() if w["id"] == "n1")
exp_x = 16 + round((x0 + 100 - 16) / 24) * 24
exp_y = 16 + round((y0 + 50 - 16) / 24) * 24
check(abs(moved["x"] * W - exp_x) < 1 and abs(moved["y"] * H - exp_y) < 1, f"drag snapped: {moved} vs {exp_x},{exp_y}")
check(frame("s1") == s1_obj, "other delegates survive an edit (no recreation)")

# Resize the system widget from its corner handle.
s1 = frame("s1")
handle = ev("w.findItem('resizeWidget', w.findItem('widgetFrame:s1'))")
p0 = center(handle)
w0 = h.eval(s1, "width")
drag(p0, QPoint(p0.x() + 60, p0.y() + 40))
resized = next(w for w in widgets() if w["id"] == "s1")
check(resized["w"] * W > w0 + 30, f"resize grows the widget: {resized}")
check(abs(((resized["x"] + resized["w"]) * W - 16) % 24) < 1 or abs(((resized["x"] + resized["w"]) * W - 16) % 24 - 24) < 1,
      "resized edge on the grid")
drag(center(handle), QPoint(center(handle).x() - 2000, center(handle).y() - 2000))
tiny = next(w for w in widgets() if w["id"] == "s1")
check(tiny["w"] * W >= h.eval(frame("s1"), "minPx.w") - 1, "resize stops at the minimum size")

# Depth clock area: overlapping widgets warn in edit mode.
ev("DesktopWidgets.setClockArea('', {x: 900, y: 40, w: 300, h: 600})")
settle(50)
check(h.eval(frame("w1"), "overlapsClock") is True, "weather overlaps the clock area")
check(h.eval(frame("n1"), "overlapsClock") is False, "note does not")

# Add: placed in a free spot clear of the clock and other widgets.
before = len(widgets())
ev("addWidget('note')")
settle(100)
after = widgets()
check(len(after) == before + 1, "added a widget")
new = after[-1]
check(new["type"] == "note" and new["options"].get("tint") == "tertiary", f"new widget with default options: {new}")
nf = frame(new["id"])
check(nf is not None and h.eval(nf, "visible"), "new widget shown")
check(h.eval(nf, "overlapsClock") is False, "new widget avoids the clock")

# Remove.
QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, center(ev(f"w.findItem('removeWidget', w.findItem('widgetFrame:{new['id']}'))")))
settle(100)
check(all(w["id"] != new["id"] for w in widgets()), "removed")

# Leave edit mode: Escape.
ev("forceActiveFocus()")
QTest.keyClick(win, Qt.Key_Escape)
settle(50)
check(ev("DesktopWidgets.editMode") is False, "Escape leaves edit mode")
check(h.eval(frame("w1"), "overlapsClock") is False, "no warning outside edit mode")

# Windows covering a widget hide it and stop it; partly covered stays.
mon = "{id: 0, x: 0, y: 0, width: %d, height: %d, scale: 1, transform: 0, activeWorkspace: {id: 1}}" % (W, H)
ev(f"monitor = {mon}")
ev("windows = [{monitor: 0, workspace: {id: 1}, hidden: false, at: [0, 0], size: [640, 720]}]")
settle(50)
check(h.eval(frame("m1"), "visible") is False and h.eval(frame("m1"), "active") is False, "covered media widget hidden")
check(h.eval(frame("s1"), "visible") is True, "uncovered widget stays")
check(ev("SystemResources.consumers[w.findItem('widgetFrame:s1').body.consumerKey]") is True, "still consuming")
ev("obscured = true")
settle(50)
check(h.eval(frame("s1"), "active") is False, "fullscreen stops every widget")
check(ev("SystemResources.consumers[w.findItem('widgetFrame:s1').body.consumerKey]") is False,
      "system widget unregistered while hidden")
ev("obscured = false; windows = []")
settle(50)
check(h.eval(frame("m1"), "visible") is True, "uncovered again")

# Note: typing saves the text into the widget's options after a pause.
note = h.eval(frame("n1"), "body")
editor = h.eval(note, "(function(it){ function f(i){ if (i.cursorRectangle !== undefined && i.selectByMouse !== undefined) return i;"
                      " for (var k = 0; k < i.children.length; k++) { var r = f(i.children[k]); if (r) return r; } return null; }"
                      " return f(it); })(this)")
h.eval(editor, "forceActiveFocus(); cursorPosition = length")
for key in (Qt.Key_Space, Qt.Key_W, Qt.Key_O, Qt.Key_R, Qt.Key_L, Qt.Key_D):
    QTest.keyClick(win, key, Qt.NoModifier)
settle(1200)
check(next(w for w in widgets() if w["id"] == "n1")["options"]["text"] == "hello world", "note text saved")

check(not errors, "QML errors on the desktop:\n  " + "\n  ".join(errors))

# ------------------------------------------------------------ settings page
shell_win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.globals
import qs.modules.desktop.widgets
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 900; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(shell_win, "shell")


def sev(expr: str):
    return h.eval(shell, expr)


def sfind(name: str):
    return sev(f'w.findItem("{name}")')


sev('select("desktop")')
settle(400)
sev("SettingsStore.set('desktop.depthClock', true)")
settle(300)
count = len(widgets())
add = sfind("addWidget:calendar")
check(add is not None, "add calendar button")
h.eval(add, "clicked()")
settle(200)
check(len(widgets()) == count + 1 and widgets()[-1]["type"] == "calendar", "settings adds a widget")
check(sev("GlobalStates.shellHasChanges") is True, "widget edits are staged with the shell settings")
cal_id = widgets()[-1]["id"]
check(sfind(f"widgetCard:{cal_id}") is not None, "card for the new widget")
sev(f"""(function() {{
    var card = w.findItem("widgetCard:{cal_id}");
    card.optionSet("showEvents", false);
}})()""")
check(next(w for w in widgets() if w["id"] == cal_id)["options"]["showEvents"] is False, "option written")
sev(f'w.findItem("widgetCard:{cal_id}").removeRequested()')
settle(100)
check(all(w["id"] != cal_id for w in widgets()), "card removes its widget")

edit = sfind("widgetsEditMode")
h.eval(edit, "clicked()")
check(sev("DesktopWidgets.editMode") is True, "arrange button enters edit mode")
h.eval(edit, "clicked()")
check(sev("DesktopWidgets.editMode") is False, "and leaves it")

poster = sfind("clockStyle:poster")
check(poster is not None, "gallery card per style")
h.eval(poster, "clicked()")
check(sev("Config.desktop.depthClockStyle") == "poster", "gallery writes the style")
swatch = sfind("swatch:tertiary")
check(swatch is not None, "ink swatch")
QTest.mouseClick(shell_win, Qt.LeftButton, Qt.NoModifier, center(swatch))
check(sev("Config.desktop.depthClockInk") == "tertiary", "swatch writes the ink role")

check(not errors, "QML errors in settings:\n  " + "\n  ".join(errors))
print("desktop-widgets: ok")
h.exit(0)
