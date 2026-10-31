#!/usr/bin/env python3
"""Render the dashboard offscreen (private Xvfb, never the live desktop).

    tools/render/dashboard_render.py [--out DIR] [--mode dark|light]
                                     [--variants stage,stage-idle,composed,...]
                                     [LANGUAGE ...]

Draws the real dashboard frame (header + widgets tab) on the popup surface
over your wallpaper, with your config and palette (see settings_render.py)
and sample data from tests/lib/dashboard_env.py: a playing track (its art is
your wallpaper), three notifications, sample events and a Pomodoro. Variants:
the stage home (playing; idle = nothing playing; empty = idle without
events, timers or notifications; low = a short screen; narrow = a narrow
one; month = the week's month detail; flat = tint and metrics off; focus =
the keyboard focus ring on a tile), the
composed home (without notifications, taller, with the output devices /
Wi-Fi / Bluetooth details open) and the bento grid.
Writes <out>/dashboard-<variant>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from dashboard_env import DashboardEnv  # noqa: E402
from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# variant -> options: home, notifications (None = the samples), playing, events,
# timers, detail, height / width (0 = natural), layout overrides.
STAGE = {"home": "stage", "events": True, "timers": True}
VARIANTS = {
    "stage": STAGE,
    "stage-idle": {**STAGE, "playing": False},
    "stage-empty": {**STAGE, "playing": False, "events": False, "timers": False, "notifications": []},
    "stage-low": {**STAGE, "height": 540},
    "stage-narrow": {**STAGE, "width": 760},
    "stage-month": {**STAGE, "detail": "month"},
    "stage-flat": {**STAGE, "layout": {"heroTint": False, "showMetrics": False}},
    "stage-focus": {**STAGE, "focus": "nightToggle"},
    "composed": {"home": "composed"},
    "composed-empty": {"home": "composed", "notifications": []},
    "composed-tall": {"home": "composed", "height": 640},
    "composed-devices": {"home": "composed", "detail": "output"},
    "composed-wifi": {"home": "composed", "detail": "wifi"},
    "composed-bluetooth": {"home": "composed", "detail": "bluetooth"},
    "bento": {"home": "bento"},
}
SAMPLE_TIMERS = [{"name": "", "leftMs": 17 * 60000 + 24000, "pomodoro": True}]


def sample_events() -> str:
    """khal-like rows from now on: in 40 min, later today, tomorrow."""
    now = datetime.now()
    rows = [(now + timedelta(minutes=40), "Sync with Mira"), (now + timedelta(hours=2, minutes=30), "Deck review"),
            ((now + timedelta(days=1)).replace(hour=10, minute=0), "Dentist")]
    return json.dumps([{"date": t.strftime("%Y-%m-%d"), "time": t.strftime("%H:%M"), "title": title} for t, title in rows])


SCENE = """
import QtQuick
import QtQuick.Window
import qs.modules.components.kit
import qs.modules.widgets.dashboard
Window {
    id: win
    property url wallpaper: ""
    width: surface.width + 96; height: surface.height + 96; visible: true; color: "black"
    Image { anchors.fill: parent; source: win.wallpaper; fillMode: Image.PreserveAspectCrop }
    Surface {
        id: surface
        anchors.centerIn: parent
        Dashboard { objectName: "dashboard"; width: implicitWidth; height: implicitHeight }
    }
}"""


def render(name: str, path: Path, state: dict, colors: dict, overrides: dict, opts: dict | None = None,
           user_config: bool = True) -> Path:
    """One dashboard scene: `overrides` ({domain: {...}}) over the defaults
    and your config (user_config=False: the defaults only), `colors` as
    the palette, `opts` a VARIANTS entry."""
    opts = opts or {}
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    env = DashboardEnv(name, notifications=opts.get("notifications"), art=url, palette=colors, user_config=user_config,
                       overrides=overrides, wallpaper=state, playing=opts.get("playing", True),
                       timers=SAMPLE_TIMERS if opts.get("timers") else [])
    win = env.load(SCENE)
    win.setProperty("wallpaper", url)
    dash = env.h.find(win, "dashboard")
    if opts.get("events"):
        cal = env.h.find(win, "calendarEvents")
        env.h.eval(cal, "available = true")
        env.h.eval(cal, f"this.events = {sample_events()}")
    if opts.get("detail"):
        env.h.eval(dash, f"widgetsItem.detail = {opts['detail']!r}")
    if opts.get("focus"):
        win.requestActivate()
        QTest.qWait(100)
        env.h.eval(env.h.find(win, opts["focus"]), "forceActiveFocus()")
        env.h.eval(dash, "FocusState.keyboard = true")
    if opts.get("height"):
        env.h.eval(dash, f"implicitHeight = {opts['height']}")
    if opts.get("width"):
        env.h.eval(dash, f"implicitWidth = {opts['width']}")
    QTest.qWait(1200)
    win.grabWindow().save(str(path))
    print(path, flush=True)
    win.close()
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--variants", default=",".join(VARIANTS))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for variant in args.variants.split(","):
        opts = VARIANTS[variant]
        suffix = "-light" if args.mode == "light" else ""
        for lang in args.languages:
            overrides = {"theme": {"language": lang, "lightMode": args.mode == "light"},
                         "layout": {"dashboard": {"home": opts["home"], **opts.get("layout", {})}}}
            render(f"dashboard-render-{variant}-{lang}", out / f"dashboard-{variant}-{lang}{suffix}.png", state,
                   palette(args.mode, state), overrides, opts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
