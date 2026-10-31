#!/usr/bin/env python3
"""Render the sentence bar (bar module `sentence`) offscreen (private Xvfb,
never the live desktop).

    tools/render/sentence_render.py [--out DIR] [--languages ink,glass,tiles]
                                    [--views wide,narrow,left,right]
                                    [--palettes default,green] [--langs en,ru]
                                    [--extras]

The notch is off, so the track and the notifications are the bar's to
say. Per palette x view x visual language x UI language:
sentence-<palette>-<view>-<language>-<lang>.png, the bar strip cropped
(wide = a 1600 px top bar, narrow = 900 px, where low ranked fragments
drop; left / right = a vertical bar, the line turned to read along it).
--extras adds, on the default palette in ink / en: hover underline
(-hover), the short wording with dots (-short), the body typeface
(-body) and the clock popup opened from the day and time (-popup).
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ.setdefault("YOZAKURA_TEST_TIMEOUT", "1800")
from settings_render import REPO  # noqa: E402  (also enters the private Xvfb)

import bundled_fonts  # noqa: E402
from barchips_render import GREEN  # noqa: E402
from PySide6.QtCore import QPoint, QRect, Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from sentence_env import find, sentence_scene  # noqa: E402
from settings_env import DEFAULT_PALETTE  # noqa: E402

H = 900
VIEWS = {"wide": ("top", 1600), "narrow": ("top", 900), "left": ("left", 1600), "right": ("right", 1600)}


def shot(win, edge: str, width: int, path: Path, depth: int = 64) -> None:
    image = win.grabWindow()
    if edge == "top":
        rect = QRect(0, 0, width, depth)
    elif edge == "left":
        rect = QRect(0, 0, depth, H)
    else:
        rect = QRect(width - depth, 0, depth, H)
    image.copy(rect).save(str(path))
    print(path, flush=True)


def render(pal_name: str, pal: dict, view: str, lang_ui: str, language: str, out: Path, **kw) -> tuple:
    edge, width = VIEWS[view]
    suffix = kw.pop("suffix", "")
    env, win, svc = sentence_scene(f"sentence-{pal_name}-{view}-{language}-{lang_ui}{suffix}", edge=edge,
                                   width=width, height=H, lang=lang_ui, language=language, palette=pal, **kw)
    QTest.qWait(500)
    shot(win, edge, width, out / f"sentence-{pal_name}-{view}-{language}-{lang_ui}{suffix}.png")
    return env, win, svc


def extras(out: Path) -> None:
    env, win, _ = render("default", DEFAULT_PALETTE, "wide", "en", "ink", out, suffix="-hover")
    link = find(win.contentItem(), "sentence:battery")
    if link is not None:
        p = link.mapToScene(link.boundingRect().center())
        QTest.mouseMove(win, QPoint(int(p.x()), int(p.y())))
        QTest.qWait(400)
        shot(win, "top", 1600, out / "sentence-default-wide-ink-en-hover.png")
    clock = find(win.contentItem(), "sentence:clock")
    if clock is not None:
        p = clock.mapToScene(clock.boundingRect().center())
        QTest.mouseClick(win, Qt.MouseButton.LeftButton, pos=QPoint(int(p.x()), int(p.y())))
        QTest.qWait(900)
        image = win.grabWindow()
        image.copy(QRect(0, 0, 1600, 620)).save(str(out / "sentence-default-wide-ink-en-popup.png"))
        print(out / "sentence-default-wide-ink-en-popup.png", flush=True)
    win.close()
    render("default", DEFAULT_PALETTE, "wide", "en", "ink", out, suffix="-short",
           options={"verbosity": "short", "separator": "dot"})[1].close()
    render("default", DEFAULT_PALETTE, "wide", "en", "glass", out, suffix="-body",
           options={"typeface": "body", "separator": "comma"})[1].close()
    render("default", DEFAULT_PALETTE, "wide", "ru", "tiles", out, suffix="-notch", notch=True)[1].close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "sentence"))
    ap.add_argument("--languages", default="ink,glass,tiles")
    ap.add_argument("--views", default="wide,narrow,left,right")
    ap.add_argument("--palettes", default="default,green")
    ap.add_argument("--langs", default="en,ru")
    ap.add_argument("--extras", action="store_true")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    bundled_fonts.register(REPO)
    pals = {"default": DEFAULT_PALETTE, "green": GREEN}
    for name in args.palettes.split(","):
        for view in args.views.split(","):
            for language in args.languages.split(","):
                for lang_ui in args.langs.split(","):
                    render(name, pals[name], view, lang_ui, language, out)[1].close()
    if args.extras:
        extras(out)
    # Skip the interpreter's Qt teardown (it may crash after many scenes)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
