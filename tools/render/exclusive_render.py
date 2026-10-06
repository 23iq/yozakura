#!/usr/bin/env python3
"""Render Settings > System > Exclusive mode offscreen (private Xvfb, never
the desktop): off, confirmation, active and restored states.

    tools/render/exclusive_render.py [--out DIR] [--mode dark|light|both] [--size 1180x1000]

Writes <out>/<view>-<mode>.png. Palette and wallpaper come from your setup
like settings_render.py; the backend is scripted (tests/lib/exclusive_env.py).
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

from exclusive_env import STATUS_OFF, STATUS_ON, ExclusiveEnv  # noqa: E402
from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "exclusive"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1180x1000")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    for mode in (["dark", "light"] if args.mode == "both" else [args.mode]):
        render(mode, state, out, w, h)
    return 0


def render(mode: str, state: dict, out: Path, w: int, h: int) -> None:
    env = ExclusiveEnv(f"exclusive-{mode}", palette=palette(mode, state), user_config=True, wallpaper=state,
                       overrides={"theme": {"lightMode": mode == "light"}})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.services
Window {{
    id: w
    width: {w}; height: {h}; visible: true; color: "black"
    // Repeater delegates have no QObject parent: search the visual tree.
    function findItem(name, from) {{
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
    ev = env.h.eval
    shell = env.h.find(win, "shell")

    def snap(name: str, wait: int = 900) -> None:
        QTest.qWait(wait)
        ev(env.h.find(win, "settingsPage").property("item"), 'reveal("exclusive", "system.exclusive")')
        QTest.mouseMove(win, QPoint(60, h - 30))
        QTest.qWait(wait)
        path = out / f"{name}-{mode}.png"
        win.grabWindow().save(str(path))
        print(path)

    def card(obj: str, expr: str):
        return ev(win, f'findItem("{obj}").{expr}')

    ev(shell, 'select("system")')
    QTest.qWait(600)
    ev(env.h.find(win, "settingsPage").property("item"), 'reveal("exclusive", "system.exclusive")')
    snap("off", 2500)
    card("exclusiveEnable", "clicked()")
    snap("confirm")
    card("exclusiveCancel", "clicked()")
    ev(win, "BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.status': %s})" % json.dumps(STATUS_ON))
    ev(win, "ExclusiveService.refresh()")
    snap("active")
    card("exclusiveRestore", "clicked()")
    snap("restore-confirm")
    ev(win, "BackendService.replies = Object.assign({}, BackendService.replies, {'exclusive.restore': %s, 'exclusive.status': %s})"
       % (json.dumps({**STATUS_OFF, "replaced": "/home/me/.local/share/yozakura/backups/20261006-120000/replaced-20261006-131500"}), json.dumps(STATUS_OFF)))
    card("exclusiveConfirmButton", "clicked()")
    snap("restored")


if __name__ == "__main__":
    sys.exit(main())
