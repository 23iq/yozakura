#!/usr/bin/env python3
"""Render the "branch" workspace indicator offscreen (private Xvfb, never the
live desktop) in the real bar.

    tools/render/branch_render.py [--out DIR] [--only TEXT] [--mode dark|light|both]
                                  [--blossom sakura|plum|round|leaf] [--role primary|...]

One sheet per bar edge (top, left) x language (ink, glass, tiles) x palette
(default, green from matugen): <out>/branch-<edge>-<language>-<palette>[-light].png,
each with the workspace states side by side: 1, 3 and 7 workspaces (mixed
window counts, the active one open), an urgent workspace and a petal
falling after a window closed. Crops are scaled x3. The palette never comes
from your config: the test default or a generated green scheme.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

import bundled_fonts  # noqa: E402
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtCore import QRect, QRectF, Qt  # noqa: E402
from PySide6.QtGui import QColor, QFont, QImage, QPainter  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import DEFAULT_PALETTE  # noqa: E402

EDGES = ["top", "left"]
LANGUAGES = ["ink", "glass", "tiles"]
GREEN = "#4c8c4a"
SCALE = 3

# name -> (shown, active workspace, {workspace: windows}, urgent workspaces)
STATES = [
    ("1 workspace", 1, 1, {1: 2}, []),
    ("3 workspaces", 3, 2, {1: 3, 2: 1}, []),
    ("7 workspaces", 7, 3, {1: 1, 2: 2, 3: 2, 4: 5, 6: 1}, []),
    ("urgent 6", 7, 3, {1: 1, 2: 2, 3: 2, 4: 5, 6: 1}, [6]),
]
# After the last state: workspace 4 loses a window, grabbed mid-fall.
FALL = ("petal falls", 4, 3, 420)


def camel(name: str) -> str:
    head, *rest = name.split("_")
    return head + "".join(p.title() for p in rest)


def green_palette(mode: str) -> dict:
    r = subprocess.run(["matugen", "color", "hex", GREEN, "--dry-run", "-q", "-j", "hex", "-m", mode],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"matugen failed: {r.stderr.strip()}")
    colors = json.loads(r.stdout)["colors"]
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v[mode]["color"] for k, v in colors.items() if mode in v})
    out["overBackground"] = out.get("onBackground", out["overBackground"])
    for role in ("primary", "secondary", "tertiary", "surface", "surfaceVariant", "error"):
        on = out.get("on" + role[0].upper() + role[1:])
        if on:
            out["over" + role[0].upper() + role[1:]] = on
    return out


def light_default() -> dict:
    """The test palette's hue in light mode (matugen from its primary)."""
    r = subprocess.run(["matugen", "color", "hex", DEFAULT_PALETTE["primary"], "--dry-run", "-q", "-j", "hex",
                        "-m", "light"], capture_output=True, text=True)
    colors = json.loads(r.stdout)["colors"]
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v["light"]["color"] for k, v in colors.items() if "light" in v})
    for role in ("background", "primary", "secondary", "tertiary", "surface", "surfaceVariant", "error"):
        on = out.get("on" + role[0].upper() + role[1:])
        if on:
            out["over" + role[0].upper() + role[1:]] = on
    return out


FIND = """
function findItem(name, from) {
    if (from.objectName === name) return from;
    var kids = from.children || [];
    for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
    return null;
}
"""


def windows_map(windows: dict) -> str:
    return json.dumps({str(ws): [{"class": "kitty", "workspace": {"id": ws}, "address": f"0x{ws}{i}"}
                                 for i in range(n)] for ws, n in windows.items()})


def strip_loader(env, win):
    """The strip Loader of Workspaces.qml (its context sees CompositorData)."""
    return env.h.eval(win, "(function(){" + FIND + "return findItem('workspaceStrip', contentItem);})()")


def widget(env, win):
    """The bar's workspaces widget."""
    strip = strip_loader(env, win)
    return strip.parentItem().parentItem() if strip is not None else None


def set_state(env, win, shown: int, active: int, windows: dict, urgent: list) -> None:
    occ = json.dumps({str(ws): True for ws, n in windows.items() if n > 0})
    urg = json.dumps({str(ws): True for ws in urgent})
    env.h.eval(strip_loader(env, win), f"""(function() {{
        Config.workspaces.shown = {shown};
        YozdService.monitor.activeWorkspace = ({{ id: {active}, name: "{active}" }});
        CompositorData.workspaceWindowsMap = {windows_map(windows)};
        CompositorData.workspaceOccupationMap = {occ};
        CompositorData.workspaceUrgentMap = {urg};
        CompositorData.windowList = [{{ n: Math.random() }}];
        return true;
    }})()""")


def grab(env, win, vertical: bool) -> QImage:
    ws = widget(env, win)
    image = win.grabWindow()
    if ws is None:
        return image
    r = ws.mapRectToScene(QRectF(0, 0, ws.width(), ws.height())).toAlignedRect()
    pad = 24
    r = r.adjusted(-pad, -pad, pad, pad).intersected(QRect(0, 0, image.width(), image.height()))
    crop = image.copy(r)
    return crop.scaled(crop.width() * SCALE, crop.height() * SCALE, Qt.AspectRatioMode.KeepAspectRatio,
                       Qt.TransformationMode.SmoothTransformation)


def sheet(shots: list[tuple[str, QImage]], vertical: bool, title: str, dest: Path) -> None:
    pad, label_h = 20, 34
    if vertical:
        w = sum(i.width() for _, i in shots) + pad * (len(shots) + 1)
        h = max(i.height() for _, i in shots) + label_h * 2 + pad * 2
    else:
        w = max(i.width() for _, i in shots) + pad * 2
        h = sum(i.height() + label_h for _, i in shots) + label_h + pad * (len(shots) + 1)
    out = QImage(max(w, 600), h, QImage.Format.Format_RGB32)
    out.fill(QColor("#101014"))
    p = QPainter(out)
    font = QFont("Inter")
    font.setPixelSize(18)
    font.setBold(True)
    p.setFont(font)
    p.setPen(QColor("#e8e4ec"))
    p.drawText(QRectF(pad, 4, out.width(), label_h), Qt.AlignmentFlag.AlignVCenter, title)
    x, y = pad, label_h + pad
    font.setBold(False)
    font.setPixelSize(15)
    p.setFont(font)
    for label, img in shots:
        p.setPen(QColor("#a8a4ac"))
        p.drawText(QRectF(x, y, img.width() + 200, label_h), Qt.AlignmentFlag.AlignVCenter, label)
        p.drawImage(x, y + label_h, img)
        if vertical:
            x += img.width() + pad
        else:
            y += img.height() + label_h + pad
    p.end()
    out.save(str(dest))
    print(dest, flush=True)


def render(edge: str, lang: str, pal_name: str, palette: dict, mode: str, args, out: Path) -> Path:
    vertical = edge in ("left", "right")
    bundled_fonts.register(REPO)
    env = PanelsEnv(f"branch-{edge}-{lang}-{pal_name}-{mode}", bar={
        "position": edge, "frameEnabled": False, "containBar": False, "panels": [],
        "layout": {"style": args.style, "left": ["workspaces"], "right": ["clock"], "drawer": []}},
        theme={"language": lang, "lightMode": mode == "light"}, palette=palette,
        extra={"workspaces": {"indicatorStyle": "branch", "shown": 7, "branchBlossom": args.blossom,
                              "branchColor": args.role}})
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(600)
    shots = []
    for label, shown, active, windows, urgent in STATES:
        set_state(env, win, shown, active, windows, urgent)
        QTest.qWait(900)
        shots.append((label, grab(env, win, vertical)))
    label, ws, active, wait = FALL
    windows = dict(STATES[-1][3])
    windows[ws] -= 1
    set_state(env, win, 7, active, windows, [])
    QTest.qWait(100 + wait)
    shots.append((label, grab(env, win, vertical)))
    suffix = "" if mode == "dark" else "-light"
    dest = out / f"branch-{edge}-{lang}-{pal_name}{suffix}.png"
    sheet(shots, vertical, f"branch · {edge} · {lang} · {pal_name} · {mode} · {args.blossom}/{args.role}", dest)
    win.close()
    return dest


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "branch"))
    ap.add_argument("--only", default="", help="only sheets whose name contains this text")
    ap.add_argument("--mode", default="dark", choices=["dark", "light", "both"])
    ap.add_argument("--blossom", default="sakura")
    ap.add_argument("--role", default="primary")
    ap.add_argument("--style", default="classic", help="bar.layout.style")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        palettes = {"default": DEFAULT_PALETTE if mode == "dark" else light_default(), "green": green_palette(mode)}
        for edge in EDGES:
            for lang in LANGUAGES:
                for pal_name, pal in palettes.items():
                    if args.only not in f"branch-{edge}-{lang}-{pal_name}":
                        continue
                    render(edge, lang, pal_name, pal, mode, args, out)
    return 0


if __name__ == "__main__":
    code = main()
    sys.stdout.flush()
    os._exit(code)
