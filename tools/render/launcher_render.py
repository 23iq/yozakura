#!/usr/bin/env python3
"""Render launcher result states offscreen (private Xvfb, never the live desktop).

    tools/render/launcher_render.py [--out DIR] [--mode dark|light|both]
                                    [--roundness N] [STATE ...]

Uses tests/lib/launcher_env.py with your real config, palette and wallpaper
(see settings_render.py); apps, presets and file hits are fixtures. Each
state types a query into the launcher (or expands options) and writes
<out>/launcher-<state>-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from launcher_env import LauncherEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

# name -> (search text, extra JS on the LauncherSearch, wait ms)
STATES = {
    "empty": ("", "", 500),
    "apps": ("fi", "", 400),
    "calc": ("12*7", "", 300),
    "units": ("5 kg in lb", "", 300),
    "currency": ("100 usd in rub", "", 500),
    "commands": (">", "", 300),
    "command-args": (">preset ", "", 300),
    "command-error": ("> glass 3", "", 300),
    "mixed-command": ("random wallpaper", "", 300),
    "files": ("ff notes", "FILES", 600),
    "wallpapers": ("ww ", "", 900),
    "ai": ("?how do I split a pane in tmux", "", 300),
    "ai-mixed": ("what is a monad", "", 300),
    "options": ("kitty", "expand(0); optionIndex = 1", 600),
}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("states", nargs="*", default=list(STATES))
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--roundness", type=int, default=-1, help="override theme.roundness")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        theme = {"lightMode": mode == "light"}
        if args.roundness >= 0:
            theme["roundness"] = args.roundness
        env = LauncherEnv(f"launcher-render-{mode}", palette=palette(mode, state), user_config=True,
                          overrides={"theme": theme}, wallpaper=state)
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.widgets.launcher
Window {{
    width: 600; height: 420; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    StyledRect {{
        variant: "bg"
        anchors.centerIn: parent
        width: view.implicitWidth + 32
        height: view.implicitHeight + 32
        radius: Styling.radius(16)
        LauncherView {{ id: view; objectName: "view"; anchors.centerIn: parent; width: implicitWidth; height: implicitHeight }}
    }}
}}""")
        h = env.h
        view = h.find(win, "view")
        search = h.find(win, "launcherSearch")
        QTest.qWait(400)
        for name in args.states:
            text, js, wait = STATES[name]
            h.eval(search, "collapse()")
            h.eval(view, f"GlobalStates.launcherSearchText = {json.dumps(text)}")
            QTest.qWait(80)
            if js == "FILES":
                files = h.eval(search, "resultsHost.providers.files")
                h.eval(files, "detected = true; tools = ({fd: 'fd'})")
                h.eval(view, 'GlobalStates.launcherSearchText = "ff note"')
                h.eval(view, f"GlobalStates.launcherSearchText = {json.dumps(text)}")
                QTest.qWait(260)
                home = env.home
                hits = [f"d\t{home}/Documents/notes", f"f\t{home}/Documents/notes/meeting-notes.md",
                        f"f\t{home}/notes.txt", f"f\t{home}/Pictures/notes-whiteboard.png",
                        f"f\t{home}/src/app/release-notes.go"]
                h.eval(files, f"proc.stdout.text = {json.dumps(chr(10).join(hits))}; proc.stdout.streamFinished()")
            elif js:
                h.eval(search, js)
            QTest.qWait(wait)
            path = out / f"launcher-{name}-{mode}.png"
            win.grabWindow().save(str(path))
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
