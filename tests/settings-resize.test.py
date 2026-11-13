"""Resizing the settings window through its breakpoints, offscreen: home
and the page bento change their column count once each way, never back
and forth (hysteresis), from the default width down to the minimum and
back (settings-stability.test.py: nothing moves on its own or on hover).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from settings_probe import window  # noqa: E402
from waits import settle, wait_until  # noqa: E402

env = SettingsEnv("settings-resize", devices=True)
h = env.h
failures: list[str] = []


def check(ok: bool, what: str) -> None:
    if not ok:
        failures.append(what)
        print("FAIL:", what, file=sys.stderr)


win = env.load(window(env))
shell = h.find(win, "shell")


def sweep_columns(prop: str, label: str) -> None:
    widths = list(range(1180, 639, -20)) + list(range(640, 1181, 20))
    seen = []
    for wd in widths:
        win.resize(wd, 780)
        settle(2)
        seen.append(h.eval(win, prop))
    changes = sum(1 for a, b in zip(seen, seen[1:], strict=False) if a != b)
    distinct = len(set(seen))
    # down then up: each change of count happens once each way
    check(changes <= 2 * (distinct - 1), f"{label}: columns flip back and forth while resizing ({seen})")
    win.resize(1180, 780)
    settle(5)


h.eval(shell, 'select("timers")')
env.wait_page(win)
sweep_columns('find("pageBento").fullCols', "page bento")
h.eval(shell, "goHome()")
check(wait_until(lambda: h.eval(win, 'find("settingsHome").opacity') == 1), "home shown")
sweep_columns('find("settingsHome").columns', "home")

h.eval(shell, 'select("timers")')
env.wait_page(win)
sweep_columns('find("pageBento").fullCols', "page bento")
h.eval(shell, "goHome()")
check(wait_until(lambda: h.eval(win, 'find("settingsHome").opacity') == 1), "home shown")
sweep_columns('find("settingsHome").columns', "home")

if failures:
    print(f"settings-resize: {len(failures)} failure(s)")
    h.exit(1)
print("settings-resize: ok")
h.exit(0)
