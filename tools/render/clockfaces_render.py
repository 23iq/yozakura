#!/usr/bin/env python3
"""Render the bar clock faces offscreen (private Xvfb, never the live desktop).

    tools/render/clockfaces_render.py [--out DIR] [--mode dark|light]
                                      [--seed HEX] [--faces a,b] [LANGUAGE ...]

Every face of modules/bar/clock/ClockFaces.js (digital, stacked, dot matrix,
kanji, segment) on a bar-like module box, 24h and 12h on a horizontal bar
and upright on a vertical one, per visual language, with your real config,
palette and wallpaper (see settings_render.py; `--seed` generates a palette
from one colour). Writes <out>/clockfaces-<language>.png.
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

FACES = ["digital", "stacked", "dotMatrix", "kanji", "segment"]
# One face in a bar module box: (vertical bar, 12h).
CELL = """StyledRect {{
    variant: "bg"
    radius: Styling.radius(0)
    width: face{i}.implicitWidth + 2 * Space.m
    height: face{i}.implicitHeight + 2 * Space.s
    ClockFace {{
        id: face{i}
        anchors.centerIn: parent
        face: {face}
        vertical: {vertical}
        use12h: {use12h}
        textColor: Colors.overBackground
        fontWeight: Font.Bold
        now: new Date(2026, 9, 31, 21, 47)
    }}
}}"""


def scene(wall: str, faces: list[str]) -> str:
    rows = []
    for n, face in enumerate(faces):
        cells = [CELL.format(i=f"{n}_{k}", face=json.dumps(face), vertical=v, use12h=t)
                 for k, (v, t) in enumerate([("false", "false"), ("false", "true"), ("true", "false")])]
        rows.append("Row { spacing: Space.l\n" + "\n".join(cells) + "\n}")
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import "modules/bar/clock"
Window {{
    width: col.implicitWidth + 2 * Space.xl
    height: col.implicitHeight + 2 * Space.xl
    visible: true
    color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    Column {{
        id: col
        x: Space.xl; y: Space.xl
        spacing: Space.l
        {chr(10).join(rows)}
    }}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--seed", default="", help="palette from this seed colour (matugen), e.g. '#4c8f5a'")
    ap.add_argument("--faces", default=",".join(FACES))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        theme = {"language": lang, "lightMode": args.mode == "light", "animDuration": 0}
        env = WidgetsEnv(f"clockfaces-render-{lang}", palette=palette(args.mode, state, args.seed), user_config=True,
                         overrides={"theme": theme}, wallpaper=state)
        qml = scene(url, args.faces.split(","))
        win = env.h.load(env.h.write(qml, dest="qs", name="ClockFacesScene.qml"), auto_stub=False)
        QTest.qWait(500)
        target = out / f"clockfaces-{lang}.png"
        win.grabWindow().save(str(target))
        print(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
