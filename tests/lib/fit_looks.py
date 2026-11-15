"""Home and the busiest settings tabs in visual languages
(tests/lib/languages.py), dark at the default window size and light at
the minimum, offscreen: no overlap, no cut or elided text, every picture
option within reach (tests/lib/settings_probe.py). A language changes
paddings, radii and boxes, so a layout that fits in one may not in another.

Every language is ~16 page builds, so the sweep is split over PARTS test
files (settings-fit-looks*.test.py); part i takes LANGUAGES[i::PARTS] and
each file stays well inside the per-test watchdog (tests/lib/headless.py).
"""
from __future__ import annotations

PARTS = 3

# a desktop page with a stage, a list page with a band, a long plain page,
# a page of picture cards
TABS = ["bar", "notifications", "network", "ai", "appearance"]


def run(name: str, part: int) -> None:
    import headless

    headless.ensure(gl=True)

    from languages import LANGUAGES
    from PySide6.QtQuick import QQuickWindow  # noqa: F401
    from settings_env import SettingsEnv
    from settings_probe import Sweep, window
    from waits import settle

    env = SettingsEnv(name, devices=True, text_wider=0.2, pin_fonts=True)
    win = env.load(window(env))
    sweep = Sweep(env, win)
    langs = LANGUAGES[part::PARTS]
    # dark at the default size, light at the minimum (the test's time budget)
    for lang in langs:
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
        print(f"{name}: {len(sweep.failures)} failure(s)")
        env.h.exit(1)
    print(f"{name}: ok ({', '.join(langs)})")
    env.h.exit(0)
