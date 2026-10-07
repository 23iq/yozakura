#!/usr/bin/env python3
"""Render the glass system offscreen (private Xvfb, never the live desktop).

    tools/render/glass_render.py [--out DIR] [--preset NAME] [--amounts 0,0.3,0.6,1]
                                 [--wallpaper LABEL=PATH ...] [--size 900x420]
    tools/render/glass_render.py --scene variants [--root TREE] ...

`preview` (default) renders the settings glass preview (GlassPreview.qml: the
real StyledRect glass over the wallpaper, blurred like the compositor) for
every wallpaper x amount: <out>/glass-<label>-a<amount>.png.

`variants` renders every glass StyledRect variant over the wallpaper at the
preset's own amount: <out>/variants-<label>.png. With `--root` pointing at an
exported older tree (git archive) it renders that tree instead, for pixel
comparisons of a preset before/after a change (`--compare A.png B.png`).

The palette is generated with matugen from each wallpaper (the preset's
light/dark mode); theme + compositor values come from the preset
(~/.config/yozakura/presets/<NAME>, else the built-in set <NAME> composed
from its layout, style and palette).
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
import presetsets  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (wraps the Window as QQuickWindow)
from PySide6.QtTest import QTest  # noqa: E402

import settings_env  # noqa: E402
from settings_env import DEFAULT_PALETTE, SettingsEnv  # noqa: E402

USER_PRESETS = Path.home() / ".config" / "yozakura" / "presets"
VARIANTS = ["bg", "popup", "internalbg", "pane", "common", "barbg", "focus", "primary"]


def camel(role: str) -> str:
    if role.startswith("on_"):
        role = "over_" + role[3:]
    head, *rest = role.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def palette_for(image: str, light: bool) -> dict:
    mode = "light" if light else "dark"
    r = subprocess.run(["matugen", "image", image, "--dry-run", "-q", "-j", "hex", "-m", mode,
                        "--source-color-index", "0"], capture_output=True, text=True)
    if r.returncode != 0:
        return DEFAULT_PALETTE
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v[mode]["color"] for k, v in json.loads(r.stdout)["colors"].items() if mode in v})
    return out


def load_preset(name: str) -> dict:
    user = USER_PRESETS / name
    if user.is_dir():
        domains = presetsets.compose_folder(user)
    elif presetsets.set_dir(name).is_dir():
        domains = presetsets.compose(name)
    else:
        raise SystemExit(f"preset not found: {name}")
    return {dom: domains[dom] for dom in ("theme", "compositor") if dom in domains}


def scene_qml(scene: str, w: int, h: int, wall: str) -> str:
    if scene == "preview":
        return f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.settings.previews
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    function setAmount(a) {{ Config.theme.glass = Object.assign({{}}, Config.theme.glass, {{ amount: a }}) }}
    GlassPreview {{ objectName: "scene"; anchors.fill: parent; stageHeight: {h}; showTag: false }}
}}"""
    cells = json.dumps(VARIANTS)
    return f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    Item {{
        objectName: "scene"
        anchors.fill: parent
        Image {{ anchors.fill: parent; source: "file://{wall}"; fillMode: Image.PreserveAspectCrop; sourceSize.width: {w} }}
        Grid {{
            x: 16; y: 16; columns: 4; spacing: 16
            Repeater {{
                model: {cells}
                StyledRect {{
                    required property string modelData
                    required property int index
                    variant: modelData
                    width: ({w} - 80) / 4; height: ({h} - 48) / 2
                    enableShadow: index === 1
                    Text {{ anchors.centerIn: parent; text: parent.modelData + " Aa"; color: Styling.srItem(parent.modelData); font.pixelSize: 18 }}
                }}
            }}
        }}
    }}
}}"""


def render(args, label: str, wall: str, preset: dict, amounts: list[float | None]) -> list[Path]:
    theme = dict(preset.get("theme", {}))
    light = bool(theme.get("lightMode", False))
    overrides = {k: v for k, v in preset.items()}
    w, h = (int(x) for x in args.size.split("x"))
    env = SettingsEnv(f"glass-{label}", palette=palette_for(wall, light), overrides=overrides,
                      wallpaper={"dir": str(Path(wall).parent), "paths": [wall], "current": wall})
    win = env.load(scene_qml(args.scene, w, h, wall))
    env.h.find(win, "scene")
    out = Path(args.out)
    paths = []
    for a in amounts:
        if a is not None:
            env.h.eval(win, f"setAmount({a})")
        QTest.qWait(700)
        tag = "native" if a is None else f"a{a:g}"
        path = out / (f"glass-{label}-{tag}.png" if args.scene == "preview" else f"variants-{label}{args.suffix}.png")
        win.grabWindow().save(str(path))
        paths.append(path)
        print(path)
    return paths


def compare(a: str, b: str) -> int:
    import numpy as np
    from PIL import Image
    x = np.asarray(Image.open(a).convert("RGBA"), dtype=np.int16)
    y = np.asarray(Image.open(b).convert("RGBA"), dtype=np.int16)
    if x.shape != y.shape:
        print(f"size differs: {x.shape} vs {y.shape}")
        return 1
    d = np.abs(x - y).max(axis=2)
    print(json.dumps({"pixels": int(d.size), "differing": int((d > 0).sum()), "over2": int((d > 2).sum()),
                      "maxDelta": int(d.max())}))
    return 0 if d.max() <= 2 else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--preset", default="Yozakura")
    ap.add_argument("--amounts", default="0,0.3,0.6,1", help="comma list; 'native' = the preset's own amount")
    ap.add_argument("--wallpaper", action="append", default=[], help="LABEL=PATH (repeatable)")
    ap.add_argument("--size", default="900x420")
    ap.add_argument("--scene", default="preview", choices=["preview", "variants"])
    ap.add_argument("--root", default="", help="render another (exported) tree, e.g. a git archive of main")
    ap.add_argument("--suffix", default="", help="file name suffix (variants scene)")
    ap.add_argument("--compare", nargs=2, metavar=("A", "B"), help="pixel-compare two renders and exit")
    args = ap.parse_args()
    if args.compare:
        return compare(*args.compare)
    if args.root:
        settings_env.REPO = Path(args.root).resolve()
    Path(args.out).mkdir(parents=True, exist_ok=True)
    preset = load_preset(args.preset)
    amounts = [None if a == "native" else float(a) for a in args.amounts.split(",")]
    if args.scene == "variants":
        amounts = [None]
    example = sorted((REPO / "assets" / "wallpapers_example").glob("*.png"))
    walls = [w.split("=", 1) for w in args.wallpaper] or [["example", str(example[0])]]
    for label, wall in walls:
        render(args, label, wall, preset, amounts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
