"""Home and every settings tab at the window's minimum size (640x480), in
Russian (the longest strings), offscreen: no overlap, no cut or elided
text, every picture option within reach, a stage of a third of the page at
most (tests/lib/settings_probe.py; the default size is settings-fit).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from settings_probe import Sweep, window  # noqa: E402
from waits import settle  # noqa: E402

env = SettingsEnv("settings-fit-min", devices=True, text_wider=0.08)
win = env.load(window(env))
win.resize(640, 480)
settle(5)
sweep = Sweep(env, win)
sweep.language("ru")
# (the one-screen pages Displays, Keyboard and About stack their cards
# here and scroll: FittedFrame.stacked)
sweep.all(" (640x480, ru)")

if sweep.failures:
    # last, after any QML warnings, so the tail of a CI log shows them
    print("\n".join("FAIL: " + f for f in sweep.failures))
    print(f"settings-fit-min: {len(sweep.failures)} failure(s)")
    env.h.exit(1)
print("settings-fit-min: ok")
env.h.exit(0)
