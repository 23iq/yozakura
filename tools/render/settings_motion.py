#!/usr/bin/env python3
"""Record settings window motion offscreen as animated WebP / GIF (private
Xvfb, never the live desktop).

    tools/render/settings_motion.py [--out DIR] [--language ink] [--size 1180x780]
                                    [--wallpaper PATH] [SCENE ...]

Scenes:
  tile-hover   the pointer moves onto the Screen tile: it lifts, the
               wallpaper swells and follows the pointer, windows slide in
  tile-open    a click on the Look tile: the tile grows into its page
  gate-toggle  on Screen > Bar, the frame switch goes on and off: its rows
               appear and go, the cards under them land without crossing
  resize       the window narrows to its minimum and widens back: home's
               and the page's columns switch once each way
  scroll       on Screen > Bar, the page scrolls down and back: the stage
               recedes, the header and tabs stay
  edge-click   on Screen > Bar, the left edge of the miniature is
               hovered (a ghost bar, "Move here") and clicked: the bar moves
  windows-gap  on Windows, the gap grip between the windows is dragged: the
               gaps widen live, the readout follows, one undo step
  power-idle   on Power, the Sleep knob of the idle timeline is dragged
               sooner and back (the device fixtures give the battery stage)

Frames are grabbed as fast as the window renders, each stamped with the
time it was taken, and joined by ffmpeg with those durations, so the result
plays at the real speed. Writes <out>/settings-<scene>.webp and .gif (and
keeps the frames in <out>/frames-<scene>/).
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import settings_render as sr  # noqa: E402  (sets up the headless display)

from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

SCENES = ("tile-hover", "tile-open", "gate-toggle", "resize", "scroll", "edge-click", "windows-gap", "power-idle")
# the page a scene starts on ("" = home)
PAGES = {"edge-click": "bar", "windows-gap": "windows", "power-idle": "power", "gate-toggle": "bar", "scroll": "bar"}


class Recorder:
    def __init__(self, win, folder: Path):
        self.win = win
        self.folder = folder
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True)
        self.frames: list[tuple[Path, float]] = []

    def grab(self, ms: int) -> None:
        """Grab frames for `ms` milliseconds."""
        end = time.monotonic() + ms / 1000
        while time.monotonic() < end:
            QTest.qWait(1)
            path = self.folder / f"{len(self.frames):04d}.png"
            self.win.grabWindow().save(str(path))
            self.frames.append((path, time.monotonic()))

    def write(self, out: Path, name: str, scale: int) -> None:
        listing = self.folder / "frames.txt"
        lines = []
        for i, (path, t) in enumerate(self.frames):
            nxt = self.frames[i + 1][1] if i + 1 < len(self.frames) else t + 0.6
            lines.append(f"file '{path.name}'\nduration {max(0.01, nxt - t):.3f}")
        lines.append(f"file '{self.frames[-1][0].name}'")
        listing.write_text("\n".join(lines) + "\n")
        base = ["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing)]
        vf = f"scale={scale}:-1:flags=lanczos"
        subprocess.run(base + ["-vf", vf, "-c:v", "libwebp_anim", "-lossless", "0", "-q:v", "80", "-loop", "0",
                               str(out / f"settings-{name}.webp")], check=True)
        subprocess.run(base + ["-vf", f"{vf},split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a",
                               "-loop", "0", str(out / f"settings-{name}.gif")], check=True)
        print(out / f"settings-{name}.webp")


def centre(item) -> QPoint:
    p = item.mapToScene(item.boundingRect().center())
    return QPoint(int(p.x()), int(p.y()))


def glide(win, a: QPoint, b: QPoint, rec: Recorder, steps: int = 8) -> None:
    for i in range(1, steps + 1):
        QTest.mouseMove(win, QPoint(a.x() + (b.x() - a.x()) * i // steps, a.y() + (b.y() - a.y()) * i // steps))
        rec.grab(25)


def scene(name: str, args, out: Path) -> None:
    w, h = (int(x) for x in args.size.split("x"))
    state = sr.wallpaper_state()
    if args.wallpaper:
        wp = str(Path(args.wallpaper).resolve())
        state = {"dir": str(Path(wp).parent), "scanDirs": [str(Path(wp).parent)], "paths": [wp],
                 "current": wp, "thumbs": {}, "presets": []}
    colors = sr.DEFAULT_PALETTE if args.palette == "default" else sr.palette("dark", state, from_wallpaper=bool(args.wallpaper))
    env = SettingsEnv(f"motion-{name}", palette=colors,
                      user_config=True,
                      overrides={"theme": {"language": args.language, "lightMode": False}}, wallpaper=state,
                      devices=name in PAGES)
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
    shell = env.h.find(win, "shell")
    root = win.contentItem()
    QTest.mouseMove(win, QPoint(w - 4, h - 4))
    if name in PAGES:
        env.h.eval(shell, f'select("{PAGES[name]}")')
    else:
        env.h.eval(shell, "goHome()")
    QTest.qWait(1200)
    rec = Recorder(win, out / f"frames-{name}")
    rest = QPoint(w - 4, h - 4)
    if name == "tile-hover":
        tile = sr.find_visual(root, "homeTile:layout")
        rec.grab(200)
        target = centre(tile)
        glide(win, rest, QPoint(target.x() - tile.width() // 4, target.y()), rec)
        rec.grab(500)
        glide(win, QPoint(target.x() - tile.width() // 4, target.y()), QPoint(target.x() + tile.width() // 4, target.y() + tile.height() // 5), rec, 12)
        rec.grab(500)
        glide(win, QPoint(target.x() + tile.width() // 4, target.y() + tile.height() // 5), rest, rec)
        rec.grab(500)
    elif name == "tile-open":
        tile = sr.find_visual(root, "homeTile:look")
        rec.grab(150)
        glide(win, rest, centre(tile), rec)
        rec.grab(250)
        QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, centre(tile))
        rec.grab(900)
        env.h.eval(shell, "goHome()")
        rec.grab(700)
    elif name == "gate-toggle":
        rec.grab(300)
        env.h.eval(shell, "SettingsStore.set('bar.frameEnabled', true)")
        rec.grab(900)
        env.h.eval(shell, "SettingsStore.set('bar.frameEnabled', false)")
        rec.grab(900)
    elif name == "resize":
        rec.grab(300)
        for wd in list(range(w, 639, -30)) + list(range(640, w + 1, 30)):
            win.resize(wd, h)
            rec.grab(40)
        env.h.eval(shell, 'select("timers")')
        rec.grab(600)
        for wd in list(range(w, 639, -30)) + list(range(640, w + 1, 30)):
            win.resize(wd, h)
            rec.grab(40)
        rec.grab(300)
    elif name == "scroll":
        page = env.h.eval(shell, 'page.item')
        rec.grab(300)
        for y in list(range(0, 901, 45)) + list(range(900, -1, -45)):
            env.h.eval(page, f"contentY = Math.min({y}, contentHeight - height)")
            rec.grab(30)
        rec.grab(300)
    elif name == "edge-click":
        mini = sr.find_visual(root, "barStageScreen")
        left = mini.mapToScene(mini.boundingRect().topLeft())
        spot = QPoint(int(left.x()) + 6, int(left.y() + mini.height() / 2))
        rec.grab(200)
        glide(win, rest, spot, rec, 10)
        rec.grab(600)
        QTest.mouseClick(win, Qt.LeftButton, Qt.NoModifier, spot)
        rec.grab(900)
        glide(win, spot, rest, rec, 6)
        rec.grab(400)
        env.h.eval(shell, "SettingsStore.undo()")
        rec.grab(800)
    elif name in ("windows-gap", "power-idle"):
        knob = sr.find_visual(root, "windowsGapGripArea" if name == "windows-gap" else "idleKnob:sleep")
        a = centre(knob)
        far = QPoint(a.x() + (36 if name == "windows-gap" else -120), a.y())
        rec.grab(200)
        glide(win, rest, a, rec, 8)
        rec.grab(300)
        QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, a)
        rec.grab(120)
        glide(win, a, far, rec, 14)
        rec.grab(300)
        glide(win, far, a, rec, 10)
        QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, a)
        rec.grab(500)
        glide(win, a, rest, rec, 6)
        rec.grab(300)
    rec.write(out, name, args.scale)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenes", nargs="*", default=list(SCENES))
    ap.add_argument("--out", default=str(sr.REPO / ".cache" / "render" / "motion"))
    ap.add_argument("--language", default="ink")
    ap.add_argument("--size", default="1180x780")
    ap.add_argument("--scale", type=int, default=880, help="output width in px")
    ap.add_argument("--wallpaper", default="", help="image used as the wallpaper")
    ap.add_argument("--palette", default="wallpaper", choices=["wallpaper", "default"],
                    help="colours from the wallpaper (default) or the fixed rose palette")
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
