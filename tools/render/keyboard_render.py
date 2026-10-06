#!/usr/bin/env python3
"""Render Settings > Keyboard and the bar layout indicator offscreen (private
Xvfb, never the desktop).

    tools/render/keyboard_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1500]

Two layouts (English, Russian) behind the scripted backend of
tests/lib/keyboard_env.py; palette and wallpaper come from your setup like
settings_render.py. Writes <out>/<view>-<mode>.png.
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

from keyboard_env import KeyboardEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

LAYOUTS = [{"layout": "us", "variant": ""}, {"layout": "ru", "variant": "phonetic"}]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "keyboard"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1280x1500")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for mode in (["dark", "light"] if args.mode == "both" else [args.mode]):
        render(mode, state, out, w, h)
    return 0


def render(mode: str, state: dict, out: Path, w: int, h: int) -> None:
    env = KeyboardEnv(f"keyboard-{mode}", palette=palette(mode, state), user_config=True, wallpaper=state,
                      overrides={"theme": {"lightMode": mode == "light"},
                                 "keyboard": {"layouts": LAYOUTS, "options": ["caps:escape"], "repeatRate": 35}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.theme
import qs.modules.services
import qs.modules.bar.modules
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
    Item {{
        id: barDemo; objectName: "barDemo"; anchors.fill: parent; visible: false
        Rectangle {{ anchors.fill: parent; gradient: Gradient {{
            GradientStop {{ position: 0; color: Colors.primaryContainer }}
            GradientStop {{ position: 1; color: Colors.background }} }} }}
        Item {{ id: fakeBar; property string orientation: "horizontal"; property int moduleSize: 40
            property bool flat: false; property string panelStyle: "classic"; property string barPosition: "top" }}
        Item {{ id: fakeVBar; property string orientation: "vertical"; property int moduleSize: 40
            property bool flat: false; property string panelStyle: "classic"; property string barPosition: "left" }}
        Row {{ x: 24; y: 20; spacing: 14
            KeyboardLayoutIndicator {{ bar: fakeBar }}
            KeyboardLayoutIndicator {{ bar: fakeBar; forceFlat: true }}
            KeyboardLayoutIndicator {{ bar: fakeVBar }}
        }}
    }}
}}""")
    ev = env.h.eval
    shell = env.h.find(win, "shell")

    def snap(name: str, wait: int = 900, crop: tuple | None = None) -> None:
        QTest.mouseMove(win, QPoint(60, h - 30))
        QTest.qWait(wait)
        path = out / f"{name}-{mode}.png"
        img = win.grabWindow()
        (img.copy(*crop) if crop else img).save(str(path))
        print(path)

    ev(win, "BackendService.emit('keyboard.layout', {name: 'English (US)', index: 0, code: 'us', short: 'EN'})")
    ev(shell, 'select("keyboard")')
    snap("page", 2500)
    page = env.h.find(win, "settingsPage").property("item")
    ev(env.h.find(win, "layoutList"), "picking = true")
    snap("picker")
    ev(env.h.find(win, "layoutList"), "picking = false")
    ev(env.h.find(win, "optionsCard"), "showAll = true; openGroup = 'caps'")
    ev(page, "contentY = 520")
    snap("options")
    env.h.find(win, "barDemo").setProperty("visible", True)
    snap("indicator", 700, (0, 0, 360, 120))


if __name__ == "__main__":
    sys.exit(main())
