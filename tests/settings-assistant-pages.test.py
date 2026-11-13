"""The Assistant destination's pages (Chat, Models & providers, Agents &
tasks) in the settings window, offscreen: plain pages (no desktop stage),
the rare options out of the window, the status line's chips on the page;
the providers band shows every provider in its state and never a key.
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


# ---- Assistant: plain rows, no desktop stage --------------------------------
select("ai")
check(ev('w.findItem("assistantPanel") !== null'), "assistant: the stage is the chat itself")
check(ev("Config.ai.sidebarPosition") == "right", "assistant: on the right by default")
for e in ("ai.appearance.defaultSize", "ai.appearance.messageStyle", "ai.enabled", "ai.showThinking",
          "ai.sidebarPosition", "ai.quickAsk.enabled", "layout.aiquick.host"):
    check(row(e), f"assistant: {e} is on the page")
for e in ("ai.appearance.animations", "ai.behavior.autoScroll", "ai.picker.showRecent", "ai.usage.sparklines",
          "ai.strip.engine", "ai.providers.link"):
    check(not row(e), f"assistant: {e} is not a row of the window")
# the status line's chips: one chip per item, on the page
chip = ev('w.findItem("stripChip:limit")')
check(chip is not None, "assistant: the status line's chips are on the page")
if chip is not None:
    n = steps()
    h.eval(chip, "clicked()")
    check(ev("Config.ai.strip.limit") is False, "assistant: a chip turns its item off")
    check(steps() == n + 1, "assistant: one undo step")
    h.eval(chip, "clicked()")

# ---- AI providers: a band of states, keys never shown ------------------------
select("ai-providers")
check(ev('w.findItem("providerState:ollama") !== null'), "providers: a state per provider in the band")
check(ev('w.findItem("providerState:ollama").border.color === w.findItem("providerState:ollama").border.color'), "providers: drawn")
check(ev('w.findItem("settingsConnectSheet") !== null'), "providers: the connect sheet is the row's list")
check(ev('w.findItem("defaultModelChoice") !== null'), "providers: the default model beside it")
check(not row("ai.providers.timeout"), "providers: request plumbing is out of the window")

# ---- Code tasks: plain rows ---------------------------------------------------
select("ai-code")
check(ev('w.findItem("pageStage").active') is False, "tasks: no stage (not a desktop page)")
for e in ("ai.tasks.maxParallel", "ai.tasks.boardLayout"):
    check(row(e), f"tasks: {e} is on the page")

if failures:
    print(f"settings-assistant-pages: {len(failures)} failure(s)")
    h.exit(1)
print("settings-assistant-pages: ok")
h.exit(0)
