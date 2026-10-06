#!/usr/bin/env python3
"""Render Settings > Displays, the keep/revert prompt and the identify card
offscreen (private Xvfb, never the desktop).

    tools/render/displays_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1000]

Two fake monitors (a 240 Hz capable 1440p and a 1080p) behind the scripted
backend of tests/lib/displays_env.py; palette and wallpaper come from your
setup like settings_render.py. Writes <out>/<view>-<mode>.png.
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

from displays_env import DisplaysEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

CONFLICT = {"file": "~/.config/hypr/monitors.conf", "line": 3, "text": "monitor=DP-1,preferred,auto,1"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "displays"))
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
    env = DisplaysEnv(f"displays-{mode}", palette=palette(mode, state), user_config=True, wallpaper=state,
                      overrides={"theme": {"lightMode": mode == "light"}},
                      replies={"displays.conflicts": [CONFLICT]})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.shell
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.displays
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
    Item {{
        objectName: "prompt"; anchors.fill: parent; visible: false
        Rectangle {{ anchors.fill: parent; color: Colors.background; opacity: 0.6 }}
        DisplayConfirmCard {{ anchors.centerIn: parent }}
    }}
    Item {{
        objectName: "identify"; anchors.fill: parent; visible: false
        DisplayIdentifyCard {{ anchors.centerIn: parent; shown: true; entry: ({{"name": "DP-1", "index": 1}}) }}
    }}
}}""")
    ev = env.h.eval
    shell = env.h.find(win, "shell")

    def snap(name: str, wait: int = 900) -> None:
        QTest.mouseMove(win, QPoint(60, h - 30))
        QTest.qWait(wait)
        path = out / f"{name}-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)

    ev(shell, 'select("displays")')
    snap("page", 2500)
    page = env.h.find(win, "settingsPage").property("item")
    ev(page, "edit('DP-1', {refresh: 240})")
    ev(page, "edit('HDMI-A-1', {scale: 1.25})")
    snap("page-edited")
    ev(page, "selectedName = 'HDMI-A-1'")
    ev(page, "edit('DP-1', {enabled: true})")
    snap("page-second")
    ev(win, "DisplaysService.session = {id: 's', state: 'pending', remaining: 15, live: true}")
    ev(win, "DisplaysService.session = {id: 's', state: 'pending', remaining: 11, live: true}")
    env.h.find(win, "prompt").setProperty("visible", True)
    snap("confirm", 1400)
    ev(win, "DisplaysService.session = {id: 's', state: 'pending', remaining: 4, live: true}")
    snap("confirm-urgent", 1400)
    env.h.find(win, "prompt").setProperty("visible", False)
    env.h.find(win, "identify").setProperty("visible", True)
    snap("identify", 700)


if __name__ == "__main__":
    sys.exit(main())
