"""Home and every settings tab in a large window (1600x1000), in Spanish,
offscreen: no overlap, no cut or elided text, every picture option within
reach, a stage of a third of the page at most (tests/lib/settings_probe.py;
the default size is settings-fit, the minimum settings-fit-min).
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

env = SettingsEnv("settings-fit-large", devices=True)
win = env.load(window(env))
win.resize(1600, 1000)
settle(5)
sweep = Sweep(env, win)
sweep.language("es")
sweep.all(" (1600x1000, es)")

if sweep.failures:
    print(f"settings-fit-large: {len(sweep.failures)} failure(s)")
    env.h.exit(1)
print("settings-fit-large: ok")
env.h.exit(0)
