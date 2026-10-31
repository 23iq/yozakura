#!/usr/bin/env python3
"""Render theme.weatherFx offscreen (private Xvfb, never the live desktop).

    tools/render/weatherfx_render.py [--out DIR] [--palette default|green ...]
                                     [--language ink|glass|tiles|classic ...]
                                     [--condition rain|frost|fog|heat|petals ...]
                                     [--mode subtle|vivid] [--light]
    tools/render/weatherfx_render.py --cpu [--seconds N]

Draws a floating bar and a kit panel (real StyledRect surface roots over
the example wallpaper) with a forced weather condition
(WeatherFx.previewCondition) and a fixed seed, after the surfaces settled and
mid-way through a drop / flake / petal / heat wave. Writes
<out>/weatherfx-<palette>-<language>-<condition>.png and one contact sheet
per palette, <out>/weatherfx-<palette>.png (rows = languages, columns =
conditions). --cpu measures this process's CPU time while the scene idles
with the mode off and with rain on (vivid), and prints both.
"""
from __future__ import annotations

import argparse
import json
import resource
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (wraps the Window as QQuickWindow)
from PySide6.QtTest import QTest  # noqa: E402

from kit_env import KitEnv  # noqa: E402
from settings_env import DEFAULT_PALETTE  # noqa: E402

CONDITIONS = {
    # condition: (preview id, capture delay ms after the event fired)
    "rain": ("rain", 1300),
    "frost": ("snow", 1600),
    "fog": ("fog", 300),
    "heat": ("heat", 1300),
    "petals": ("petals", 1500),
    "leaves": ("leaves", 1500),
    "storm": ("storm", 1300),
    "off": ("", 0),
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
    function setFx(cond, mode) {
        WeatherFx.seed = 3;
        WeatherFx.previewCondition = cond;
        Config.theme.weatherFx = Object.assign({}, Config.theme.weatherFx, { mode: mode, heat: true, seasonal: true });
    }
    // Fire the next event of every effect now (a drop runs, a flake falls,
    // a petal lands, a heat wave passes)
    function fire(item) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            const n = c.objectName || "";
            if (n === "rainTimer" || n === "snowTimer" || n === "heatTimer" || n === "seasonalTimer")
                c.triggered();
            fire(c);
        }
        if (item.resources)
            for (let j = 0; j < item.resources.length; j++) {
                const t = item.resources[j];
                if (t && t.objectName && t.objectName.endsWith("Timer") && t.triggered)
                    t.triggered();
            }
    }
    Item {
        id: sceneItem
        objectName: "scene"
        anchors.fill: parent
        Image { anchors.fill: parent; source: "%(wall)s"; fillMode: Image.PreserveAspectCrop; sourceSize.width: %(w)d }

        StyledRect {
            id: bar
            objectName: "bar"
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
                ListRow { width: parent.width; title: "Night light"; subtitle: "Until 07:00" }
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


def palette(name: str, light: bool) -> dict:
    if name == "default" and not light:
        return DEFAULT_PALETTE
    seed = GREEN_SEED if name == "green" else DEFAULT_PALETTE.get("primary", "#ffb3b0")
    scheme = "light" if light else "dark"
    r = subprocess.run(["matugen", "color", "hex", seed, "--dry-run", "-q", "-j", "hex", "-m", scheme],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("matugen failed: " + r.stderr)
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v[scheme]["color"] for k, v in json.loads(r.stdout)["colors"].items() if scheme in v})
    return out


def wallpaper(number: str) -> str:
    path = REPO / "assets" / "wallpapers_example" / f"wallpaper-{number}.png"
    return "file://" + str(path) if path.is_file() else ""


def env_for(pal: str, lang: str, light: bool) -> KitEnv:
    tag = f"weatherfx-{pal}-{lang}{'-light' if light else ''}"
    return KitEnv(tag, palette=palette(pal, light),
                  overrides={"theme": {"language": lang, "lightMode": light, "shape": {"popupCorners": "round"}}})


def render(out: Path, pal: str, lang: str, conds: list[str], mode: str, wall: str, light: bool) -> list[Path]:
    env = env_for(pal, lang, light)
    win = env.load(SCENE % {"w": W, "h": H, "wall": wallpaper(wall)})
    paths = []
    for c in conds:
        cid, delay = CONDITIONS[c]
        env.h.eval(win, f"setFx('{cid}', '{mode if cid else 'off'}')")
        QTest.qWait(2800)  # frost creeps in, drops land
        env.h.eval(win, "fire(sceneItem)")
        QTest.qWait(delay)
        suffix = "-light" if light else ""
        path = out / f"weatherfx-{pal}-{lang}-{c}{suffix}.png"
        win.grabWindow().save(str(path))
        paths.append(path)
        print(path)
    return paths


def sheet(out: Path, name: str, grid: list[list[Path]]) -> None:
    from PIL import Image
    rows, cols = len(grid), max(len(r) for r in grid)
    img = Image.new("RGB", (cols * W, rows * H))
    for y, row in enumerate(grid):
        for x, p in enumerate(row):
            img.paste(Image.open(p).convert("RGB"), (x * W, y * H))
    path = out / f"{name}.png"
    img.save(path)
    print(path)


def cpu(seconds: float, lang: str) -> int:
    env = env_for("default", lang, False)
    win = env.load(SCENE % {"w": W, "h": H, "wall": wallpaper("09")})

    frames = [0]
    win.frameSwapped.connect(lambda: frames.__setitem__(0, frames[0] + 1))

    def measure(label: str) -> float:
        QTest.qWait(3000)  # settle
        r0, t0, f0 = resource.getrusage(resource.RUSAGE_SELF), time.monotonic(), frames[0]
        QTest.qWait(int(seconds * 1000))
        r1, t1 = resource.getrusage(resource.RUSAGE_SELF), time.monotonic()
        used = (r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)
        pct = 100 * used / (t1 - t0)
        fps = (frames[0] - f0) / (t1 - t0)
        print(f"{label}: {used:.3f} s CPU over {t1 - t0:.1f} s = {pct:.2f} % ({fps:.1f} frames/s, software GL)")
        return pct

    env.h.eval(win, "WeatherFx.previewCondition = ''")
    measure("mode off")
    env.h.eval(win, "setFx('rain', 'subtle')")
    measure("rain subtle")
    env.h.eval(win, "setFx('storm', 'vivid')")
    measure("storm vivid")
    env.h.eval(win, "setFx('', 'off')")
    measure("mode off again")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--palette", action="append", choices=["default", "green"])
    ap.add_argument("--language", action="append", choices=["ink", "glass", "tiles", "classic"])
    ap.add_argument("--condition", action="append", choices=list(CONDITIONS))
    ap.add_argument("--mode", default="subtle", choices=["subtle", "vivid"])
    ap.add_argument("--light", action="store_true", help="light theme palette")
    ap.add_argument("--wallpaper", default="06", help="assets/wallpapers_example number")
    ap.add_argument("--cpu", action="store_true", help="measure idle CPU: mode off vs rain")
    ap.add_argument("--seconds", type=float, default=20)
    args = ap.parse_args()
    if args.cpu:
        return cpu(args.seconds, (args.language or ["glass"])[0])
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    conds = args.condition or ["rain", "frost", "fog", "heat", "petals"]
    for pal in args.palette or ["default", "green"]:
        grid = [render(out, pal, lang, conds, args.mode, args.wallpaper, args.light)
                for lang in args.language or ["ink", "glass", "tiles"]]
        sheet(out, f"weatherfx-{pal}{'-light' if args.light else ''}", grid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
