#!/usr/bin/env python3
"""Record the home <-> page shared-element transition in slow motion
(offscreen, private Xvfb), to inspect it frame by frame.

    tools/render/settings_morph_frames.py [--out DIR] [--language ink]
                                          [--slow 10] [--wallpaper PATH] [SCENE ...]

Scenes:
  tile-open    a click on the Look tile: its snapshot grows into the page
  tile-back    from a page reached without its tile (a deep link to Bar,
               then Ctrl+Tab to the next tab): back collapses into the
               Screen tile
  search-open  a query, Enter: the result row grows into the page (the row
               flashes), the row is revealed once the page stands; back
               lands on the destination's tile

The Motion tokens are stretched `--slow` times (assigned on the Motion
singleton for this run only), so a 280 ms morph spans tens of grabs.
Writes <out>/morph-<scene>.png (a contact sheet, frames numbered) and keeps
the frames in <out>/frames-<scene>/.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import settings_render as sr  # noqa: E402  (sets up the headless display)
from settings_motion import Recorder, centre  # noqa: E402

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

SCENES = ("tile-open", "tile-back", "search-open")


def sheet(folder: Path, out: Path) -> None:
    n = len(list(folder.glob("*.png")))
    cols = 8
    rows = (n + cols - 1) // cols
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-start_number", "0", "-i", str(folder / "%04d.png"),
                    "-vf", f"scale=iw/4:-1,drawtext=text='%{{n}}':x=6:y=6:fontsize=18:fontcolor=yellow:box=1:boxcolor=black,"
                    f"tile={cols}x{rows}:padding=4:color=white", "-frames:v", "1", str(out)], check=True)
    print(out)


def scene(name: str, args, out: Path) -> None:
    wp = str(Path(args.wallpaper).resolve())
    state = {"dir": str(Path(wp).parent), "scanDirs": [str(Path(wp).parent)], "paths": [wp],
             "current": wp, "thumbs": {}, "presets": []}
    env = SettingsEnv(f"morph-{name}", palette=sr.DEFAULT_PALETTE, user_config=True,
                      overrides={"theme": {"language": args.language, "lightMode": args.light}}, wallpaper=state)
    win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.theme
Window {
    width: 1180; height: 780; visible: true; color: "black"
    function slowmo(n) {
        for (const k of ["morph", "exit", "glide", "micro"])
            Motion[k].duration = Motion[k].duration * n;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
    shell = env.h.find(win, "shell")
    root = win.contentItem()
    rest = QPoint(1176, 776)
    QTest.mouseMove(win, rest)
    if name == "tile-back":
        env.h.eval(shell, 'select("bar")')
        QTest.qWait(1200)
        env.h.eval(shell, "step(1)")
    else:
        env.h.eval(shell, "goHome()")
    QTest.qWait(1500)
    slow = args.slow
    env.h.eval(win, f"slowmo({slow})")
    rec = Recorder(win, out / f"frames-{name}")
    span = 280 * slow + 600
    if name == "tile-open":
        tile = sr.find_visual(root, "homeTile:look")
        QTest.mouseMove(win, centre(tile))
        rec.grab(300)
        QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(tile))
        rec.grab(span)
        env.h.eval(shell, "goHome()")
        rec.grab(160 * slow + 600)
    elif name == "tile-back":
        rec.grab(200)
        env.h.eval(shell, "goHome()")
        rec.grab(160 * slow + 800)
    else:
        env.h.eval(shell, "openSearch()")
        QTest.qWait(200)
        env.h.find(win, "settingsSearch").setProperty("text", "clock")
        QTest.qWait(400)
        rec.grab(300)
        QTest.keyClick(win, Qt.Key_Return)
        rec.grab(span + 1200)
        env.h.eval(shell, "goHome()")
        rec.grab(160 * slow + 800)
    sheet(rec.folder, out / f"morph-{name}.png")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenes", nargs="*", default=list(SCENES))
    ap.add_argument("--out", default=str(sr.REPO / ".cache" / "render" / "morph"))
    ap.add_argument("--language", default="ink")
    ap.add_argument("--light", action="store_true")
    ap.add_argument("--slow", type=int, default=10, help="stretch the motion tokens this many times")
    ap.add_argument("--wallpaper", default=str(sr.REPO / "assets" / "wallpapers_example" / "wallpaper-01.png"))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for name in args.scenes:
        if name not in SCENES:
            raise SystemExit(f"unknown scene {name!r} (one of {', '.join(SCENES)})")
        scene(name, args, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
