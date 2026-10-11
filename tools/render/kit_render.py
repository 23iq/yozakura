#!/usr/bin/env python3
"""Render the shared UI kit sheet offscreen (private Xvfb, never the live desktop).

    tools/render/kit_render.py [--out DIR] [--mode dark|light] [--sheet NAME] [LANGUAGE ...]

Draws tools/render/KitGallery.qml (every modules/components/kit component in
its states) once per visual language (ink, glass, tiles by default) with your
real config, palette and wallpaper (see settings_render.py). Writes
<out>/<prefix>-<language>.png (prefix: kit). `--sheet KitGalleryBold` draws the
big controls (Tile, LevelSlider, Segmented, Sparkline) instead (prefix: kit-bold).
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
    ap.add_argument("--prefix", default="", help="file name prefix (<prefix>-<language>.png)")
    ap.add_argument("--sheet", default="KitGallery", choices=["KitGallery", "KitGalleryBold"])
    args = ap.parse_args()
    prefix = args.prefix or ("kit" if args.sheet == "KitGallery" else "kit-bold")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    for lang in args.languages:
        theme = {"language": lang, "lightMode": args.mode == "light"}
        env = KitEnv(f"kit-render-{lang}", gallery=True, palette=palette(args.mode, state), user_config=True,
                     overrides={"theme": theme}, wallpaper=state)
        win = env.load(f"import qs.kitgallery\n{args.sheet} {{}}")
        win.setProperty("wallpaper", url)
        win.setProperty("art", url)
        win.setProperty("language", lang)
        QTest.qWait(900)
        path = out / f"{prefix}-{lang}.png"
        win.grabWindow().save(str(path))
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
