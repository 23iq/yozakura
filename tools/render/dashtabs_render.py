#!/usr/bin/env python3
"""Render the dashboard's tool tabs offscreen (private Xvfb, never the live desktop).

    tools/render/dashtabs_render.py [--out DIR] [--mode dark|light]
                                    [--views metrics,wifi,...] [LANGUAGE ...]

The metrics tab, the device panels of controls/ (Wi-Fi, Bluetooth, the
audio mixer, EasyEffects; also the settings Connect pages) and the
wallpapers tab, each on the popup Surface over your wallpaper with your
config and palette (see settings_render.py) and sample data: CPU / RAM / two
GPUs / disks with a history, networks, devices, app streams, presets and
your wallpaper folder. The clipboard tab renders with launcher_render.py
(tab-clipboard*). Writes <out>/dashtab-<view>-<language>[-light].png.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from dashtabs_env import DashTabsEnv  # noqa: E402
from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# view -> (QML element, width, height)
VIEWS = {
    "metrics": ("MetricsTab {}", 860, 430),
    "wifi": ("WifiPanel {}", 520, 420),
    "bluetooth": ("BluetoothPanel {}", 520, 360),
    "mixer": ("AudioMixerPanel {}", 520, 460),
    "mixer-input": ("AudioMixerPanel { showOutput: false }", 520, 360),
    "effects": ("EasyEffectsPanel {}", 520, 340),
    "wallpapers": ("WallpapersTab {}", 860, 470),
}


def sample_walls(state: dict) -> dict:
    """A full grid even with a small folder: sample entries (images, a GIF,
    videos) drawn with the current wallpaper's thumbnail."""
    paths = list(state.get("paths", []))
    if len(paths) >= 12:
        return state
    cur = state.get("current", "") or (paths[0] if paths else "")
    thumb = state.get("thumbs", {}).get(cur, cur)
    exts = ["jpg", "png", "gif", "mp4", "jpg", "webp"]
    extra = [f"/walls/sample-{i:02d}.{exts[i % len(exts)]}" for i in range(14 - len(paths))]
    return {**state, "paths": paths + extra, "thumbs": {**state.get("thumbs", {}), **{p: thumb for p in extra}}}


def render(view: str, path: Path, state: dict, colors: dict, overrides: dict) -> Path:
    element, w, h = VIEWS[view]
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    env = DashTabsEnv(f"dashtabs-{view}", art=url, palette=colors, user_config=True, overrides=overrides,
                      wallpaper=state)
    win = env.scene(element, w, h)
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
    ap.add_argument("--views", default=",".join(VIEWS))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = sample_walls(wallpaper_state())
    suffix = "-light" if args.mode == "light" else ""
    for view in args.views.split(","):
        if view not in VIEWS:
            ap.error(f"unknown view {view!r} (known: {', '.join(VIEWS)})")
        for lang in args.languages:
            overrides = {"theme": {"language": lang, "lightMode": args.mode == "light"}}
            render(view, out / f"dashtab-{view}-{lang}{suffix}.png", state, palette(args.mode, state), overrides)
    return 0


if __name__ == "__main__":
    sys.exit(main())
