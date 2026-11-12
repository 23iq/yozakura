"""The System destination's composed pages (Voice, Timers, Routines, ...)
in the settings window, offscreen: a click on a stage changes its key as
one undo step, the custom editors write their keys, the band acts.
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


# ---- Voice: the key on the stage switches hold / tap ---------------------------
select("voice")
check(ev("Config.voice.activation") == "push-to-talk", "voice: hold to talk by default")
n = steps()
check(click("voiceActivationFlip"), "voice: the key on the stage is clickable")
check(ev("Config.voice.activation") == "toggle", "voice: a click on the key switches to tap")
check(steps() == n + 1, "voice: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.voice.activation") == "push-to-talk", "voice: undo puts it back")
ev("SettingsStore.set('voice.enabled', false)")
QTest.qWait(50)
check(ev('w.findItem("voiceActivationFlip").enabled') is False, "voice: off, the key does nothing")
ev("SettingsStore.set('voice.enabled', true)")

# ---- Timers: the island's time shows / hides seconds; the Pomodoro card -------
select("timers")
n = steps()
check(click("timersSecondsFlip"), "timers: the island's time is clickable")
check(ev("Config.system.timers.showSeconds") is False, "timers: a click hides the seconds")
check(steps() == n + 1, "timers: one undo step")
ev("SettingsStore.undo()")
check(ev("Config.system.timers.showSeconds") is True, "timers: undo shows them again")
h.eval(ev('w.findItem("pomodoroWorkStep")'), "step(1)")
check(ev("Config.system.pomodoro.workTime") == 1800, "timers: + on Focus adds five minutes (in seconds)")
h.eval(ev('w.findItem("pomodoroRestStep")'), "step(-1)")
check(ev("Config.system.pomodoro.restTime") == 240, "timers: - on Break takes a minute")
h.eval(ev('w.findItem("pomodoroAutoSwitch")'), "toggled(true)")
check(ev("Config.system.pomodoro.autoStart") is True, "timers: the switch starts the next phase on its own")
check(ev('w.findItem("settingRow:system.pomodoro.workTime")') is None, "timers: the raw seconds are not a row")

if failures:
    print(f"settings-system-pages: {len(failures)} failure(s)")
    h.exit(1)
print("settings-system-pages: ok")
h.exit(0)
