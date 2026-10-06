#!/usr/bin/env python3
"""Render Settings > Terminal & Apps with the app connection pills offscreen
(private Xvfb, never the desktop).

    tools/render/apphooks_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1000]

One app per hook state (connected, restart needed, Connect, managed, error,
absent) behind the scripted backend of tests/lib/apphooks_env.py; palette and
wallpaper come from your setup like settings_render.py. Writes
<out>/terminal-<mode>.png.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from apphooks_env import AppHooksEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "apphooks"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1280x1000")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for mode in (["dark", "light"] if args.mode == "both" else [args.mode]):
        render(mode, state, out, w, h)
    return 0


def render(mode: str, state: dict, out: Path, w: int, h: int) -> None:
    env = AppHooksEnv(f"apphooks-{mode}", palette=palette(mode, state), user_config=True, wallpaper=state,
                      overrides={"theme": {"lightMode": mode == "light"}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
    env.h.eval(env.h.find(win, "shell"), 'select("terminal")')
    page = env.h.find(win, "settingsPage").property("item")
    env.h.eval(page, "contentY = 1000000")  # the theming section is last
    QTest.mouseMove(win, QPoint(60, h - 30))
    QTest.qWait(2500)
    path = out / f"terminal-{mode}.png"
    win.grabWindow().save(str(path))
    print(path)


if __name__ == "__main__":
    sys.exit(main())
