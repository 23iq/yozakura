#!/usr/bin/env python3
"""Render the dashboard offscreen (private Xvfb, never the live desktop).

    tools/render/dashboard_render.py [--out DIR] [--mode dark|light]
                                     [--variants composed,composed-empty,bento]
                                     [LANGUAGE ...]

Draws the real dashboard frame (tab rail + widgets tab) on the popup
surface over your wallpaper, with your config and palette (see
settings_render.py) and sample data from tests/lib/dashboard_env.py: a
playing track, three notifications (none in composed-empty). Variants:
the composed home, the composed home without notifications, the bento grid.
Writes <out>/dashboard-<variant>-<language>.png.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from dashboard_env import DashboardEnv  # noqa: E402
from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# variant -> (layout.dashboard.home, notifications: None = the samples)
VARIANTS = {
    "composed": ("composed", None),
    "composed-empty": ("composed", []),
    "bento": ("bento", None),
}

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


def render(name: str, path: Path, state: dict, colors: dict, overrides: dict,
           notifications: list[dict] | None = None, user_config: bool = True) -> Path:
    """One dashboard scene: `overrides` ({domain: {...}}) over the defaults
    (and your config with user_config) and `colors` as the palette."""
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    env = DashboardEnv(name, notifications=notifications, art=url, palette=colors, user_config=user_config,
                       overrides=overrides, wallpaper=state)
    win = env.load(SCENE)
    win.setProperty("wallpaper", url)
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
        home, notifs = VARIANTS[variant]
        for lang in args.languages:
            overrides = {"theme": {"language": lang, "lightMode": args.mode == "light"},
                         "layout": {"dashboard": {"home": home}}}
            render(f"dashboard-render-{variant}-{lang}", out / f"dashboard-{variant}-{lang}.png", state,
                   palette(args.mode, state), overrides, notifs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
