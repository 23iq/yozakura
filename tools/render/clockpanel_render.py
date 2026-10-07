#!/usr/bin/env python3
"""Render the bar clock popup offscreen (private Xvfb, never the live desktop).

    tools/render/clockpanel_render.py [--out DIR] [--mode dark|light]
                                      [--styles column,wide,bento] [--idle]
                                      [LANGUAGE ...]

modules/bar/clock/ClockPanel.qml in each style
(bar.moduleOptions.clock.panelStyle) per visual language (ink, glass, tiles
by default), with your real config, palette and wallpaper (see
settings_render.py) and fixture services (tests/lib/widgets_env.py: weather,
a running Pomodoro unless --idle, a timer and a reminder, three world
clocks). Writes <out>/clockpanel-<style>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from widgets_env import WidgetsEnv  # noqa: E402

ZONES = [{"label": "Tokyo", "zone": "Asia/Tokyo"}, {"label": "London", "zone": "Europe/London"},
         {"label": "New York", "zone": "America/New_York"}]


def scene(wall: str) -> str:
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import "modules/bar/clock"
Window {{
    width: 720; height: 900; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    ClockPanel {{
        objectName: "panel"
        x: 24; y: 24
        width: implicitWidth; height: implicitHeight
        now: new Date(2026, 9, 6, 10, 25)
    }}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--styles", default="column,wide,bento")
    ap.add_argument("--idle", action="store_true", help="no Pomodoro running")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        for style in args.styles.split(","):
            theme = {"language": lang, "lightMode": args.mode == "light", "animDuration": 0}
            bar = {"moduleOptions": {"clock": {"panelStyle": style, "panel": {"cells": []}},
                                     "worldClocks": {"zones": ZONES}}}
            env = WidgetsEnv(f"clockpanel-render-{lang}-{style}", palette=palette(args.mode, state), user_config=True,
                             overrides={"theme": theme, "bar": bar}, wallpaper=state)
            win = env.h.load(env.h.write(scene(url), dest="qs", name="ClockScene.qml"), auto_stub=False)
            env.timers(win, pomodoro=not args.idle)
            QTest.qWait(700)
            target = out / f"clockpanel-{style}-{lang}.png"
            win.grabWindow().save(str(target))
            print(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
