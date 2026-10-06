#!/usr/bin/env python3
"""Render the tools menu styles offscreen (private Xvfb, never the live desktop).

    tools/render/tools_render.py [--out DIR] [--mode dark|light] [--style S ...] [LANGUAGE ...]

Draws layout.tools.style radial / notch once per visual language (ink,
glass, tiles by default) with your real config, palette and wallpaper (see
settings_render.py), each at rest (Screenshot focused) and "recording" (a
recording runs: the record tool is active, its time in the caption).
Writes <out>/tools-<style>[-recording]-<language>.png. Nothing runs: the
services are stubs.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from menus_env import LANGUAGES, MenusEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

STYLES = ["radial", "notch"]
RECORD = "ScreenRecorder.isRecording = true; ScreenRecorder.duration = '00:42'; "

# style -> (scene QML, rest JS, recording JS); the JS runs in the style
# file's scope (its ToolsModel's context); RECORD runs in the scene's.
# Radial items skip separators.
SCENES = {
    "radial": ("Styles.Radial { objectName: 'style'; anchors.fill: parent; shown: true; focus: true;"
               " cursor: Qt.point(640, 360); area: ({x: 0, y: 40, w: 1280, h: 680}) }",
               "menu.currentIndex = 0", "menu.currentIndex = 2"),
    "notch": ("StyledRect { variant: 'bg'; anchors.horizontalCenter: parent.horizontalCenter; y: -radius;"
              " width: s.implicitWidth + Space.xl * 2; height: s.implicitHeight + Space.l * 2 + radius;"
              " radius: Styling.radius(8)\n"
              "  ToolsMenu { id: s; objectName: 'style'; x: Space.xl; y: parent.radius + Space.l;"
              " width: implicitWidth; height: implicitHeight; focus: true } }",
              "strip.select(0)", "strip.select(3)"),
}


def scene(style: str, wall: str) -> str:
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.services
import qs.modules.widgets.tools
import qs.modules.widgets.tools.styles as Styles
Window {{
    width: 1280; height: 720; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    {SCENES[style][0]}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--style", action="append", choices=STYLES, help="style(s) to draw (default: all)")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        env = MenusEnv(f"tools-render-{lang}", palette=palette(args.mode, state), user_config=True,
                       overrides={"theme": {"language": lang, "lightMode": args.mode == "light"}}, wallpaper=state)
        for style in args.style or STYLES:
            win = env.load(scene(style, url))
            win.requestActivate()
            model = env.h.find(win, "toolsModel")
            QTest.qWait(700)
            for name, js in (("", SCENES[style][1]), ("-recording", SCENES[style][2])):
                if name:
                    env.h.eval(win, RECORD)
                env.h.eval(model, js)
                QTest.qWait(300)
                path = out / f"tools-{style}{name}-{lang}.png"
                win.grabWindow().save(str(path))
                print(path)
            env.h.eval(win, "ScreenRecorder.isRecording = false")
            win.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
