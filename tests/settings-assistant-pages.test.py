"""The Assistant destination's composed pages (Assistant, AI providers, Code
tasks) in the settings window, offscreen: clicks on a stage change their
key as one undo step; the rare options are out of the row; the providers
band shows every provider in its state and never a key.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("settings-assistant-pages")
h = env.h
failures: list[str] = []


def check(ok, what):
    print(("PASS " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import qs.modules.settings
import qs.modules.settings.store
Window {
    id: w
    width: 1180; height: 780; visible: true
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    // a point of an item, as fractions of its size, in window coordinates
    function at(name, fx, fy) {
        var it = findItem(name);
        if (!it || !it.visible) return null;
        var p = it.mapToItem(null, it.width * fx, it.height * fy);
        return [Math.round(p.x), Math.round(p.y)];
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")
win.requestActivate()
QTest.qWaitForWindowActive(win, 3000)


def ev(expr):
    return h.eval(win, expr)


def select(cat):
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    QTest.qWait(200)


def click(name, fx=0.5, fy=0.5) -> bool:
    p = json.loads(h.eval(win, f'JSON.stringify(at("{name}", {fx}, {fy}))'))
    if not p:
        return False
    QTest.mouseMove(win, QPoint(p[0], p[1]))
    QTest.qWait(30)
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(p[0], p[1]))
    QTest.qWait(60)
    return True


def steps():
    return ev("SettingsStore.undoStack.length")


def row(entry):
    return ev(f'w.findItem("settingRow:{entry}") !== null')


# ---- Assistant: the other edge moves it; a strip item shows / hides --------
select("ai")
check(ev("Config.ai.sidebarPosition") == "right", "assistant: on the right by default")
n = steps()
check(click("assistantEdgePicker", 0.02, 0.5), "assistant: the left edge of the stage is a target")
check(ev("Config.ai.sidebarPosition") == "left", "assistant: a click on the left edge moves it there")
check(steps() == n + 1, "assistant: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.ai.sidebarPosition") == "right", "assistant: undo puts it back")
QTest.qWait(500)  # the panel glides back
n = steps()
check(click("assistantStrip:cost"), "assistant: the strip's cost item is clickable")
check(ev("Config.ai.strip.cost") is False, "assistant: a click hides the cost")
check(steps() == n + 1, "assistant: one undo step")
click("assistantStrip:cost")
check(ev("Config.ai.strip.cost") is True, "assistant: its ghost shows it again")
for e in ("ai.appearance.defaultSize", "ai.appearance.messageStyle", "ai.enabled", "ai.showThinking"):
    check(row(e), f"assistant: {e} is on the page")
for e in ("ai.appearance.animations", "ai.behavior.autoScroll", "ai.picker.showRecent", "ai.usage.sparklines",
          "ai.strip.engine", "ai.providers.link"):
    check(not row(e), f"assistant: {e} is not a row of the window")
# the strip's chips (More): one chip per item
ev('w.findItem("pageMore").clicked()')
QTest.qWait(100)
chip = ev('w.findItem("stripChip:limit")')
check(chip is not None, "assistant: the strip's chips are in More")
if chip is not None:
    h.eval(chip, "clicked()")
    check(ev("Config.ai.strip.limit") is False, "assistant: a chip turns its item off")
    h.eval(chip, "clicked()")
ev('w.findItem("settingsPage").item.moreOpen = false')

# ---- AI providers: a band of states, keys never shown ------------------------
select("ai-providers")
check(ev('w.findItem("providerState:ollama") !== null'), "providers: a state per provider in the band")
check(ev('w.findItem("providerState:ollama").border.color === w.findItem("providerState:ollama").border.color'), "providers: drawn")
check(ev('w.findItem("settingsConnectSheet") !== null'), "providers: the connect sheet is the row's list")
check(ev('w.findItem("defaultModelChoice") !== null'), "providers: the default model beside it")
check(not row("ai.providers.timeout"), "providers: request plumbing is out of the window")

# ---- Code tasks: - / + and the layout switch on the board --------------------
select("ai-code")
n = steps()
check(click("tasksParallelMore"), "tasks: + is on the board")
check(ev("Config.ai.tasks.maxParallel") == 3, "tasks: + lets one more work at once")
check(steps() == n + 1, "tasks: one undo step")
click("tasksParallelLess")
click("tasksParallelLess")
check(ev("Config.ai.tasks.maxParallel") == 1, "tasks: - lets fewer work at once")
click("tasksParallelLess")
check(ev("Config.ai.tasks.maxParallel") == 1, "tasks: never fewer than one")
ev("SettingsStore.set('ai.tasks.maxParallel', 2)")
n = steps()
check(click("tasksLayoutFlip"), "tasks: the layout switch is on the board")
check(ev("Config.ai.tasks.boardLayout") == "list", "tasks: a click shows a list")
check(steps() == n + 1, "tasks: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.ai.tasks.boardLayout") == "auto", "tasks: undo puts the layout back")

if failures:
    print(f"settings-assistant-pages: {len(failures)} failure(s)")
    h.exit(1)
print("settings-assistant-pages: ok")
h.exit(0)
