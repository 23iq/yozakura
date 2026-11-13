"""Home and the busiest settings tabs in every visual language
(tests/lib/languages.py), dark at the default window size and light at
the minimum, offscreen: no overlap, no cut or elided text, every picture
option within reach (tests/lib/settings_probe.py). A language changes
paddings, radii and boxes, so a layout that fits in one may not in another.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from languages import LANGUAGES  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from settings_env import SettingsEnv  # noqa: E402
from settings_probe import Sweep, window  # noqa: E402
from waits import settle  # noqa: E402

# a desktop page with a stage, a list page with a band, a long plain page,
# a page of picture cards
TABS = ["bar", "notifications", "network", "ai", "appearance"]

env = SettingsEnv("settings-fit-looks", devices=True, text_wider=0.08)
win = env.load(window(env))
sweep = Sweep(env, win)
# dark at the default size, light at the minimum (the test's time budget)
for lang in LANGUAGES:
    for light, (w, hgt), tabs in ((False, (1180, 780), TABS), (True, (640, 480), TABS[:3])):
        env.h.eval(win, f"SettingsStore.set('theme.language', '{lang}'); SettingsStore.set('theme.lightMode', {str(light).lower()})")
        win.resize(w, hgt)
        settle(5)
        tag = f" ({lang}{' light' if light else ''}, {w}x{hgt})"
        sweep.home("home" + tag)
        for cat in tabs:
            sweep.tab(cat, cat + tag)

if sweep.failures:
    # last, after any QML warnings, so the tail of a CI log shows them
    print("\n".join("FAIL: " + f for f in sweep.failures))
    print(f"settings-fit-looks: {len(sweep.failures)} failure(s)")
    env.h.exit(1)
print("settings-fit-looks: ok")
env.h.exit(0)
