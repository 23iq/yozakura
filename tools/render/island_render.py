#!/usr/bin/env python3
"""Render the island (notch) offscreen (private Xvfb, never the live desktop).

    tools/render/island_render.py [--out DIR] [--mode dark|light]
                                  [--styles attached,island,pill] [--languages ink,glass,tiles]
                                  [--no-left] [STATE ...]

Uses tests/lib/island_env.py (real Notch, DefaultView, panels and notch
notifications; fixture player, timers, downloads, privacy, voice) with your
real config, palette and wallpaper (see settings_render.py). Every state is
rendered on the top edge per style x language, plus collapsed and media on
the left edge (island style). Writes <out>/island-<state>-<style>-<language>.png
and island-left-<state>-<language>.png.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# Many scenes: a longer watchdog than the tests' 120 s (tests/lib/headless.py)
os.environ.setdefault("YOZAKURA_TEST_TIMEOUT", "1800")
from settings_render import REPO, color_source, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

import bundled_fonts  # noqa: E402
from island_env import IslandEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

USER_CONFIG = Path.home() / ".config" / "yozakura" / "config"
LANGUAGES = ["ink", "glass", "tiles"]
STYLES = ["attached", "island", "pill"]
# name -> (JS on the window, panel to open through the controller)
STATES = {
    "collapsed": ("", ""),
    "media-row": ("Config.notch.mediaStyle = 'row'", "media"),
    "media-artwork": ("Config.notch.mediaStyle = 'artwork'", "media"),
    "transfers": ("", "transfers"),
    "timers": ("TimersService.stopwatchActive = true; TimersService.stopwatchMs = 83400", "timers"),
    "timerHub": ("TimersService.openHub('timer', '')", ""),
    "alarm": ("TimersService.timers = [{ id: '3', name: 'Tea', state: 'done', ringing: true, leftMs: 0, progress: 1 }]", ""),
    "privacy": ("", "privacy"),
    "voice": ("VoiceService.panelOpen = true", ""),
    "notif-card": ("Config.notifications.notchStyle = 'card'; win.notify(true)", ""),
    "notif-compact": ("Config.notifications.notchStyle = 'compact'; win.notify(true)", ""),
    "notif-card-hover": ("Config.notifications.notchStyle = 'card'; win.notify(true)", "hover"),
    "notif-compact-hover": ("Config.notifications.notchStyle = 'compact'; win.notify(true)", "hover"),
}
LEFT_STATES = ["collapsed", "media-row", "timers"]


def user_domain(name: str) -> dict:
    try:
        return json.loads((USER_CONFIG / f"{name}.json").read_text())
    except (OSError, ValueError):
        return {}


def render_all(env: IslandEnv, wall: str, states: list[str], name: str, out: Path) -> None:
    h = env.h
    for state in states:
        win = env.scene(wallpaper=wall)
        h.eval(win, "seed()")
        QTest.qWait(300)
        js, panel = STATES[state]
        if js:
            h.eval(win, js)
        if panel == "hover":
            QTest.qWait(200)
            h.eval(h.find(win, "islandNotifications"), "hovered = true")
        elif panel:
            h.eval(h.find(win, "panelController"), f"toggle('{panel}')")
        QTest.qWait(700)
        path = out / name.format(state=state)
        win.grabWindow().save(str(path))
        print(path, flush=True)
        win.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("states", nargs="*", default=list(STATES))
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "island"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--styles", default=",".join(STYLES))
    ap.add_argument("--languages", default=",".join(LANGUAGES))
    ap.add_argument("--no-left", action="store_true", help="skip the left-edge renders")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = color_source(state)
    art = state.get("thumbs", {}).get(state.get("current", ""), wall)
    bundled_fonts.register(REPO)
    for lang in args.languages.split(","):
        theme = {**user_domain("theme"), "language": lang, "lightMode": args.mode == "light"}
        for style in args.styles.split(","):
            env = IslandEnv(f"island-{style}-{lang}", art=("file://" + art) if art else "", theme=theme,
                            palette=palette(args.mode, state),
                            notch={**user_domain("notch"), "style": style, "position": "top", "expandOn": "click",
                                   "disableHoverExpansion": False})
            render_all(env, wall, args.states, f"island-{{state}}-{style}-{lang}.png", out)
        if not args.no_left:
            env = IslandEnv(f"island-left-{lang}", art=("file://" + art) if art else "", theme=theme,
                            palette=palette(args.mode, state),
                            notch={**user_domain("notch"), "style": "island", "position": "left", "expandOn": "click",
                                   "disableHoverExpansion": False})
            render_all(env, wall, [s for s in LEFT_STATES if s in args.states], f"island-left-{{state}}-{lang}.png", out)
    return 0


if __name__ == "__main__":
    code = main()
    sys.stdout.flush()
    # Skip PySide's engine teardown (can crash after several scenes)
    os._exit(code)
