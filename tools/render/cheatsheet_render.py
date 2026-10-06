#!/usr/bin/env python3
"""Render the keybind cheatsheet once per visual language (private Xvfb).

    tools/render/cheatsheet_render.py [--out DIR] [--mode dark|light] [LANGUAGE ...]

The fullscreen cheatsheet (scrim + CheatsheetPanel) with your real config,
binds.json, palette and wallpaper (see settings_render.py), at rest and
searching ("work", second hit selected). Writes
<out>/cheatsheet[-search]-<language>.png. keybinds_render.py covers the
editor and light / dark.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import USER_BINDS, SettingsEnv, default_binds  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    try:
        binds = json.loads(USER_BINDS.read_text())
    except (OSError, ValueError):
        binds = default_binds()
    for lang in args.languages:
        env = SettingsEnv(f"cheatsheet-{lang}", palette=palette(args.mode, state), user_config=True,
                          overrides={"theme": {"language": lang, "lightMode": args.mode == "light"}},
                          wallpaper=state, binds=binds)
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.keybinds
Window {{
    width: 1600; height: 1000; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    Rectangle {{ anchors.fill: parent; color: Colors.background; opacity: 0.72 }}
    CheatsheetPanel {{ objectName: "panel"; anchors.fill: parent; anchors.margins: 64 }}
}}""")
        panel = env.h.find(win, "panel")
        env.h.eval(panel, "KeybindsStore.revision++")
        search = env.h.find(win, "cheatsheetSearch")
        for name, query in (("", ""), ("-search", "work")):
            if query:
                search.setProperty("text", query)
                env.h.eval(panel, "selectedIndex = 1")
            QTest.qWait(700)
            path = out / f"cheatsheet{name}-{lang}.png"
            win.grabWindow().save(str(path))
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
