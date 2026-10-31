#!/usr/bin/env python3
"""Render theme.lighting offscreen (private Xvfb, never the live desktop).

    tools/render/lighting_render.py [--out DIR] [--palette default|green ...]
                                    [--language ink|glass|tiles ...]
                                    [--time morning|noon|evening|night ...]
                                    [--mode sun|fixed|off]
                                    [--strength subtle|normal|dramatic]
                                    [--corners round|cut|squircle]

Draws a floating bar and a kit panel (real StyledRect surfaces with the
theme shadow, lit edge and cursor lantern, over the example wallpaper) at
a fixed place (Madrid) and moment (2026-10-31): morning, noon, evening and
night (the night scene turns the lantern on and hovers the panel). Writes
<out>/lighting-<palette>-<language>-<time>.png and one contact sheet per
palette, <out>/lighting-<palette>.png (rows = languages, columns = times).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (wraps the Window as QQuickWindow)
from PySide6.QtTest import QTest  # noqa: E402

from kit_env import KitEnv  # noqa: E402
from settings_env import DEFAULT_PALETTE  # noqa: E402

PLACE = (40.4, -3.7)
TIMES = {
    "morning": "2026-10-31T07:40:00Z",
    "noon": "2026-10-31T12:00:00Z",
    "evening": "2026-10-31T16:20:00Z",
    "night": "2026-10-31T21:00:00Z",
}
GREEN_SEED = "#3f9b5a"
W, H = 720, 340

SCENE = """
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit

Window {
    width: %(w)d; height: %(h)d; visible: true; color: "black"
    function setLight(ms, lat, lon, mode, lantern, strength) {
        Lighting.latitude = lat;
        Lighting.longitude = lon;
        Lighting.overrideTime = ms;
        Config.theme.lighting = Object.assign({}, Config.theme.lighting, { mode: mode, lantern: lantern, strength: strength });
    }
    Item {
        objectName: "scene"
        anchors.fill: parent
        LanternScope {}
        Image { anchors.fill: parent; source: "%(wall)s"; fillMode: Image.PreserveAspectCrop; sourceSize.width: %(w)d }

        // Floating bar
        StyledRect {
            id: bar
            x: Space.xl; y: Space.l
            width: parent.width - Space.xl * 2
            height: Space.controlM
            variant: "bg"
            glassSurface: "bar"
            enableShadow: true
            radius: Space.surfaceRadius
            Row {
                anchors.left: parent.left; anchors.leftMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                IconButton { icon: Icons.squaresFour; size: "s" }
                Chip { text: "1"; active: true }
                Chip { text: "2" }
                Chip { text: "3" }
            }
            KitText { anchors.centerIn: parent; role: "label"; text: "Sat 31  18:20" }
            Row {
                anchors.right: parent.right; anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                IconButton { icon: Icons.wifiHigh; size: "s" }
                IconButton { icon: Icons.speakerHigh; size: "s" }
                IconButton { icon: Icons.batteryHigh; size: "s" }
            }
        }

        // Panel under the bar
        Surface {
            id: panel
            objectName: "panel"
            x: parent.width - width - Space.xl - Space.l
            y: bar.y + bar.height + Space.l
            width: 300
            glassSurface: "popups"
            enableShadow: true
            Column {
                width: 300 - panel.padding * 2
                spacing: Space.s
                SectionLabel { text: "Quick settings" }
                ListRow { width: parent.width; title: "Wi-Fi"; subtitle: "Home network"; selected: true }
                ListRow { width: parent.width; title: "Bluetooth"; subtitle: "Off" }
                LineSlider { width: parent.width; icon: Icons.speakerHigh; value: 0.6 }
            }
        }
    }
}
"""


def camel(role: str) -> str:
    if role.startswith("on_"):
        role = "over_" + role[3:]
    head, *rest = role.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def palette(name: str) -> dict:
    if name == "default":
        return DEFAULT_PALETTE
    r = subprocess.run(["matugen", "color", "hex", GREEN_SEED, "--dry-run", "-q", "-j", "hex", "-m", "dark"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("matugen failed: " + r.stderr)
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v["dark"]["color"] for k, v in json.loads(r.stdout)["colors"].items() if "dark" in v})
    return out


def wallpaper(number: str) -> str:
    path = REPO / "assets" / "wallpapers_example" / f"wallpaper-{number}.png"
    return "file://" + str(path) if path.is_file() else ""


def epoch_ms(iso: str) -> int:
    from datetime import datetime
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def render(out: Path, pal: str, lang: str, times: list[str], mode: str, wall: str, strength: str,
           corners: str = "round") -> list[Path]:
    env = KitEnv(f"lighting-{pal}-{lang}", palette=palette(pal),
                 overrides={"theme": {"language": lang, "shape": {"popupCorners": corners}}})
    win = env.load(SCENE % {"w": W, "h": H, "wall": wallpaper(wall)})
    panel = env.h.find(win, "panel")
    paths = []
    for t in times:
        night = t == "night"
        env.h.eval(win, f"setLight({epoch_ms(TIMES[t])}, {PLACE[0]}, {PLACE[1]}, '{mode}', '{'night' if night else 'off'}', '{strength}')")
        QTest.qWait(150)
        # The lantern follows the pointer: hover the panel's upper rows
        px = int(panel.property("x") + panel.property("width") * 0.38)
        py = int(panel.property("y") + 70)
        QTest.mouseMove(win, QPoint(px - 40, py) if night else QPoint(4, H - 4))
        QTest.qWait(60)
        QTest.mouseMove(win, QPoint(px, py) if night else QPoint(5, H - 5))
        QTest.qWait(700)
        path = out / f"lighting-{pal}-{lang}-{t}.png"
        win.grabWindow().save(str(path))
        paths.append(path)
        print(path)
    return paths


def sheet(out: Path, pal: str, grid: list[list[Path]]) -> None:
    from PIL import Image
    rows, cols = len(grid), max(len(r) for r in grid)
    img = Image.new("RGB", (cols * W, rows * H))
    for y, row in enumerate(grid):
        for x, p in enumerate(row):
            img.paste(Image.open(p).convert("RGB"), (x * W, y * H))
    path = out / f"lighting-{pal}.png"
    img.save(path)
    print(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--palette", action="append", choices=["default", "green"])
    ap.add_argument("--language", action="append", choices=["ink", "glass", "tiles", "classic"])
    ap.add_argument("--time", action="append", choices=list(TIMES))
    ap.add_argument("--mode", default="sun", choices=["sun", "fixed", "off"])
    ap.add_argument("--strength", default="normal", choices=["subtle", "normal", "dramatic"])
    ap.add_argument("--corners", default="round", choices=["round", "cut", "squircle"],
                    help="popup corner style (cut/squircle render through CornerMask)")
    ap.add_argument("--wallpaper", default="09", help="assets/wallpapers_example number (09: light, shows shadows)")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    times = args.time or list(TIMES)
    for pal in args.palette or ["default", "green"]:
        grid = [render(out, pal, lang, times, args.mode, args.wallpaper, args.strength, args.corners)
                for lang in args.language or ["ink", "glass", "tiles"]]
        sheet(out, pal, grid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
