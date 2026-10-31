#!/usr/bin/env python3
"""Render the panorama ("emaki") wallpaper offscreen (private Xvfb, never the live desktop).

    tools/render/panorama_render.py [--out DIR] [--size 1280x720] [--screens 3]
                                    [--tint] [--palette green]

Generates its own wide test scroll (sky, far mountains, hills, a near tree
and torii; plus a grey depth map) and draws the real
modules/desktop/panorama/PanoramaView.qml at a few workspace positions, with
and without depth, and mid-pan (the parallax lead), plus the real
WallpaperForeground (desktop depth layering) over a mock desktop widget.
Writes <out>/panorama-*.png and the strip overview sheet
<out>/panorama-strip.png. Never reads your wallpapers or config.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from qmlharness import Harness  # noqa: E402

PALETTES = {
    "default": {"primary": "#e8b4c8", "surface": "#1d1b1e", "overSurface": "#e7e1e5", "outline": "#958e92"},
    "green": {"primary": "#8fd18f", "surface": "#141c14", "overSurface": "#dde8dc", "outline": "#87a087"},
}


def scroll_image(w: int, h: int, out: Path) -> tuple[Path, Path]:
    """A wide landscape and its depth map (white = near)."""
    img = Image.new("RGB", (w, h))
    dep = Image.new("L", (w, h), 0)
    px = img.load()
    for y in range(h):
        t = y / h
        c = (int(40 + 120 * t), int(60 + 90 * t), int(110 + 60 * t))
        for x in range(w):
            px[x, y] = c
    d = ImageDraw.Draw(img)
    dd = ImageDraw.Draw(dep)
    # Sun and far mountains.
    d.ellipse((w * 0.42, h * 0.18, w * 0.42 + h * 0.16, h * 0.34), fill=(250, 220, 170))

    def ridge(base, amp, freq, phase, color, depth):
        pts = [(0, h)]
        for x in range(0, w + 8, 8):
            y = base + amp * (math.sin(x * freq + phase) * 0.6 + math.sin(x * freq * 2.7 + phase * 1.7) * 0.4)
            pts.append((x, y))
        pts.append((w, h))
        d.polygon(pts, fill=color)
        dd.polygon(pts, fill=depth)

    ridge(h * 0.52, h * 0.12, 0.0021, 0.4, (74, 84, 120), 70)
    ridge(h * 0.66, h * 0.08, 0.0034, 1.9, (52, 70, 82), 130)
    ridge(h * 0.80, h * 0.05, 0.0051, 3.1, (36, 52, 48), 175)
    # Near objects: a tree per screen and a torii, numbered for reading the pan.
    screens = max(1, round(w / (h * 16 / 9)))
    for i in range(screens):
        cx = (i + 0.5) * w / screens
        if i % 2 == 0:
            d.rectangle((cx - h * 0.02, h * 0.45, cx + h * 0.02, h), fill=(30, 22, 24))
            dd.rectangle((cx - h * 0.02, h * 0.45, cx + h * 0.02, h), fill=240)
            for k in range(5):
                r = h * (0.13 - k * 0.012)
                ox = cx + math.sin(k * 2.1) * h * 0.08
                oy = h * (0.40 - k * 0.035)
                d.ellipse((ox - r, oy - r, ox + r, oy + r), fill=(150 + k * 14, 70 + k * 8, 96 + k * 10))
                dd.ellipse((ox - r, oy - r, ox + r, oy + r), fill=235)
        else:
            top = h * 0.42
            for sx in (-1, 1):
                d.rectangle((cx + sx * h * 0.12 - h * 0.018, top, cx + sx * h * 0.12 + h * 0.018, h), fill=(170, 40, 34))
                dd.rectangle((cx + sx * h * 0.12 - h * 0.018, top, cx + sx * h * 0.12 + h * 0.018, h), fill=225)
            for bar, bh in ((top - h * 0.02, h * 0.04), (top + h * 0.06, h * 0.025)):
                d.rectangle((cx - h * 0.2, bar, cx + h * 0.2, bar + bh), fill=(150, 30, 28))
                dd.rectangle((cx - h * 0.2, bar, cx + h * 0.2, bar + bh), fill=225)
        d.text((cx - 6, h * 0.08), str(i + 1), fill=(255, 255, 255))
    dep = dep.filter(ImageFilter.GaussianBlur(2))
    img_path, dep_path = out / "scroll.png", out / "scroll.depth.png"
    img.save(img_path)
    dep.save(dep_path)
    return img_path, dep_path


def harness(palette: dict) -> Harness:
    h = Harness("panorama-render")
    colors = "\n".join(f'    property color {k}: "{v}"' for k, v in palette.items())
    h.module("qs.modules.theme", {
        "Motion": """pragma Singleton
QtObject {
    component Token: QtObject { property int duration: 0; property int easing: Easing.InOutCubic }
    readonly property Token pan: Token { duration: 900 }
}""",
        "Colors": "pragma Singleton\nQtObject {\n" + colors + """
    property color background: surface; property color overBackground: overSurface; property color shadow: "black"
    property color surfaceBright: surface; property color surfaceDim: surface; property color surfaceContainer: surface
    property color surfaceContainerHigh: surface; property color surfaceContainerHighest: surface
    property color surfaceContainerLow: surface; property color surfaceContainerLowest: surface
    property color secondary: primary; property color tertiary: primary; property color red: primary; property color lightRed: primary
    property color green: primary; property color lightGreen: primary; property color blue: primary; property color lightBlue: primary
    property color yellow: primary; property color lightYellow: primary; property color cyan: primary; property color lightCyan: primary
    property color magenta: primary; property color lightMagenta: primary
}"""})
    h.module("qs.modules.services", {
        "DepthMaskService": """pragma Singleton
QtObject { property bool available: false; property int revision: 0
    function result(p, w, h) { return null } function request(p, w, h) {} }""",
        "YozdService": """pragma Singleton
QtObject { property int activeId: 1; property string compositorName: "hyprland"
    property QtObject workspaces: QtObject { property var values: [] }
    function monitorFor(s) { return { name: "TEST", activeWorkspace: { id: activeId } } } }"""})
    h.module("qs.config", {"Config": """pragma Singleton
QtObject {
    property QtObject workspaces: QtObject { property int shown: 3 }
    property QtObject desktop: QtObject { property string wallpaperMode: "panorama"; property bool panoramaParallax: true; property bool depthLayering: false }
}"""})
    h.module("qs.modules.globals", {"GlobalStates": """pragma Singleton
QtObject {
    property QtObject wallpaperManager: QtObject {
        property string currentWallpaper: ""; property var perScreenWallpapers: ({}); property var depthMaps: []
        property bool tintEnabled: false
        function getFileType(p) { return "image" }
    }
}"""})
    for f in ("PanoramaView", "PanoramaLayer", "PanoramaSlice", "WallpaperForeground", "PanoramaSlot"):
        h.copy(f"modules/desktop/panorama/{f}.qml", dest="app")
    return h


def scene(w: int, h: int, palette: dict) -> str:
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.globals
import qs.config
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    PanoramaView {{
        objectName: "view"
        anchors.fill: parent
        sourceFile: GlobalStates.wallpaperManager.currentWallpaper
        sourceWidth: {w}; sourceHeight: {h}
        visible: Config.desktop.wallpaperMode === "panorama"
        slotIndex: YozdService.activeId - 1
        slotCount: Config.workspaces.shown
        tint: GlobalStates.wallpaperManager.tintEnabled
        parallax: Config.desktop.panoramaParallax
        depthMaps: GlobalStates.wallpaperManager.depthMaps
    }}
    Image {{
        // Fill mode stand-in (StaticWallpaper: centred crop).
        anchors.fill: parent
        visible: Config.desktop.wallpaperMode !== "panorama"
        source: "file://" + GlobalStates.wallpaperManager.currentWallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: {w}; sourceSize.height: {h}
    }}
    // Mock desktop widget: behind the subject with depth layering.
    Rectangle {{
        x: parent.width * 0.38; y: parent.height * 0.5; width: parent.width * 0.24; height: parent.height * 0.3
        radius: 18; color: "{palette['surface']}"; opacity: 0.94
        border.color: "{palette['outline']}"; border.width: 1
        Text {{ anchors.centerIn: parent; color: "{palette['overSurface']}"; text: "desktop widget"; font.pixelSize: 18 }}
    }}
    WallpaperForeground {{
        anchors.fill: parent
        objectName: "foreground"
    }}
    // Mock bar: the shell chrome always stays above the wallpaper layers.
    Rectangle {{
        width: parent.width; height: 32; color: "{palette['surface']}"; opacity: 0.92
        Text {{ anchors.centerIn: parent; color: "{palette['overSurface']}"; text: "bar" }}
    }}
}}"""


def strip_scene(img: str, w: int, h: int, cells: int, palette: dict) -> str:
    cw, ch = 256, 144
    return f"""
import QtQuick
import QtQuick.Window
Window {{
    width: {cw * cells + 48}; height: {ch + 48}; visible: true; color: "{palette['surface']}"
    Row {{
        x: 24; y: 24
        Repeater {{
            model: {cells}
            Item {{
                required property int index
                width: {cw}; height: {ch}
                PanoramaSlice {{
                    anchors.fill: parent
                    sourceFile: {json.dumps(img)}
                    slotIndex: parent.index; slotCount: {cells}
                    screenW: {w}; screenH: {h}
                    opacity: parent.index === 1 ? 1 : 0.7
                }}
                Rectangle {{
                    anchors.fill: parent; color: "transparent"; radius: 8
                    border.width: parent.index === 1 ? 2 : 0; border.color: "{palette['primary']}"
                }}
                Text {{ x: 8; y: 6; text: parent.index + 1; color: "{palette['overSurface']}" }}
            }}
        }}
    }}
}}"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--screens", type=int, default=3, help="test image width in screens")
    ap.add_argument("--slots", type=int, default=3, help="workspaces")
    ap.add_argument("--tint", action="store_true")
    ap.add_argument("--palette", default="default", choices=sorted(PALETTES))
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    w, h = (int(v) for v in args.size.split("x"))
    work = out / "panorama-src"
    work.mkdir(exist_ok=True)
    img, dep = scroll_image(round(w * args.screens), h, work)
    palette = PALETTES[args.palette]
    hh = harness(palette)
    suffix = ("-tint" if args.tint else "") + ("" if args.palette == "default" else f"-{args.palette}")

    flat = work / "flat"
    flat.mkdir(exist_ok=True)
    Image.open(img).save(flat / "scroll.png")
    win = hh.load(hh.write(scene(w, h, palette), name="Scene.qml"))
    view = hh.find(win, "view")
    manager = hh.eval(win, "GlobalStates.wallpaperManager")
    config = hh.eval(win, "Config.desktop")
    yozd = hh.eval(win, "YozdService")
    manager.setProperty("tintEnabled", args.tint)

    def shot(name: str) -> None:
        target = out / f"panorama-{name}{suffix}.png"
        win.grabWindow().save(str(target))
        print(target)

    passes = [("flat", str(flat / "scroll.png"), [], False, "panorama"),
              ("depth", str(img), [str(dep)], False, "panorama"),
              ("layering", str(img), [str(dep)], True, "panorama"),
              ("fill-layering", str(img), [str(dep)], True, "fill")]
    for tag, src, maps, layering, mode in passes:
        yozd.setProperty("activeId", 1)
        config.setProperty("wallpaperMode", mode)
        config.setProperty("depthLayering", layering)
        manager.setProperty("depthMaps", maps)
        manager.setProperty("currentWallpaper", src)
        QTest.qWait(1200)
        print(tag, "depth kind:", view.property("depthKind"), "layers:", view.property("layerCount"))
        for ws in range(1, (args.slots if mode == "panorama" else 1) + 1):
            yozd.setProperty("activeId", ws)
            QTest.qWait(1300)
            shot(f"{tag}-ws{ws}")
        if mode == "panorama":
            # Mid-pan from the last workspace back to the first (parallax lead).
            yozd.setProperty("activeId", 1)
            QTest.qWait(430)
            shot(f"{tag}-midpan")
    win.close()

    strip = hh.load(hh.write(strip_scene(str(img), w, h, args.slots + 2, palette), name="Strip.qml"))
    QTest.qWait(900)
    target = out / f"panorama-strip{suffix}.png"
    strip.grabWindow().save(str(target))
    print(target)
    hh.exit(0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
