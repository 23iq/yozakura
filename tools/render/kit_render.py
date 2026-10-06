#!/usr/bin/env python3
"""Render the shared UI kit sheet offscreen (private Xvfb, never the live desktop).

    tools/render/kit_render.py [--out DIR] [--mode dark|light] [LANGUAGE ...]

Draws tools/render/KitGallery.qml (every modules/components/kit component in
its states) once per visual language (ink, glass, tiles by default) with your
real config, palette and wallpaper (see settings_render.py). Writes
<out>/kit-<language>.png.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES, KitEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        theme = {"language": lang, "lightMode": args.mode == "light"}
        env = KitEnv(f"kit-render-{lang}", gallery=True, palette=palette(args.mode, state), user_config=True,
                     overrides={"theme": theme}, wallpaper=state)
        win = env.load("import qs.kitgallery\nKitGallery {}")
        win.setProperty("wallpaper", url)
        win.setProperty("art", url)
        win.setProperty("language", lang)
        QTest.qWait(900)
        path = out / f"kit-{lang}.png"
        win.grabWindow().save(str(path))
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
