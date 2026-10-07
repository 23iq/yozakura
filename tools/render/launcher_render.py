#!/usr/bin/env python3
"""Render the launcher offscreen (private Xvfb, never the live desktop).

    tools/render/launcher_render.py [--out DIR] [--mode dark|light|both]
                                    [--languages ink,glass,tiles]
                                    [--roundness N] [NAME ...]

Uses tests/lib/launcher_env.py with your real config, palette and wallpaper
(see settings_render.py); apps, presets and file hits are fixtures. NAME is a
look variant (VARIANTS: result style, preview, compactWhenEmpty, tabs) or a
content state (STATES, drawn in the grouped list). Each one types its query
and writes <out>/launcher-<name>-<language>[-light].png.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from kit_env import LANGUAGES  # noqa: E402
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

LIST = {"resultStyle": "list", "preview": False, "compactWhenEmpty": False, "icons": True}
# name -> (layout.launcher overrides, state, extra JS on the LauncherSearch)
VARIANTS = {
    "list": (LIST, "mixed-command", ""),
    "list-empty": (LIST, "empty", ""),
    "list-options": (LIST, "options", ""),
    "cards": ({**LIST, "resultStyle": "cards"}, "apps", ""),
    "grid": ({**LIST, "resultStyle": "grid"}, "empty", "select(1)"),
    "preview": ({**LIST, "preview": True}, "apps", ""),
    "preview-file": ({**LIST, "preview": True}, "files", "select(4)"),
    "preview-image": ({**LIST, "preview": True}, "files", "select(2)"),
    "preview-calc": ({**LIST, "preview": True}, "calc", ""),
    "compact": ({**LIST, "compactWhenEmpty": True}, "empty", ""),
    # icons: false, the text-only (command-line) list
    "text": ({**LIST, "icons": False}, "mixed-command", ""),
    "text-options": ({**LIST, "icons": False}, "options", ""),
    "text-cards": ({**LIST, "resultStyle": "cards", "icons": False}, "apps", ""),
}


def fixture_files(home: str, wall: str) -> None:
    """Real files behind the file hits, so the previews have content."""
    root = Path(home)
    (root / "Documents/notes").mkdir(parents=True, exist_ok=True)
    (root / "Pictures").mkdir(parents=True, exist_ok=True)
    (root / "Documents/notes/meeting-notes.md").write_text(
        "# Design review\n\n- Launcher: grouped results, one divider\n- Detail pane: icon, name, actions\n"
        "- Keep keyboard UX identical\n\nNext: tabs (clipboard, emoji, tmux, notes)\n")
    (root / "notes.txt").write_text("buy milk\ncall Mira at 18:00\n")
    if wall and Path(wall).exists():
        shutil.copy(wall, root / "Pictures/notes-whiteboard.png")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", default=list(VARIANTS))
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light", "both"])
    ap.add_argument("--languages", default=",".join(LANGUAGES))
    ap.add_argument("--roundness", type=int, default=-1, help="override theme.roundness")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for lang in [x for x in args.languages.split(",") if x]:
        for mode in modes:
            render(lang, mode, args, state, wall, out)
    return 0


def render(lang: str, mode: str, args, state: dict, wall: str, out: Path) -> None:
    theme = {"lightMode": mode == "light", "language": lang}
    if args.roundness >= 0:
        theme["roundness"] = args.roundness
    env = LauncherEnv(f"launcher-render-{lang}-{mode}", palette=palette(mode, state), user_config=True,
                      overrides={"theme": theme}, wallpaper=state)
    fixture_files(env.home, wall)
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.modules.widgets.launcher
Window {{
    width: 980; height: 470; visible: true; color: "black"
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    Surface {{
        variant: "bg"
        anchors.centerIn: parent
        padding: Space.l
        width: view.width + padding * 2
        height: view.height + padding * 2
        LauncherView {{ id: view; objectName: "view"; width: implicitWidth; height: implicitHeight }}
    }}
}}""")
    h = env.h
    view = h.find(win, "view")
    search = h.find(win, "launcherSearch")
    QTest.qWait(400)
    suffix = "" if mode == "dark" else "-light"
    for name in args.names:
        layout, st, extra = VARIANTS.get(name, (LIST, name, ""))
        text, js, wait = STATES[st]
        h.eval(view, f"Config.layout.launcher = Object.assign({{}}, Config.layout.launcher, {json.dumps(layout)})")
        h.eval(search, "collapse()")
        h.eval(view, 'GlobalStates.launcherSearchText = "x"')
        QTest.qWait(40)
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
        if extra:
            QTest.qWait(80)
            h.eval(search, extra)
        QTest.qWait(wait + 700)
        path = out / f"launcher-{name}-{lang}{suffix}.png"
        win.grabWindow().save(str(path))
        print(path)


if __name__ == "__main__":
    sys.exit(main())
