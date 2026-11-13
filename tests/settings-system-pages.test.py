"""The System and assistant-side pages (Voice, Timers, Routines, Language,
Updates, About) in the settings window, offscreen: the plain stages act
(an update lane follows its channel as one undo step, the routines band
runs), the custom editors write their keys, settings sit in one place.
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

env = SettingsEnv("settings-system-pages")
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
    function centre(name) {
        var it = findItem(name);
        if (!it || !it.visible) return null;
        var p = it.mapToItem(null, it.width / 2, it.height / 2);
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
    QTest.qWait(150)


def click(name) -> bool:
    at = json.loads(h.eval(win, f'JSON.stringify(centre("{name}"))'))
    if not at:
        return False
    QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, QPoint(at[0], at[1]))
    QTest.qWait(50)
    return True


def steps():
    return ev("SettingsStore.undoStack.length")


# ---- Voice: plain rows; the panel opens where the timers do -----------------
select("voice")
check(ev('w.findItem("pageStage").active') is False, "voice: no stage (not a desktop page)")
check(ev("Config.voice.activation") == "push-to-talk", "voice: hold to talk by default")
check(ev('w.findItem("settingRow:voice.activation") !== null'), "voice: the activation row")
link = ev('w.findItem("settingRow:voice.opensLink")')
check(link is not None, "voice: a link to where the panel opens")
check(ev('w.findItem("settingRow:layout.panels.host")') is None, "voice: ...not a second copy of that setting")

# ---- Timers: where the panel opens, the island's look; the Pomodoro card ------
select("timers")
check(ev('w.findItem("settingRow:layout.panels.host") !== null'), "timers: Opens in is on the page")
check(ev('w.findItem("settingRow:system.timers.notchStyle") !== null'), "timers: the island's look is on the page")
h.eval(ev('w.findItem("pomodoroWorkStep")'), "step(1)")
check(ev("Config.system.pomodoro.workTime") == 1800, "timers: + on Focus adds five minutes (in seconds)")
h.eval(ev('w.findItem("pomodoroRestStep")'), "step(-1)")
check(ev("Config.system.pomodoro.restTime") == 240, "timers: - on Break takes a minute")
h.eval(ev('w.findItem("pomodoroAutoSwitch")'), "toggled(true)")
check(ev("Config.system.pomodoro.autoStart") is True, "timers: the switch starts the next phase on its own")
check(ev('w.findItem("settingRow:system.pomodoro.workTime")') is None, "timers: the raw seconds are not a row")

# ---- Routines: the band keeps the example, then runs your routine -----------
select("routines")
check(ev("RoutinesService.routines.length") == 0, "routines: none yet, the band shows an example")
check(click("routinePlay"), "routines: the band's button is clickable")
check(ev("RoutinesService.routines.length") == 1, "routines: + keeps the example as your routine")
check(ev("RoutinesService.routines[0].steps.length") == 3, "routines: with its steps")
QTest.qWait(50)
click("routinePlay")
calls = json.loads(ev("JSON.stringify(RoutinesService.calls)"))
check(any(c[0] == "run" for c in calls), "routines: play runs the routine now")
check(ev('w.findItem("routineStrip") !== null'), "routines: the when -> then strip")

# ---- System: language, weather, OCR languages ------------------------------
select("system")
check(ev('w.findItem("pageStage").active') is False, "system: no stage (not a desktop page)")
check(ev('w.findItem("settingRow:system.ocr") !== null'), "system: the OCR languages are here, not on Updates")
cards = ev('w.findItem("languageCards")')
check(cards is not None, "system: the language as picture cards")

# ---- Updates: one action; a lane follows its channel -----------------------
select("updates")
before = ev("UpdateService.checks")
h.eval(ev('w.findItem("updatesAction")'), "clicked()")
check(ev("UpdateService.checks") == before + 1, "updates: the action checks now")
n = steps()
check(click("updatesLane:beta"), "updates: the beta lane is clickable")
check(ev("Config.system.updateChannel") == "beta", "updates: a click follows the beta channel")
check(steps() == n + 1, "updates: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.system.updateChannel") == "stable", "updates: undo goes back to stable")

# ---- About: the identity scene and a row of cards ----------------------------
select("about")
check(ev('w.findItem("aboutScene") !== null'), "about: the identity scene")
check(ev('w.findItem("aboutLegalNotice") !== null'), "about: the legal notes in their card")
h.eval(ev('w.findItem("aboutUpdates")'), "clicked()")
QTest.qWait(200)
check(h.eval(shell, "currentCategory") == "updates", "about: the version card opens Updates")

if failures:
    print(f"settings-system-pages: {len(failures)} failure(s)")
    h.exit(1)
print("settings-system-pages: ok")
h.exit(0)
