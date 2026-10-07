#!/usr/bin/env python3
"""Render the OSD styles offscreen (private Xvfb, never the live desktop).

    tools/render/osd_render.py [--out DIR] [--mode dark|light]
                               [--languages ink,glass,tiles] [STYLE ...]

Draws each style of modules/shell/osd/styles (pill, edge, island,
bar-inline) in the states volume / brightness / muted / device switch, once
per visual language, over your wallpaper with your real config and palette
(see settings_render.py). The edge and pill styles show their vertical (left/right
edge) and horizontal (top/bottom edge) forms. Writes
<out>/osd-<style>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES  # noqa: E402
from osd_env import OsdEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

STYLES = ["pill", "edge", "island", "bar-inline"]
# name -> (kind, value, muted, device)
STATES = [
    ("volume", 0.62, False, ""),
    ("brightness", 0.38, False, ""),
    ("volume", 0.45, True, ""),
    ("volume", 0.62, False, "Headphones"),
]

# One OSD in a state: the style's component at its window size.
CELL = {
    "pill": "OsdPill { vertical: %s; width: implicitWidth; height: implicitHeight; %s }",
    "edge": "OsdEdge { vertical: %s; width: implicitWidth; height: implicitHeight; %s }",
    "island": "OsdIsland { width: implicitWidth; height: implicitHeight; %s }",
    # The bar's controls button, grown by the inline OSD (ControlsButton).
    "bar-inline": """StyledRect {
        variant: "bg"
        radius: Styling.radius(0)
        width: BarMetrics.moduleSize + osd%d.reveal
        height: BarMetrics.moduleSize
        OsdBarInline { id: osd%d; anchors.fill: parent; shown: true; %s }
    }""",
}


def props(state: tuple) -> str:
    kind, value, muted, device = state
    return (f'kind: "{kind}"; value: {value}; muted: {"true" if muted else "false"}; '
            f'device: {json.dumps(device)}; currentDevice: "Speakers"')


def cells(style: str) -> str:
    out = []
    for i, st in enumerate(STATES):
        p = props(st)
        if style in ("edge", "pill"):
            out.append(CELL[style] % ("true", p))
        elif style == "bar-inline":
            out.append(CELL["bar-inline"] % (i, i, p.replace('; currentDevice: "Speakers"', "")))
        else:
            out.append(CELL[style] % p)
    if style in ("edge", "pill"):
        # Horizontal form (top/bottom edge) in a second row.
        row = "\n".join(CELL[style] % ("false", props(st)) for st in STATES)
        return f"Row {{ spacing: Space.xl\n{chr(10).join(out)}\n}}\nGrid {{ columns: 2; spacing: Space.xl\n{row}\n}}"
    return "\n".join(out)


def sheet(style: str, wall: str) -> str:
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.shell.osd.styles
Window {{
    width: col.implicitWidth + 2 * Space.xxl
    height: col.implicitHeight + 2 * Space.xxl
    visible: true
    color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(wall)}; fillMode: Image.PreserveAspectCrop }}
    Column {{
        id: col
        x: Space.xxl; y: Space.xxl
        spacing: Space.xl
        {cells(style)}
    }}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("styles", nargs="*", default=STYLES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--languages", default=",".join(LANGUAGES))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages.split(","):
        theme = {"language": lang, "lightMode": args.mode == "light"}
        env = OsdEnv(f"osd-render-{lang}", palette=palette(args.mode, state), user_config=True,
                     overrides={"theme": theme}, wallpaper=state)
        for style in args.styles:
            win = env.load(sheet(style, url))
            QTest.qWait(900)
            path = out / f"osd-{style}-{lang}.png"
            win.grabWindow().save(str(path))
            win.close()
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
