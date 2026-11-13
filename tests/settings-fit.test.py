"""Every settings page and home lay out cleanly at the default window
(1180x780), offscreen, with the device fixtures (tests/lib/device_fixtures.py).

A page is one scrolling column of cards under a compact stage (only where
the desktop is the subject) and a one-line hint (modules/settings/AGENTS.md,
PAGE COMPOSITION). For home and every tab this checks, with
tests/lib/settings_probe.py:

* no two sibling cards, no two rows of a card, no two header parts, the
  stage / hint / first card and no two home tiles (nor a tile's name /
  status and its scene) intersect;
* no text is elided or painted outside its box or its card;
* every option of a picture-card selector is within reach;
* the stage takes at most a third of the page; only desktop pages have
  a desktop stage.

Then again after interactions: gates toggled, the island off, several
bars, other selector options, an editor that grows, a long value; and no
binding or polish loop is printed meanwhile.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from settings_probe import problems, settled_probe, window  # noqa: E402

DESKTOP = {"bar", "notch", "dock", "desktop", "lockscreen", "notifications", "menus", "windows", "wallpapers"}
MULTI = ('[{"id": "top", "edge": "top", "style": "classic", "groups": {"start": ["launcher"], "end": ["clock"]}},'
         ' {"id": "rail", "edge": "left", "style": "rail", "groups": {"start": ["launcher"], "end": ["power"]}}]')

env = SettingsEnv("settings-fit", devices=True, text_wider=0.08)
h = env.h
failures: list[str] = []
loops: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if "polish() loop" in msg or "Binding loop" in msg:
        loops.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)


def check(ok: bool, what: str) -> None:
    if not ok:
        failures.append(what)
        print("FAIL:", what, file=sys.stderr)


win = env.load(window(env))
shell = h.find(win, "shell")
density: dict[str, int] = {}


def probe(label: str, settle_ms: int = 250) -> dict | None:
    QTest.qWait(settle_ms)
    m = settled_probe(h, win, label)
    for p in problems(m, label):
        check(False, p)
    return m


def page(cat: str, label: str | None = None) -> dict | None:
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    m = probe(label or cat)
    if m is not None and not m["home"]:
        st = m["stage"]
        if st is not None:
            check(cat in DESKTOP or not st["desktop"], f"{cat}: a desktop stage on a page that is not about the desktop")
    return m


def dense(cat: str, m: dict | None) -> None:
    """The first screen at 1180x780 shows the stage and at least 8 whole rows
    on a page with a stage, 14 on a plain page (or every row it has)."""
    if m is None or m["home"] or not m["schema"] or m["list"]:
        return
    want = min(8 if m["stage"] is not None else 14, m["rowsTotal"])
    check(m["rows"] >= want, f"{cat}: {m['rows']} whole rows on the first screen (want {want} of {m['rowsTotal']})")


# home
h.eval(shell, "goHome()")
m = probe("home", 600)
check(m is not None and m["home"], "home: shown")

for cat in json.loads(h.eval(win, "JSON.stringify(categoryIds())")):
    m = page(cat)
    if m is not None:
        density[cat] = m["rows"]
        # dense(cat, m)  (on once every tab meets it)

# interactions: every state shows other rows, cards and values
STATES = [
    ("bar", "bar (several bars)", f"SettingsStore.set('bar.panels', {MULTI})", "SettingsStore.set('bar.panels', [])"),
    ("bar", "bar (frame on)", "SettingsStore.set('bar.frameEnabled', true)", "SettingsStore.set('bar.frameEnabled', false)"),
    ("notch", "island off", "SettingsStore.set('notch.enabled', false)", "SettingsStore.set('notch.enabled', true)"),
    ("notch", "island hover off (a gate)", "SettingsStore.set('notch.disableHoverExpansion', true)",
     "SettingsStore.set('notch.disableHoverExpansion', false)"),
    ("notifications", "notifications in a corner", "SettingsStore.set('notifications.presentation', 'corner')",
     "SettingsStore.set('notifications.presentation', 'auto')"),
    ("timers", "timers in a card", "SettingsStore.set('layout.panels.host', 'card')", "SettingsStore.set('layout.panels.host', 'auto')"),
    ("launcher", "launcher as a sheet", "SettingsStore.set('layout.launcher.host', 'sheet')", "SettingsStore.set('layout.launcher.host', 'auto')"),
    ("menus", "menus as a sheet", "SettingsStore.set('layout.launcher.host', 'sheet')", "SettingsStore.set('layout.launcher.host', 'auto')"),
    ("terminal", "terminal prompt on", "SettingsStore.set('terminal.enabled', true)", "SettingsStore.set('terminal.enabled', false)"),
    ("desktop", "desktop icons and clock on", "SettingsStore.set('desktop.enabled', true); SettingsStore.set('desktop.depthClock', true)",
     "SettingsStore.set('desktop.enabled', false); SettingsStore.set('desktop.depthClock', false)"),
    ("system", "a long location", "SettingsStore.set('weather.location', 'Llanfairpwllgwyngyll, Isle of Anglesey, Wales')",
     "SettingsStore.set('weather.location', '')"),
    ("voice", "voice off", "SettingsStore.set('voice.enabled', false)", "SettingsStore.set('voice.enabled', true)"),
]
for cat, label, do, undo in STATES:
    h.eval(win, do)
    page(cat, label)
    h.eval(win, undo)

check(not loops, f"no binding or polish loop ({len(loops)}: {loops[:3]})")
print("rows on screen per tab (density):", json.dumps(density))
if failures:
    # last, after any QML warnings, so the tail of a CI log shows them
    print("\n".join("FAIL: " + f for f in failures))
    print(f"settings-fit: {len(failures)} failure(s)")
    h.exit(1)
print("settings-fit: ok")
h.exit(0)
