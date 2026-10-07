#!/usr/bin/env python3
"""Render every bento widget offscreen (private Xvfb, never the live desktop).

    tools/render/widgets_render.py [--out DIR] [--mode dark|light]
                                   [--sizes default,min,edit] [LANGUAGE ...]

Each widget of modules/widgets/dashboard/widgets/WidgetRegistry.js in a real
BentoTile at its default size and at its minimum size ("edit": default size
with the edit chrome), on one popup surface per language (ink, glass,
tiles by default), with your real config, palette and wallpaper (see
settings_render.py) and fixture services (tests/lib/widgets_env.py).
Writes <out>/widgets-<size>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from widgets_env import WidgetsEnv  # noqa: E402

REGISTRY = REPO / "modules/widgets/dashboard/widgets/WidgetRegistry.js"
CELL = 132
GAP = 8


def registry() -> list[dict]:
    code = ("const fs=require('fs');const s=fs.readFileSync(process.argv[1],'utf8').replace('.pragma library','');"
            "const m={};new Function('m',s+';m.w=widgets;')(m);console.log(JSON.stringify(m.w));")
    out = subprocess.run(["node", "-e", code, str(REGISTRY)], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def scene(size: str, wall: str) -> str:
    tiles = []
    for w in registry():
        cw, ch = (w["minW"], w["minH"]) if size == "min" else (w["defaultW"], w["defaultH"])
        tiles.append({"id": w["id"], "w": cw, "h": ch})
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.components.kit
import qs.modules.services
import "modules/widgets/dashboard/widgets"
import "modules/widgets/dashboard/widgets/WidgetRegistry.js" as Registry
Window {{
    id: win
    width: 1240; height: 1080; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    Surface {{
        id: panel
        x: 24; y: 24
        width: win.width - 48
        Flow {{
            width: panel.width - panel.padding * 2
            spacing: {GAP * 2}
            Repeater {{
                model: {json.dumps(tiles)}
                Item {{
                    required property var modelData
                    width: modelData.w * {CELL} + (modelData.w - 1) * {GAP}
                    height: modelData.h * {CELL} + (modelData.h - 1) * {GAP}
                    BentoTile {{
                        entry: Registry.byId(parent.modelData.id)
                        cell: ({{ "x": 0, "y": 0, "w": parent.modelData.w, "h": parent.modelData.h }})
                        cellW: {CELL}; cellH: {CELL}; gap: {GAP}
                        editing: {"true" if size == "edit" else "false"}
                    }}
                }}
            }}
        }}
    }}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--sizes", default="default,min")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        theme = {"language": lang, "lightMode": args.mode == "light", "animDuration": 0}
        env = WidgetsEnv(f"widgets-render-{lang}", palette=palette(args.mode, state), user_config=True,
                         overrides={"theme": theme}, wallpaper=state)
        for size in args.sizes.split(","):
            path = env.h.write(scene(size, url), dest="qs", name=f"Scene{size.capitalize()}.qml")
            win = env.h.load(path, auto_stub=False)
            env.timers(win)
            QTest.qWait(700)
            target = out / f"widgets-{size}-{lang}.png"
            win.grabWindow().save(str(target))
            print(target)
            win.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
