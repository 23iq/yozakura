#!/usr/bin/env python3
"""Render the settings chrome with the active preset footer offscreen
(private Xvfb, never the live desktop).

    tools/render/presetstatus_render.py [--out DIR] [--languages ink,glass,tiles]
                                        [--mode dark|light] [--size 1180x780]
                                        [--sheet] [--compact] [--accent HEX]

One PNG per language and state: a user preset vs a built-in, in sync vs
with changes (<out>/presetstatus-<owned|official>-<0|n>-<language>.png).
--sheet also opens the "Changes since" sheet, --compact renders the narrow
sidebar, --accent swaps the palette's primary colours (e.g. a green one).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import DEFAULT_PALETTE, SettingsEnv  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

CHANGES = [
    {"key": "theme.roundness", "a": 7, "b": 3},
    {"key": "bar.position", "a": "bottom", "b": "top"},
    {"key": "dock.iconSize", "a": 48, "b": 40},
]

STATES = {
    "owned-0": {"active": "My evening", "owned": True, "official": False, "changed": 0, "changes": []},
    "owned-n": {"active": "My evening", "owned": True, "official": False, "changed": 3, "changes": CHANGES},
    "official-0": {"active": "Yozakura Night", "owned": False, "official": True, "changed": 0, "changes": []},
    "official-n": {"active": "Yozakura Night", "owned": False, "official": True, "changed": 3, "changes": CHANGES},
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--languages", default="ink,glass,tiles")
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--size", default="1180x780")
    ap.add_argument("--states", default=",".join(STATES))
    ap.add_argument("--sheet", action="store_true", help="open the changes sheet")
    ap.add_argument("--compact", action="store_true", help="narrow window (compact sidebar)")
    ap.add_argument("--accent", default="", help="primary colour override, e.g. #4caf50")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    if args.compact:
        w = min(w, 820)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    for lang in [x for x in args.languages.split(",") if x]:
        pal = dict(palette(args.mode, state) or DEFAULT_PALETTE)
        if args.accent:
            for k in ("primary", "surfaceTint", "inversePrimary"):
                pal[k] = args.accent
        env = SettingsEnv(f"presetstatus-{lang}", palette=pal, user_config=True, wallpaper=state,
                          overrides={"theme": {"language": lang, "lightMode": args.mode == "light"}})
        backdrop = json.dumps("file://" + wall if wall else "")
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    function setStatus(s) {{ PresetStatusService.status = s }}
    Image {{ anchors.fill: parent; source: {backdrop}; fillMode: Image.PreserveAspectCrop }}
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
        shell = env.h.find(win, "shell")
        env.h.eval(shell, 'select("appearance")')
        for name in [x for x in args.states.split(",") if x]:
            env.h.eval(win, f"setStatus({json.dumps(STATES[name])})")
            if args.sheet:
                env.h.eval(shell, 'presetAction("changes")')
            QTest.qWait(900)
            suffix = ("-sheet" if args.sheet else "") + ("-compact" if args.compact else "") + \
                ("-accent" if args.accent else "")
            path = out / f"presetstatus-{name}{suffix}-{lang}{'' if args.mode == 'dark' else '-light'}.png"
            win.grabWindow().save(str(path))
            print(path)
            if args.sheet:
                env.h.find(win, "presetChangesSheet").setProperty("open", False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
