#!/usr/bin/env python3
"""Frame sequences of the stage dashboard's motion (private Xvfb, never the
live desktop), as contact sheets you can read.

    tools/render/dashboard_motion_render.py [--out DIR] [--language glass]
                                            [--scenarios open,tab,...]

Each scenario loads the stage (as tools/render/dashboard_render.py does),
triggers one change and grabs the window at fixed times after it (the
label shows the real elapsed ms). Scenarios: open (the section stagger),
tab (Home -> Metrics cross-slide), detail (Wi-Fi panel over the right
column), dismiss (a notification leaves, neighbours close the gap), clear
(clear-all sweep), arrive (a new notification slides in), track (track
change), stop (playback stops: player -> idle), toggle (a tile turns off).
Writes <out>/motion-<scenario>.png (and the frames under <out>/frames/).
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dashboard_render import SAMPLE_TIMERS, sample_events  # noqa: E402
from dashboard_render import SCENE as STILL  # noqa: E402
from settings_render import REPO, palette, wallpaper_state  # noqa: E402

from dashboard_env import DashboardEnv  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# The still scene plus the services the scenarios poke.
SCENE = STILL.replace("import QtQuick.Window", "import QtQuick.Window\nimport qs.modules.globals\nimport qs.modules.services")
FRAMES = [0, 30, 60, 100, 150, 220, 400]
NEW = '{"id": 99, "appName": "Calendar", "summary": "Standup in 5 min", "body": "Room 2", "time": 0}'
# scenario -> (object, expression, crop box as window fractions or None)
SCENARIOS = {
    "open": ("stage", "playReveal()", None),
    "tab": ("dashboard", "GlobalStates.dashboardCurrentTab = 2", None),
    "detail": ("stage", "openDetail('wifi')", (0.5, 0.1, 1.0, 0.9)),
    "dismiss": ("dashboard", "Notifications.list = Notifications.list.slice(1)", (0.5, 0.55, 1.0, 0.9)),
    "clear": ("dashboard", "Notifications.list = []", (0.5, 0.55, 1.0, 0.9)),
    "arrive": ("dashboard", "Notifications.list = [" + NEW + "].concat(Notifications.list)", (0.5, 0.55, 1.0, 0.9)),
    "track": ("dashboard", "MprisController.activePlayer.trackTitle = 'Wait'", (0.0, 0.1, 0.55, 0.5)),
    "stop": ("dashboard", "MprisController.activePlayer = null", (0.0, 0.1, 0.55, 0.5)),
    "toggle": ("wifiToggle", "clicked()", (0.0, 0.45, 0.55, 0.75)),
}


def run(name: str, out: Path, lang: str, state: dict, colors: dict) -> Path:
    obj, expr, crop = SCENARIOS[name]
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    url = ("file://" + wall) if wall else ""
    overrides = {"theme": {"language": lang}, "layout": {"dashboard": {"home": "stage"}}}
    env = DashboardEnv(f"dashboard-motion-{name}", art=url, palette=colors, user_config=True, overrides=overrides,
                       wallpaper=state, timers=SAMPLE_TIMERS)
    win = env.load(SCENE)
    win.setProperty("wallpaper", url)
    dash = env.h.find(win, "dashboard")
    cal = env.h.find(win, "calendarEvents")
    env.h.eval(cal, "available = true")
    env.h.eval(cal, f"this.events = {sample_events()}")
    QTest.qWait(1200)
    target = {"dashboard": dash, "stage": env.h.eval(dash, "widgetsItem")}.get(obj) or env.h.find(win, obj)
    frames = []
    t0 = time.monotonic()
    env.h.eval(target, expr)
    for at in FRAMES:
        wait = at - (time.monotonic() - t0) * 1000
        if wait > 0:
            QTest.qWait(int(wait))
        img = win.grabWindow()
        frames.append((int((time.monotonic() - t0) * 1000), img))
    win.close()
    fdir = out / "frames"
    fdir.mkdir(parents=True, exist_ok=True)
    tiles = []
    for ms, img in frames:
        p = fdir / f"{name}-{ms:04d}.png"
        img.save(str(p))
        im = Image.open(p).convert("RGB")
        if crop:
            w, h = im.size
            im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
        tiles.append((ms, im))
    scale = min(1.0, 1500 / (4 * tiles[0][1].width))
    tiles = [(ms, im.resize((int(im.width * scale), int(im.height * scale)))) for ms, im in tiles]
    tw, th = tiles[0][1].size
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, (th + 16) * rows), "white")
    d = ImageDraw.Draw(sheet)
    for i, (ms, im) in enumerate(tiles):
        x, y = (i % cols) * tw, (i // cols) * (th + 16)
        sheet.paste(im, (x, y + 16))
        d.text((x + 4, y + 2), f"{name} +{ms} ms", fill="black")
    path = out / f"motion-{name}.png"
    sheet.save(path)
    print(path, flush=True)
    return path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "motion"))
    ap.add_argument("--language", default="glass")
    ap.add_argument("--scenarios", default=",".join(SCENARIOS))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for name in args.scenarios.split(","):
        run(name, out, args.language, state, palette("dark", state))
    return 0


if __name__ == "__main__":
    sys.exit(main())
