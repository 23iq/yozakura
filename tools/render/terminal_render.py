#!/usr/bin/env python3
"""Render Settings > Terminal & Apps > Terminal look offscreen (private Xvfb,
never the desktop).

    tools/render/terminal_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1100]
                                    [--language ink|glass|tiles|classic|device ...]

The prompt previews are real: every preset is rendered by the installed
Starship in the backend's fixture repo with your palette
(tools/render/termpreview.go), oh-my-posh (missing here) gives the
approximate renderer. Palette and wallpaper come from your setup like
settings_render.py. Views: `page` (preview, notices, gallery), `gallery`
(scrolled to the cards), `controls` (engine, greeting, padding, cursor),
`approx` (oh-my-posh missing, fish not the login shell, a foreign prompt
in config.fish, fastfetch greeting, block cursor), `notices` (no Nerd Font
on the system, the engine installing for this prompt), and the greeting
section (`fetch-off`, `fetch-<look>-<logo>`: the switch on, each look, the
distro / sakura / custom logo). The greeting previews come from
tools/render/fetchpreview.go (fastfetch when installed, else the bundled
samples) or `--fetch-previews FILE` ({"<look>|<logo>|<path>": term.fetch.preview
result}, e.g. collected with `yozakura ipc call term.fetch.preview`).
`--seed '#e8a0bf'` draws everything in a matugen palette from that colour.
Writes <out>/<view>-<mode>.png (your theme.language), or
<out>/<view>-<mode>-<language>.png per --language.
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
from languages import LANGUAGES  # noqa: E402
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
    ap.add_argument("--language", action="append", choices=LANGUAGES,
                    help="visual language(s) to draw (default: the one in your config)")
    ap.add_argument("--seed", default="", help="palette seed colour (default: your palette)")
    ap.add_argument("--fetch-previews", default="", help="greeting previews JSON (default: fetchpreview.go)")
    ap.add_argument("--only", choices=["prompt", "fetch"], help="only the prompt or only the greeting views")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for mode in (["dark", "light"] if args.mode == "both" else [args.mode]):
        for lang in args.language or [""]:
            if args.only != "fetch":
                render(mode, state, out, w, h, lang)
            if args.only != "prompt":
                render_fetch(mode, state, out, w, h, lang, args.seed, args.fetch_previews)
    return 0


def fetch_previews(pal: dict) -> tuple[list, dict]:
    """(looks, {"look|logo|": preview}) from fetchpreview.go."""
    with tempfile.TemporaryDirectory() as tmp:
        colors = Path(tmp) / "colors.json"
        colors.write_text(json.dumps(pal))
        r = subprocess.run(["go", "run", str(REPO / "tools/render/fetchpreview.go"), str(colors),
                            str(REPO / "assets/terminal/fastfetch")],
                           cwd=REPO / "backend", capture_output=True, text=True, check=True)
    data = json.loads(r.stdout)
    return data.pop("_presets"), data


# (look, logo, logo path) shown in turn with the greeting on
FETCH_VIEWS = [("sakura", "sakura", ""), ("compact", "sakura", ""), ("boxed", "sakura", ""), ("full", "distro", ""),
               ("sakura", "distro", ""), ("sakura", "custom", "/home/user/cat.txt"), ("minimal", "sakura", ""),
               ("own", "sakura", "")]


def render_fetch(mode: str, state: dict, out: Path, w: int, h: int, lang: str, seed: str, previews_file: str) -> None:
    theme = {"lightMode": mode == "light", **({"language": lang} if lang else {})}
    tag = f"{mode}-{lang}" if lang else mode
    pal = with_ansi(palette(mode, state, seed), mode == "dark")
    looks, pvs = fetch_previews(pal)
    if previews_file:
        pvs.update(json.loads(Path(previews_file).read_text()))
    shells = [{"shell": "fish", "state": "on"}, {"shell": "bash", "state": "on"}, {"shell": "zsh", "state": "absent"}]
    status = {**STATUS, "greeting": {"on": False, "fastfetchInstalled": True, "ownConfig": True, "shells": shells}}
    env = TerminalEnv(f"terminal-fetch-{tag}", palette=pal, user_config=True, wallpaper=state, status=status,
                      catalog=full_catalog(), fetch_previews=pvs, replies={"term.fetch.presets": looks},
                      overrides={"theme": theme, "terminal": {"enabled": True, "engine": "starship", "prompt": "plain",
                                                             "greeting": "none", "fastfetchPreset": "sakura",
                                                             "fastfetchLogo": "sakura"}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
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
        page = env.h.find(win, "settingsPage").property("item")
        target = _item(page, "settingRow:terminal.fetch")
        y = target.mapToItem(page.property("contentItem"), 0, 0).y()
        page.setProperty("contentY", max(0, y - 24))
        QTest.qWait(300)
        path = out / f"{name}-{tag}.png"
        win.grabWindow().save(str(path))
        print(path)

    ev(shell, 'select("terminal")')
    QTest.qWait(1500)
    snap("fetch-off", 1500)
    ev(win, "SettingsStore.set('terminal.greeting', 'fastfetch')")
    on = json.dumps({**status, "greeting": {**status["greeting"], "on": True}})
    ev(win, "BackendService.replies = Object.assign({}, BackendService.replies, {'term.status': %s, 'term.apply': %s})"
        % (on, on))
    ev(win, "TerminalLookService.refreshStatus()")
    for look, logo, path in FETCH_VIEWS:
        ev(win, f"SettingsStore.set('terminal.fastfetchLogoPath', {json.dumps(path)})")
        ev(win, f"SettingsStore.set('terminal.fastfetchPreset', '{look}')")
        ev(win, f"SettingsStore.set('terminal.fastfetchLogo', '{logo}')")
        snap(f"fetch-{look}-{logo}")


def _item(root, name: str):
    for c in root.childItems():
        if c.objectName() == name:
            return c
        found = _item(c, name)
        if found is not None:
            return found
    return None


def render(mode: str, state: dict, out: Path, w: int, h: int, lang: str = "") -> None:
    theme = {"lightMode": mode == "light", **({"language": lang} if lang else {})}
    tag = f"{mode}-{lang}" if lang else mode
    pal = with_ansi(palette(mode, state), mode == "dark")
    presets, pvs = previews(pal)
    status = {**STATUS, "engineInstalled": {"starship": True, "ohmyposh": False}}
    env = TerminalEnv(f"terminal-{tag}", palette=pal, user_config=True, wallpaper=state, presets=presets,
                      previews=pvs, status=status, catalog=full_catalog(),
                      overrides={"theme": theme,
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
        path = out / f"{name}-{tag}.png"
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

    ev(win, "TerminalLookService.enablePrompt('two-line-box')")
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
    ev(win, "TerminalLookService.enablePrompt('sakura-powerline')")
    ev(win, "Config.terminal.greeting = 'none'")
    ev(win, "BackendService.emit('extras.progress', %s)" % json.dumps(
        {"job": "system-7", "kind": "system", "entries": ["oh-my-posh"], "state": "running", "percent": 62,
         "phase": "Downloading oh-my-posh 26.1"}))
    snap("notices", 1500)


if __name__ == "__main__":
    sys.exit(main())
