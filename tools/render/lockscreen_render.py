#!/usr/bin/env python3
"""Render every lock screen style offscreen (private Xvfb, never the live
session, never a real lock).

    tools/render/lockscreen_render.py [--out DIR] [--styles glass,paper,...]
                                      [--modes dark,light] [--tone theme]
                                      [--wallpaper PATH] [--size 1920x1080]
                                      [--no-media] [--position bottom|top]
                                      [--languages ink,glass,tiles] [--seed '#4f8a5b']

Builds tests/lib/lockscreen_env.py (real modules/lockscreen files, stubbed
services) with your palette: dark = ~/.cache/<app>/colors.json, light =
matugen from the wallpaper. Wallpaper: --wallpaper, else the current one
(videos: the frame the lock screen caches), else an example wallpaper. A fake
player fills the media card unless --no-media.
--languages renders once per theme.language (the kit's look), --seed takes
the palette from that colour (matugen) instead (e.g. a green one).
Writes <out>/<style>-<mode>[-<tone>][-<language>][-<seed>].png (tone only
when not "theme", language only with --languages, seed only with --seed).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (wraps the Window as QQuickWindow)
from PySide6.QtTest import QTest  # noqa: E402
import bundled_fonts  # noqa: E402
from lockscreen_env import LockscreenEnv  # noqa: E402
from settings_env import APP_ID, DEFAULT_PALETTE  # noqa: E402

CACHE = Path.home() / ".cache" / APP_ID
VIDEO = (".mp4", ".webm", ".mkv", ".mov", ".gif", ".avi", ".m4v")


def camel(role: str) -> str:
    if role.startswith("on_"):
        role = "over_" + role[3:]
    head, *rest = role.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def wallpaper(arg: str) -> str:
    if arg:
        return arg
    try:
        cur = json.loads((CACHE / "wallpapers.json").read_text()).get("currentWall", "")
    except (OSError, ValueError):
        cur = ""
    if cur and Path(cur).suffix.lower() in VIDEO:
        frame = CACHE / "lockscreen" / (Path(cur).name + ".jpg")
        cur = str(frame) if frame.exists() else ""
    if cur and Path(cur).exists():
        return cur
    return str(sorted((REPO / "assets" / "wallpapers_example").glob("*.png"))[0])


def palette(mode: str, wall: str, seed: str = "") -> dict:
    cmd = ["matugen", "color", "hex", seed] if seed else ["matugen", "image", wall]
    if mode == "dark" and not seed:
        try:
            return {**DEFAULT_PALETTE, **json.loads((CACHE / "colors.json").read_text())}
        except (OSError, ValueError):
            pass
    r = subprocess.run(cmd + ["--dry-run", "-q", "-j", "hex", "-m", mode,
                        "--source-color-index", "0"], capture_output=True, text=True)
    if r.returncode != 0:
        return DEFAULT_PALETTE
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v[mode]["color"] for k, v in json.loads(r.stdout)["colors"].items() if mode in v})
    return out


def styles() -> list[str]:
    import re
    text = (REPO / "modules/lockscreen/styles/LockStyleRegistry.js").read_text()
    return re.findall(r'^\s*id: "(\w+)"', text, re.M)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "lockscreen"))
    ap.add_argument("--styles", default="")
    ap.add_argument("--modes", default="dark,light")
    ap.add_argument("--tone", default="theme", help="lockscreen.tone (style|theme|light|dark)")
    ap.add_argument("--wallpaper", default="")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--position", default="bottom")
    ap.add_argument("--no-media", action="store_true")
    ap.add_argument("--languages", default="", help="theme.language values, one render each (ink,glass,tiles)")
    ap.add_argument("--seed", default="", help="palette seed colour (matugen), e.g. '#4f8a5b'")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    wall = wallpaper(args.wallpaper)
    wanted = [s for s in args.styles.split(",") if s] or styles()
    langs = args.languages.split(",") if args.languages else [""]
    for mode, lang in [(m, lg) for m in args.modes.split(",") for lg in langs]:
        bundled_fonts.register()
        theme = {"lightMode": mode == "light", **({"language": lang} if lang else {})}
        env = LockscreenEnv(f"lock-render-{mode}", palette=palette(mode, wall, args.seed), overrides={
            "theme": theme,
            "lockscreen": {"tone": args.tone, "position": args.position}})
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.lockscreen
import qs.modules.services
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    function use(s) {{ Config.lockscreen.style = s }}
    LockView {{
        objectName: "lv"; anchors.fill: parent; startAnim: true
        username: "lazy"; hostname: "sakura"
        wallpaperSource: "file://{wall}"
    }}
}}""")
        lv = env.h.find(win, "lv")
        if not args.no_media:
            env.h.eval(lv, "MprisController.activePlayer = " + env.player())
        for style in wanted:
            env.h.eval(win, f'use("{style}")')
            QTest.qWait(300)
            win.requestActivate()
            env.h.eval(lv, "focusPassword()")
            QTest.qWait(600)
            suffix = ("" if args.tone == "theme" else f"-{args.tone}") + (f"-{lang}" if lang else "")
            suffix += "-" + args.seed.lstrip("#") if args.seed else ""
            path = out / f"{style}-{mode}{suffix}.png"
            win.grabWindow().save(str(path))
            print(path)
        if env.errors:
            print("QML errors:\n  " + "\n  ".join(env.errors), file=sys.stderr)
    env.h.exit(0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
