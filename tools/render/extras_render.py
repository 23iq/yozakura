#!/usr/bin/env python3
"""Render Settings > Apps & Extras offscreen (private Xvfb, never the desktop).

    tools/render/extras_render.py [--out DIR] [--mode dark|light|both] [--size 1280x1100]

The real catalog (assets/catalog/extras.json) behind the scripted backend of
tests/lib/extras_env.py; palette and wallpaper come from your setup like
settings_render.py. Views: `page` (idle catalog), `states` (selection,
installing, failed, installed cards, the multilib confirm and the install
bar), `search` (a greyed entry unavailable here), `log` (the log popup).
Writes <out>/<view>-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
sys.path.insert(0, str(REPO / "tools" / "render"))
import headless  # noqa: E402

headless.ensure(gl=True)

from extras_env import ExtrasEnv, full_catalog  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtGui import QCursor  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

INSTALLED = {"firefox": "pkg", "kitty": "pkg", "fish": "pkg", "mpv": "pkg", "nautilus": "pkg", "telegram": "flatpak",
             "fastfetch": "pkg", "claude-code": "bin"}
LOG = ("resolving dependencies...\nlooking for conflicting packages...\n\nPackages (3) lib32-mesa-24.2 steam-1.0.0.81\n\n"
       ":: Retrieving packages...\nerror: failed retrieving file 'steam-1.0.0.81-1-x86_64.pkg.tar.zst' from mirror : "
       "The requested URL returned error: 404\nerror: failed to commit transaction (failed to retrieve some files)\n")


def with_ansi(pal: dict, dark: bool) -> dict:
    """The shell derives the terminal hues (Colors.blue, .cyan, ...) from the
    primary color (ColorUtils.ansiColors); do the same so accents match."""
    script = ("const q = require(process.argv[1]); const C = q.loadLibrary(process.argv[2]);"
              "console.log(JSON.stringify(C.ansiColors(process.argv[3], process.argv[4] === '1')))")
    r = subprocess.run(["node", "-e", script, str(REPO / "tests/lib/qmljs.cjs"), str(REPO / "modules/theme/ColorUtils.js"),
                        pal.get("primary", "#ffb2b8"), "1" if dark else "0"], capture_output=True, text=True, check=True)
    return {**pal, **json.loads(r.stdout)}


def status(catalog: dict) -> dict:
    out = {}
    for e in catalog["entries"]:
        src = INSTALLED.get(e["id"])
        out[e["id"]] = {"id": e["id"], "state": "installed", "source": src} if src else {"id": e["id"], "state": "missing"}
    out["spicetify"] = {"id": "spicetify", "state": "unavailable", "reason": "only_distro"}
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "extras"))
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
    cat = full_catalog()
    env = ExtrasEnv(f"extras-{mode}", palette=with_ansi(palette(mode, state), mode == "dark"), user_config=True, wallpaper=state,
                    overrides={"theme": {"lightMode": mode == "light"}}, catalog=cat, status=status(cat),
                    platform={"distro": "fedora", "gpu": "amd", "hasFlatpak": True, "hasNpm": True, "multilib": False},
                    replies={"extras.install": {"error": 'needs_confirm: {"kind":"multilib","entries":["steam"]}'},
                             "extras.log": {"text": LOG}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.services
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

    def emit(service: str, data) -> None:
        ev(win, "BackendService.emit('%s', %s)" % (service, json.dumps(data)))

    ev(shell, 'select("extras")')
    snap("page", 2500)
    page = env.h.find(win, "settingsPage").property("item")
    grid = env.h.find(page, "catalogGrid")

    ev(grid, "selected = {'codex': true, 'ollama': true, 'steam': true, 'vesktop': true}")
    emit("extras.progress", {"job": "script-1", "kind": "script", "entries": ["gemini-cli"], "state": "running",
                             "percent": 62, "phase": "Downloading gemini 0.9.1"})
    emit("extras.progress", {"job": "system-2", "kind": "system", "entries": ["cuda"], "state": "queued", "percent": -1})
    emit("extras.progress", {"job": "npm-3", "kind": "npm", "entries": ["opencode"], "state": "failed",
                             "reason": "network", "percent": -1})
    QTest.qWait(50)
    ev(win, "ExtrasService.offline = false")
    env.h.find(page, "installButton").setProperty("focus", False)
    ev(win, "ExtrasService.install(['steam'], false)")
    snap("states")
    ev(win, "ExtrasService.dismissConfirm()")
    ev(grid, "category = 'games'")
    emit("extras.progress", {"job": "system-4", "kind": "system", "entries": ["steam"], "state": "failed",
                             "reason": "needs_sync", "percent": -1})
    emit("extras.progress", {"job": "flatpak-5", "kind": "flatpak", "entries": ["lutris"], "state": "running",
                             "percent": -1, "phase": "Installing runtime org.gnome.Platform"})
    snap("games")
    ev(grid, "category = ''")
    env.h.find(grid, "catalogSearch").setProperty("text", "spice")
    snap("search")
    env.h.find(grid, "catalogSearch").setProperty("text", "")
    ev(env.h.find(page, "logPopup"), "show('system-4', 'Steam')")
    snap("log")


if __name__ == "__main__":
    sys.exit(main())
