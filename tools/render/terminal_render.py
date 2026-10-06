#!/usr/bin/env python3
"""Render Settings > Terminal & Apps > Terminal look offscreen (private Xvfb,
never the desktop).

    tools/render/terminal_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1100]

The prompt previews are real: every preset is rendered by the installed
Starship in the backend's fixture repo with your palette
(tools/render/termpreview.go), oh-my-posh (missing here) gives the
approximate renderer. Palette and wallpaper come from your setup like
settings_render.py. Views: `page` (preview, notices, gallery), `gallery`
(scrolled to the cards), `controls` (engine, greeting, padding, cursor),
`approx` (oh-my-posh missing, fish not the login shell, a foreign prompt
in config.fish, fastfetch greeting, block cursor), `notices` (no Nerd Font
on the system, the engine installing for this prompt).
Writes <out>/<view>-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from extras_env import full_catalog  # noqa: E402
from extras_render import with_ansi  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtGui import QCursor  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402
from terminal_env import STATUS, TerminalEnv  # noqa: E402


def previews(pal: dict) -> tuple[list, dict]:
    """(presets, {"engine:id": preview}) for both engines, from the real
    preset files and renderer."""
    out: dict = {}
    presets: list = []
    with tempfile.TemporaryDirectory() as tmp:
        colors = Path(tmp) / "colors.json"
        colors.write_text(json.dumps(pal))
        for engine in ("starship", "ohmyposh"):
            r = subprocess.run(["go", "run", str(REPO / "tools/render/termpreview.go"), str(colors),
                                str(REPO / "assets/terminal/prompts"), engine],
                               cwd=REPO / "backend", capture_output=True, text=True, check=True)
            data = json.loads(r.stdout)
            presets = data.pop("_presets")
            out.update({f"{engine}:{k}": v for k, v in data.items()})
    return presets, out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "terminal"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1280x1100")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for mode in (["dark", "light"] if args.mode == "both" else [args.mode]):
        render(mode, state, out, w, h)
    return 0


def render(mode: str, state: dict, out: Path, w: int, h: int) -> None:
    pal = with_ansi(palette(mode, state), mode == "dark")
    presets, pvs = previews(pal)
    status = {**STATUS, "engineInstalled": {"starship": True, "ohmyposh": False}}
    env = TerminalEnv(f"terminal-{mode}", palette=pal, user_config=True, wallpaper=state, presets=presets,
                      previews=pvs, status=status, catalog=full_catalog(),
                      overrides={"theme": {"lightMode": mode == "light"},
                                 "terminal": {"enabled": False, "engine": "starship", "prompt": "sakura-powerline"}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.services
import qs.config
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
    ev = env.h.eval
    shell = env.h.find(win, "shell")

    def snap(name: str, wait: int = 900) -> None:
        QCursor.setPos(win.mapToGlobal(QPoint(w - 4, 4)))
        QTest.mouseMove(win, QPoint(w - 4, 4))
        QTest.qWait(wait)
        path = out / f"{name}-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)

    def item(root, name: str):
        for c in root.childItems():
            if c.objectName() == name:
                return c
            found = item(c, name)
            if found is not None:
                return found
        return None

    def scroll_to(name: str, offset: int = 24) -> None:
        page = env.h.find(win, "settingsPage").property("item")
        target = item(page, name)
        y = target.mapToItem(page.property("contentItem"), 0, 0).y()
        page.setProperty("contentY", max(0, y - offset))

    ev(shell, 'select("terminal")')
    snap("page", 2500)
    scroll_to("settingRow:terminal.look", -380)
    snap("gallery")
    scroll_to("settingRow:terminal.enabled")
    snap("controls")

    ev(win, "TerminalLookService.choose('two-line-box')")
    ev(win, "Config.terminal.engine = 'ohmyposh'")
    ev(win, "Config.terminal.greeting = 'fastfetch'")
    ev(win, "Config.terminal.cursorShape = 'block'")
    ev(win, "Config.terminal.cursorBlink = false")
    late = json.dumps({**status, "enabled": True, "fishIsLoginShell": False, "foreignPromptInit": True,
                       "foreignFile": "/home/you/.config/fish/config.fish"})
    ev(win, "BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s, 'term.apply': %s})"
        % (late, late))
    ev(win, "TerminalLookService.refreshStatus()")
    env.h.find(win, "settingsPage").property("item").setProperty("contentY", 0)
    snap("approx", 1500)

    # No Nerd Font on the system + the engine being installed for this prompt.
    ev(win, "TerminalLookService._families = ['Noto Sans', 'DejaVu Sans Mono']")
    ev(win, "TerminalLookService.choose('sakura-powerline')")
    ev(win, "Config.terminal.greeting = 'none'")
    ev(win, "BackendService.emit('extras.progress', %s)" % json.dumps(
        {"job": "system-7", "kind": "system", "entries": ["oh-my-posh"], "state": "running", "percent": 62,
         "phase": "Downloading oh-my-posh 26.1"}))
    snap("notices", 1500)


if __name__ == "__main__":
    sys.exit(main())
