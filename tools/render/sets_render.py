#!/usr/bin/env python3
"""Render the built-in preset sets offscreen (private Xvfb, never the live
desktop): the composed set config over the defaults (not your config) and
the set's static palette (assets/colors/<Palette>/{dark,light}.json, light
when the composed theme.lightMode is true).

    tools/render/sets_render.py [--only NAME] [--out DIR] [--size 1920x1080]

Writes <out>/<set>-dashboard.png (the dashboard frame) and <out>/<set>-bar.png
(the strip of the set's first bar panel on its edge; the top strip, where the
notch lives, for a set without a visible bar).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import panels_render  # noqa: E402  (enters the private Xvfb first)
import dashboard_render  # noqa: E402
import presetsets  # noqa: E402
from settings_env import load_defaults  # noqa: E402
from settings_render import REPO, wallpaper_state  # noqa: E402

COLORS = REPO / "assets" / "colors"
STRIP = 96


def set_palette(composed: dict) -> dict:
    name = composed.get("wallpaper", {}).get("activeColorPreset", "")
    mode = "light" if composed.get("theme", {}).get("lightMode") else "dark"
    path = COLORS / name / f"{mode}.json"
    if not path.is_file():
        raise FileNotFoundError(f"palette {name!r}: no {path}")
    return json.loads(path.read_text())


def bar_edge(bar: dict) -> str:
    """Edge of the set's first visible bar panel ("top" for none/no-bar)."""
    panels = bar.get("panels") or []
    if not panels:
        return bar.get("position", "top")
    first = panels[0]
    return "top" if first.get("style") == "none" else first.get("edge", "top")


def render_set(name: str, out: Path, size: tuple[int, int], state: dict) -> None:
    composed = presetsets.compose(name)
    colors = set_palette(composed)
    known = load_defaults()
    overrides = {dom: obj for dom, obj in composed.items() if dom in known}
    slug = name.replace(" ", "-")
    dashboard_render.render(f"sets-{slug}-dash", out / f"{name}-dashboard.png", state, colors, overrides,
                            user_config=False)
    mode = "light" if composed.get("theme", {}).get("lightMode") else "dark"
    layout = {**overrides, "name": f"{name}-bar", "crop": {"edge": bar_edge(composed.get("bar", {})),
                                                           "size": STRIP}}
    panels_render.render(layout, mode, size, out, state, REPO, windows=False, colors=colors, user_config=False)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default="", help="only this set")
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "sets"))
    ap.add_argument("--size", default="1920x1080")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    size = tuple(int(x) for x in args.size.split("x"))
    state = wallpaper_state()
    names = [args.only] if args.only else presetsets.list_sets()
    for name in names:
        render_set(name, out, size, state)
    return 0


if __name__ == "__main__":
    code = main()
    sys.stdout.flush()
    os._exit(code)
