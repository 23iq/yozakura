#!/usr/bin/env python3
"""Render the file converter window (modules/converter) offscreen (private
Xvfb, never the desktop) over the wallpaper.

    tools/render/converter_render.py [--out DIR] [--mode dark|light] [--scale N]
                                     [--wallpaper FILE] [LANGUAGE ...]

States: `empty` (the drop zone), `drag` (files dragged over it), `files`
(the proposed targets of mixed kinds under a header per kind: two images,
audio, video, a document, markup that needs pandoc, data), `picker` (the
target picker of a photo; webp is chosen after it), `converting` (progress),
`done` (results with show / copy) and `error` (a failed conversion and its
short message). Writes <out>/converter-<state>-<language>[-light].png, every
visual language by default (tests/lib/languages.py). The backend is the
scripted one of tests/lib/converter_env.py (probe results of the real
backend); thumbnails are small images made here.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))


def _scale_arg() -> str:
    for i, a in enumerate(sys.argv):
        if a == "--scale" and i + 1 < len(sys.argv):
            return sys.argv[i + 1]
        if a.startswith("--scale="):
            return a.split("=", 1)[1]
    return "1"


# before Qt starts: the device pixel ratio of the renders
os.environ["QT_SCALE_FACTOR"] = _scale_arg()

import headless  # noqa: E402

headless.ensure(gl=True)

from converter_env import ConverterEnv  # noqa: E402
from languages import LANGUAGES  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtGui import QColor, QCursor, QImage, QLinearGradient, QPainter  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

FILES = ["holiday-photo.jpg", "screenshot.png", "podcast-episode.flac", "screen-recording.mkv",
         "quarterly-report.docx", "meeting-notes.md", "settings.json"]


def sample_images(d: Path) -> None:
    """Small gradient pictures for the thumbnails."""
    for name, a, b in (("holiday-photo.jpg", "#f4a261", "#2a9d8f"), ("screenshot.png", "#264653", "#e9c46a")):
        img = QImage(160, 160, QImage.Format_RGB32)
        p = QPainter(img)
        g = QLinearGradient(0, 0, 160, 160)
        g.setColorAt(0, QColor(a))
        g.setColorAt(1, QColor(b))
        p.fillRect(img.rect(), g)
        p.setBrush(QColor("#ffffff"))
        p.setPen(Qt.NoPen)
        p.drawEllipse(96, 24, 36, 36)
        p.end()
        img.save(str(d / name))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "converter"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--scale", default="1")
    ap.add_argument("--wallpaper", default="")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = args.wallpaper or state.get("current", "") or str(REPO / "assets/wallpapers_example/wallpaper-01.png")
    with tempfile.TemporaryDirectory(prefix="converter-render-") as tmp:
        files = Path(tmp)
        sample_images(files)
        for lang in args.languages:
            render(lang, args.mode, state, wall, out, files)
    return 0


def render(lang: str, mode: str, state: dict, wall: str, out: Path, files: Path) -> None:
    theme = {"language": lang, "lightMode": mode == "light", "animDuration": 0}
    env = ConverterEnv(f"converter-render-{lang}", palette=palette(mode, state), overrides={"theme": theme})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.converter
Window {{
    width: 680; height: 700; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps("file://" + wall)}; fillMode: Image.PreserveAspectCrop }}
    ConverterView {{ objectName: "view"; anchors.centerIn: parent; width: 560; height: 580; focus: true }}
}}""")
    h = env.h
    view = h.find(win, "view")

    def ev(expr: str):
        return h.eval(view, expr)

    def snap(name: str) -> None:
        # no row under the pointer (the Xvfb cursor starts mid-screen)
        QCursor.setPos(win.mapToGlobal(QPoint(2, 2)))
        QTest.mouseMove(win, QPoint(2, 2))
        QTest.qWait(500)
        path = out / f"converter-{name}-{lang}{'' if mode == 'dark' else '-light'}.png"
        win.grabWindow().save(str(path))
        print(path)

    def job(name: str, to: str, **kw) -> None:
        data = {"path": str(files / name), "to": to, **kw}
        ev("BackendService.emit('convert.job', %s)" % json.dumps(data))
        QTest.qWait(50)

    win.requestActivate()
    QTest.qWait(300)
    snap("empty")
    zone = h.find(win, "dropZone")
    zone.setProperty("dragging", True)  # files dragged over the window
    snap("drag")
    zone.setProperty("dragging", False)

    # the proposed targets, untouched
    ev("converter.add(%s)" % json.dumps([str(files / f) for f in FILES]))
    QTest.qWait(200)
    snap("files")

    ev("pickRow(%s, null)" % json.dumps(str(files / "holiday-photo.jpg")))
    snap("picker")
    ev("picker.chosen('webp'); picker.shown = false")

    for name in ("meeting-notes.md", "quarterly-report.docx", "settings.json"):
        ev("converter.remove(%s)" % json.dumps(str(files / name)))
    ev("converter.convert()")
    QTest.qWait(100)
    job("holiday-photo.jpg", "webp", id="c1", state="done", progress=1, output=str(files / "holiday-photo.webp"))
    job("screenshot.png", "jpg", id="c2", state="running", progress=0.72)
    job("podcast-episode.flac", "mp3", id="c3", state="running", progress=0.35)
    job("screen-recording.mkv", "mp4", id="c4", state="queued", progress=-1)
    snap("converting")

    job("screenshot.png", "jpg", id="c2", state="done", progress=1, output=str(files / "screenshot.jpg"))
    job("podcast-episode.flac", "mp3", id="c3", state="done", progress=1, output=str(files / "podcast-episode.mp3"))
    job("screen-recording.mkv", "mp4", id="c4", state="done", progress=1, output=str(files / "screen-recording (1).mp4"))
    snap("done")

    job("screen-recording.mkv", "mp4", id="c4", state="failed",
        error="Error while decoding stream #0:0: Invalid data found when processing input")
    job("podcast-episode.flac", "mp3", id="c3", state="failed", error="Unknown encoder 'libmp3lame'")
    snap("error")


if __name__ == "__main__":
    sys.exit(main())
