#!/usr/bin/env python3
"""Render the desktop with widgets offscreen (private Xvfb, never the live desktop).

    tools/render/desktop_widgets_render.py [--out DIR] [--mode dark|light|both]
                                           [--size 2560x1440] [--wallpaper PATH]
                                           [--no-depth] [--settings]

Draws the wallpaper (a video shows the frame its depth mask was made from),
the real depth clock (with the subject cutout when the depth venv is set up:
scripts/depth_mask.py, cached results are reused) and the real desktop
widgets canvas with a sample layout of every widget type and demo data, in
normal and edit desktop mode. Uses your config, palette (light mode via
matugen) and current wallpaper, like tools/render/settings_render.py.
Writes <out>/desktop-{normal,edit}-<mode>.png; --settings also renders the
Desktop & Clock settings page (<out>/settings-desktop[-sN]-<mode>.png).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import QUICKSHELL, SettingsEnv  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

DATA = Path.home() / ".local" / "share" / "yozakura"
CACHE = Path.home() / ".cache" / "yozakura"
VIDEO = (".mp4", ".webm", ".mkv", ".mov", ".gif", ".avi")

# Sample layout (fractions of the screen), one of each type.
LAYOUT = [
    {"id": "media", "type": "media", "x": 0.03, "y": 0.8, "w": 0.2, "h": 0.12, "options": {}},
    {"id": "calendar", "type": "calendar", "x": 0.8, "y": 0.08, "w": 0.17, "h": 0.3, "options": {}},
    {"id": "weather", "type": "weather", "x": 0.8, "y": 0.41, "w": 0.17, "h": 0.15, "options": {}},
    {"id": "system", "type": "system", "x": 0.8, "y": 0.59, "w": 0.17, "h": 0.18, "options": {}},
    {"id": "note", "type": "note", "x": 0.63, "y": 0.08, "w": 0.14, "h": 0.2,
     "options": {"text": "夜桜 — tonight\n• finish the desktop widgets\n• water the bonsai"}},
]

HISTORY = [0.22, 0.25, 0.31, 0.28, 0.35, 0.42, 0.38, 0.33, 0.29, 0.36, 0.44, 0.51, 0.47, 0.4, 0.37, 0.33, 0.3,
           0.34, 0.39, 0.45, 0.41, 0.36, 0.32, 0.28, 0.3, 0.35, 0.33, 0.29, 0.27, 0.31]


def depth_result(path: str, w: int, h: int) -> dict | None:
    py = DATA / "venv-depth" / "bin" / "python"
    if not py.exists():
        return None
    r = subprocess.run([str(py), str(REPO / "scripts" / "depth_mask.py"), path, "--cache-dir", str(CACHE / "depth"),
                        "--models-dir", str(DATA / "depth-models"), "--screen", f"{w}x{h}"],
                       capture_output=True, text=True, timeout=600)
    try:
        res = json.loads(r.stdout.strip().splitlines()[-1])
    except (IndexError, ValueError):
        return None
    return res if res.get("ok") else None


def demo_services(depth: dict | None, art: str) -> dict:
    hist = json.dumps(HISTORY)
    return {
        "DepthMaskService": "pragma Singleton\nQtObject { property bool available: true; property string matteJob: ''; "
                            f"property real matteProgress: 0; property var data: ({json.dumps(depth)}); "
                            "function result(p, w, h) { return data } function request(p, w, h) {} }",
        "MprisController": "pragma Singleton\nQtObject { property bool isPlaying: true; property bool canTogglePlaying: true; "
                           "property bool canGoPrevious: true; property bool canGoNext: true; "
                           f"property var activePlayer: ({{ trackTitle: 'Yoru ni Kakeru', trackArtist: 'YOASOBI', "
                           f"trackArtUrl: {json.dumps(art)}, isPlaying: true }}); "
                           "function togglePlaying() {} function previous() {} function next() {} }",
        "CavaService": "pragma Singleton\nQtObject { property bool available: true; function setConsumer(k, a) {} "
                       "function levels(n) { var o = []; for (var i = 0; i < n; i++) "
                       "o.push(0.25 + 0.6 * Math.abs(Math.sin(i * 0.55) * Math.cos(i * 0.21))); return o } }",
        "SystemResources": "pragma Singleton\nQtObject { property real cpuUsage: 34; property real ramUsage: 52; "
                           f"property int gpuTemp: 61; property var cpuHistory: {hist}; "
                           f"property var ramHistory: {json.dumps([0.48 + (v - 0.3) * 0.15 for v in HISTORY])}; "
                           f"property var gpuTempHistories: [{json.dumps([55 + v * 20 for v in HISTORY])}]; "
                           "function setConsumer(k, a) {} }",
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="2560x1440")
    ap.add_argument("--wallpaper", default="")
    ap.add_argument("--no-depth", action="store_true")
    ap.add_argument("--settings", action="store_true", help="also render the Desktop & Clock settings page")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = args.wallpaper or state.get("current", "")
    depth = None if args.no_depth or not wall else depth_result(wall, w, h)
    backdrop = wall
    if wall.lower().endswith(VIDEO):
        frame = CACHE / "depth" / f"{depth['key']}.frame.jpg" if depth else None
        backdrop = str(frame) if frame and frame.exists() else state.get("thumbs", {}).get(wall, "")
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        env = SettingsEnv(f"desktop-render-{mode}", palette=palette(mode, state), user_config=True,
                          overrides={"theme": {"lightMode": mode == "light"},
                                     "desktop": {"widgets": LAYOUT, "widgetsEnabled": True}},
                          wallpaper=state)
        env.h.module("qs.modules.services", demo_services(depth, "file://" + backdrop if backdrop else ""))
        env.h.module("Quickshell", {**QUICKSHELL, "Quickshell": QUICKSHELL["Quickshell"].replace(
            "property var screens: []", f'property var screens: [{{ name: "render", width: {w}, height: {h} }}]')})
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.desktop
import qs.modules.desktop.widgets
Window {{
    id: win
    width: {w}; height: {h}; visible: true; color: "black"
    Image {{
        anchors.fill: parent
        source: {json.dumps("file://" + backdrop if backdrop else "")}
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: {w}
    }}
    Loader {{
        anchors.fill: parent
        active: Config.desktop.depthClock ?? false
        sourceComponent: DepthClock {{
            wallpaperPath: {json.dumps(wall)}
            isVideo: false
            areaKey: "render"
        }}
    }}
    DesktopWidgetsCanvas {{
        objectName: "canvas"
        anchors.fill: parent
        screenName: "render"
        bounds: ({{ x: 16, y: 60, w: {w} - 32, h: {h} - 76 }})
    }}
}}""")
        canvas = env.h.find(win, "canvas")
        QTest.qWait(2500)
        path = out / f"desktop-normal-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)
        env.h.eval(canvas, "DesktopWidgets.editMode = true")
        QTest.qWait(1200)
        path = out / f"desktop-edit-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)
        env.h.eval(canvas, "DesktopWidgets.editMode = false")
        if args.settings:
            render_settings(env, out, mode)
    return 0


def render_settings(env: SettingsEnv, out: Path, mode: str) -> None:
    win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.settings
Window {
    width: 1180; height: 1400; visible: true; color: "black"
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
    shell = env.h.find(win, "shell")
    env.h.eval(shell, 'select("desktop")')
    QTest.qWait(2500)
    for scroll in (0, 1250):
        page = env.h.find(win, "settingsPage").property("item")
        page.setProperty("contentY", scroll)
        QTest.qWait(600)
        path = out / (f"settings-desktop{'-s' + str(scroll) if scroll else ''}-{mode}.png")
        win.grabWindow().save(str(path))
        print(path)


if __name__ == "__main__":
    sys.exit(main())
