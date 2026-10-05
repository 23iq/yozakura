#!/usr/bin/env python3
"""Render the settings preset studio offscreen (private Xvfb, never the desktop).

    tools/render/presets_render.py [--out DIR] [--mode dark|light|both]
                                   [--size 1280x900] [--editor NAME] [--builtin NAME]

Views: gallery, mixer, editor of a user preset, editor of a built-in
preset, the "editing preset" banner on another page and the trial pill.
The studio runs the real `<app> preset` CLI of this checkout against a
private copy of your presets (tests/lib/preset_sandbox.py); wallpaper,
palette and scheme previews come from your setup like settings_render.py.
Writes <out>/<view>-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from preset_sandbox import PresetSandbox  # noqa: E402
from settings_env import BRAND_CACHE, SettingsEnv  # noqa: E402
from settings_render import palette, scheme_palettes, wallpaper_state  # noqa: E402

USER_PRESETS = Path.home() / ".config" / "yozakura" / "presets"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "presets"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1280x900")
    ap.add_argument("--editor", default="", help="user preset for the editor view (default: first user preset)")
    ap.add_argument("--builtin", default="Neon Tokyo", help="built-in preset for the read-only editor view")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    schemes = scheme_palettes(state)
    try:
        scheme = json.loads((Path.home() / ".cache" / "yozakura" / "wallpapers.json").read_text()).get("matugenScheme")
    except (OSError, ValueError):
        scheme = None
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        render_mode(mode, args, state, schemes, scheme, out, (w, h))
    return 0


def render_mode(mode: str, args, state: dict, schemes: dict, scheme: str | None, out: Path, size: tuple[int, int]) -> None:
    w, h = size
    sb = PresetSandbox(Path(tempfile.mkdtemp(prefix="presets-render-")), user_presets=USER_PRESETS,
                       wallpapers={"matugenScheme": scheme or "scheme-tonal-spot", "currentWall": state.get("current", "")})
    user = [p["name"] for p in sb.json("list", "--json") if not p["official"] and not p.get("shadowed")]
    editor = args.editor or (user[0] if user else "")
    if not editor:
        sb.run(["duplicate", args.builtin, "My look"])
        editor = "My look"
    env = SettingsEnv(f"presets-{mode}", palette=palette(mode, state), user_config=True,
                      overrides={"theme": {"lightMode": mode == "light"}}, wallpaper=state)
    # Brand.cacheDir of the harness (thumbnail PNG cache).
    (BRAND_CACHE / "preset-thumbs").mkdir(parents=True, exist_ok=True)
    bridge = sb.bridge()  # keep a reference: the QML context does not own it
    env.h.engine.rootContext().setContextProperty("presetBridge", bridge)
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
    shell = env.h.find(win, "shell")
    ev = env.h.eval
    ev(shell, "PresetStudio.runner = function (a, cb) { var r = presetBridge.run(a); cb(r[0], r[1], r[2]); }")
    ev(shell, f"SchemePreviews.palettes = {json.dumps(schemes)}")
    ev(shell, "SchemePreviews.loadedSource = SchemePreviews.source")

    def page():
        return env.h.find(win, "settingsPage").property("item")

    def snap(name: str, wait: int = 2500) -> None:
        QTest.mouseMove(win, QPoint(120, h - 30))  # over the sidebar: no card hover in the shot
        QTest.qWait(wait)
        path = out / f"{name}-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)

    ev(shell, 'select("presets")')
    snap("gallery", 4000)
    ev(page(), 'show("mixer")')
    names = [p["name"] for p in sb.json("list", "--json")]
    pick = {a: names[(i * 4 + 2) % len(names)] for i, a in enumerate(["layout", "colors", "windows", "desktop", "lockscreen"])}
    ev(page(), f"current.sources = {json.dumps(pick)}")
    snap("mixer")
    ev(page(), f'show("editor:{editor}")')
    snap("editor")
    ev(page(), f'show("editor:{args.builtin}")')
    snap("editor-builtin")
    ev(page(), 'show("gallery")')
    ev(shell, f'PresetStudio.tryPreset("{args.builtin}")')
    snap("trial", 1200)
    ev(shell, "PresetStudio.endTrial(false)")
    ev(shell, f'PresetStudio.beginEdit("{editor}")')
    ev(shell, 'select("appearance")')
    snap("editing-banner", 1500)
    ev(shell, "PresetStudio.finishEdit(false, false)")


if __name__ == "__main__":
    sys.exit(main())
