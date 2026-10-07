#!/usr/bin/env python3
"""Render whole-screen bar panel layouts offscreen (private Xvfb, never the
live desktop): wallpaper, frame, every panel of bar.panels, the notch and
tiled windows in the work area the panels reserve.

    tools/render/panels_render.py LAYOUT.json [...] [--out DIR] [--mode dark|light|both]
                                  [--size 2560x1440] [--sheet SHEET.png] [--repo PATH]
    tools/render/panels_render.py --bar-matrix [--bar-surface] [--only TEXT] --out DIR

--bar-matrix renders the bar matrix of bar_matrix.py (every bar style on the
top and left edges x ink/glass/tiles, cropped to the strip, and every bar
popup opened), 1600x900 dark, no windows; --bar-surface gives the strip a
visible background (srBarBg) so the groups show the language's group box.

A LAYOUT.json holds config overrides per domain: {"name": "...", "bar":
{...}, "notch": {...}, "theme": {...}, "dock": {...}}, optional "actions"
and "crop" ({"edge": "top|left|...", "size": px} or {"around": [objectName,
...], "pad": px}). Theme and palette
come from your config (~/.config/yozakura, ~/.cache/yozakura/colors.json;
light mode is generated with matugen). Writes <out>/<name>-<mode>.png and,
with --sheet, a labelled contact sheet of every render.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import headless  # noqa: E402

headless.ensure(gl=True)

import bar_matrix  # noqa: E402
import bundled_fonts  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QRect, QRectF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QFont, QImage, QPainter  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import color_source, palette, wallpaper_state  # noqa: E402

USER_CONFIG = Path.home() / ".config" / "yozakura" / "config"


def user_domain(name: str) -> dict:
    try:
        return json.loads((USER_CONFIG / f"{name}.json").read_text())
    except (OSError, ValueError):
        return {}


def find_item(item, name: str):
    """Depth-first search of the visual tree (Repeater/Loader items have no QObject parent)."""
    if item.objectName() == name:
        return item
    for child in item.childItems():
        found = find_item(child, name)
        if found is not None:
            return found
    return None


def render(layout: dict, mode: str, size: tuple[int, int], out: Path, state: dict, repo: Path,
           windows: bool = True) -> Path:
    theme = {**user_domain("theme"), **layout.get("theme", {}), "lightMode": mode == "light"}
    bar = {**user_domain("bar"), **layout.get("bar", {})}
    notch = {**user_domain("notch"), **layout.get("notch", {})}
    extra = {k: v for k, v in layout.items()
             if k not in ("name", "bar", "theme", "notch", "dock", "label", "actions", "crop")}
    bundled_fonts.register(repo)
    env = PanelsEnv(f"panels-{layout.get('name', 'layout')}-{mode}", repo=repo, bar=bar, theme=theme,
                    notch=notch, dock=layout.get("dock"), palette=palette(mode, state), extra=extra)
    win = env.scene(size[0], size[1], wallpaper=color_source(state), windows=windows)
    QTest.qWait(1200)
    # "actions": [{"object": "<objectName>", "eval": "<expression>"}] (hover, open popups...)
    for action in layout.get("actions", []):
        obj = find_item(win.contentItem(), action["object"])
        if obj is None:
            print(f"warning: no object named {action['object']!r}", file=sys.stderr)
            continue
        env.h.eval(obj, action["eval"])
        QTest.qWait(action.get("wait", 400))
    suffix = "" if layout.get("crop") else f"-{mode}"
    path = out / f"{layout.get('name', 'layout')}{suffix}.png"
    image = win.grabWindow()
    rect = crop_rect(win, layout.get("crop"), image.width(), image.height())
    (image.copy(rect) if rect is not None else image).save(str(path))
    print(path, flush=True)
    win.close()
    return path


def crop_rect(win, crop: dict | None, width: int, height: int) -> QRect | None:
    """The part of the scene a layout's "crop" keeps: an edge strip, or the
    union of named items (a module and its open popup) plus padding."""
    if not crop:
        return None
    if "edge" in crop:
        n = int(crop.get("size", 96))
        return {"top": QRect(0, 0, width, n), "bottom": QRect(0, height - n, width, n),
                "left": QRect(0, 0, n, height), "right": QRect(width - n, 0, n, height)}[crop["edge"]]
    box = None
    for name in crop.get("around", []):
        item = find_item(win.contentItem(), name)
        if item is None or not item.isVisible():
            continue
        r = item.mapRectToScene(QRectF(0, 0, item.width(), item.height()))
        box = r if box is None else box.united(r)
    if box is None:
        return None
    pad = int(crop.get("pad", 24))
    return box.toAlignedRect().adjusted(-pad, -pad, pad, pad).intersected(QRect(0, 0, width, height))


def contact_sheet(paths: list[tuple[str, Path]], dest: Path, cols: int = 2, thumb_w: int = 1280) -> None:
    thumbs = []
    for label, p in paths:
        img = QImage(str(p))
        thumbs.append((label, img.scaledToWidth(thumb_w, Qt.TransformationMode.SmoothTransformation)))
    th = thumbs[0][1].height()
    pad, label_h = 24, 44
    rows = (len(thumbs) + cols - 1) // cols
    sheet = QImage(cols * thumb_w + (cols + 1) * pad, rows * (th + label_h) + (rows + 1) * pad,
                   QImage.Format.Format_RGB32)
    sheet.fill(QColor("#101014"))
    p = QPainter(sheet)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    font = QFont("Inter")
    font.setPixelSize(22)
    font.setBold(True)
    p.setFont(font)
    for i, (label, img) in enumerate(thumbs):
        x = pad + (i % cols) * (thumb_w + pad)
        y = pad + (i // cols) * (th + label_h + pad)
        p.setPen(QColor("#e8e4ec"))
        p.drawText(QRectF(x, y, thumb_w, label_h - 8), Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                   label)
        p.drawImage(x, y + label_h, img)
    p.end()
    sheet.save(str(dest))
    print(dest)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("layouts", nargs="*")
    ap.add_argument("--bar-matrix", action="store_true", help="the bar styles x edges x languages + popups matrix")
    ap.add_argument("--bar-surface", action="store_true", help="matrix: a visible strip background")
    ap.add_argument("--only", default="", help="matrix: only layouts whose name contains this text")
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "panels"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="2560x1440")
    ap.add_argument("--sheet", default="")
    ap.add_argument("--repo", default=str(REPO), help="render another checkout (before/after comparisons)")
    ap.add_argument("--no-windows", action="store_true", help="no tiled windows (pixel comparisons)")
    args = ap.parse_args()
    size = tuple(int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    done = []
    layouts = [{"name": Path(f).stem, **json.loads(Path(f).read_text())} for f in args.layouts]
    if args.bar_matrix:
        modes, size = ["dark"], (1600, 900)
        layouts += [lay for lay in bar_matrix.strips(args.bar_surface) + bar_matrix.popups(args.bar_surface)
                    if args.only in lay["name"]]
    for layout in layouts:
        for mode in modes:
            windows = not (args.no_windows or args.bar_matrix)
            path = render(layout, mode, size, out, state, Path(args.repo), windows)
            done.append((f"{layout.get('label', layout['name'])} — {mode}", path))
    if args.sheet:
        contact_sheet(done, Path(args.sheet))
    return 0


if __name__ == "__main__":
    code = main()
    sys.stdout.flush()
    # Skip PySide's engine teardown (can crash after several scenes)
    os._exit(code)
