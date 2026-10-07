#!/usr/bin/env python3
"""Render live activity chips in the bar offscreen (private Xvfb, never the
live desktop).

    tools/render/activitychip_render.py [--out DIR] [--mode dark|light]
                                        [--languages ink,glass,tiles] [--edges top,left]

A dock-like bar (start: systemStats, launcher, workspaces; end: controls,
clock) sharing its edge with a pill notch, ActivityService.presentation
"bar" (notch.activitiesIn auto). Per edge x language: one activity, three
activities, and three with the pointer resting on the downloads chip (its
TransfersPanel popup). Uses tests/lib/island_env.py (fixture downloads,
timer, privacy) with your real palette and wallpaper. Writes
<out>/chips-<edge>-<n|hover>-<language>.png.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("YOZAKURA_TEST_TIMEOUT", "1800")
from settings_render import REPO, color_source, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

import bundled_fonts  # noqa: E402
from island_env import IslandEnv  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QPoint, QRect  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

W, H = 1600, 900
ONE = "ActivityService.activities.filter(a => a.id === 'downloads')"
THREE = "ActivityService.activities.filter(a => a.id !== 'privacy:screen')"


def bar(edge: str) -> dict:
    return {"frameEnabled": False, "containBar": False, "pinnedOnStartup": True, "panels": [{
        "id": "main", "edge": edge, "style": "dock-like", "align": "center",
        "groups": {"start": ["systemStats", "launcher", "workspaces"], "end": ["controls", "clock"]}}]}


def find(item, name: str):
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(child, name)
        if hit is not None:
            return hit
    return None


def shot(win, edge: str, path: Path, popup: bool) -> None:
    image = win.grabWindow()
    if edge == "top":
        rect = QRect(200, 0, W - 400, 560 if popup else 90)
    else:
        rect = QRect(0, 0, 620 if popup else 90, H)
    image.copy(rect).save(str(path))
    print(path, flush=True)


def render(edge: str, lang: str, mode: str, state: dict, out: Path) -> None:
    env = IslandEnv(f"chips-{edge}-{lang}", bar=bar(edge), theme={"language": lang, "lightMode": mode == "light"},
                    notch={"style": "pill", "position": edge, "expandOn": "hover", "mediaStyle": "artwork"},
                    palette=palette(mode, state))
    win = PanelsEnv.scene(env, W, H, wallpaper=color_source(state), windows=False)
    h = env.h
    # A context that sees the services (the scene's root does not import them)
    svc = h.load("import QtQuick\nimport qs.modules.theme\nimport qs.modules.services.activities\nQtObject {}")
    QTest.qWait(600)
    h.eval(svc, "ActivityService.presentation = 'bar'")
    h.eval(svc, f"ActivityService.transfers = {TRANSFERS}")
    QTest.qWait(300)
    for name, expr in (("1", ONE), ("3", THREE)):
        h.eval(svc, f"ActivityService.activities = {ALL}")
        h.eval(svc, f"ActivityService.activities = {expr}")
        QTest.qWait(900)
        shot(win, edge, out / f"chips-{edge}-{name}-{lang}.png", False)
    chip = find(win.contentItem(), "activityChip:downloads")
    if chip is None:
        print("warning: no downloads chip", file=sys.stderr)
        return
    c = chip.mapToItem(None, chip.width() / 2, chip.height() / 2)
    QTest.mouseMove(win, QPoint(round(c.x()), round(c.y())))
    QTest.qWait(30)
    QTest.mouseMove(win, QPoint(round(c.x()) + 1, round(c.y())))
    QTest.qWait(1000)
    shot(win, edge, out / f"chips-{edge}-hover-{lang}.png", True)
    win.close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "activity-chip"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--languages", default="ink,glass,tiles")
    ap.add_argument("--edges", default="top,left")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    bundled_fonts.register(REPO)
    state = wallpaper_state()
    for edge in args.edges.split(","):
        for lang in args.languages.split(","):
            render(edge, lang, args.mode, state, out)
    # Skip the interpreter's Qt teardown (it may crash after many scenes)
    sys.stdout.flush()
    os._exit(0)


from island_env import ACTIVITIES as ALL, TRANSFERS  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
