#!/usr/bin/env python3
"""Render the polkit password dialog (modules/polkit/PolkitDialog.qml)
offscreen (private Xvfb, never the desktop) over a dimmed wallpaper.

    tools/render/polkit_render.py [--out DIR] [--mode dark|light] [--size 1280x800]
                                  [--wallpaper FILE] [LANGUAGE ...]

States: `prompt` (password asked, a few masked characters typed), `error`
(after a wrong password), `identities` (two identities: the picker).
Writes <out>/polkit-<state>-<language>.png, every visual language by
default. The flows are the stubs of tests/lib/polkit_env.py with neutral
sample data; palette and wallpaper as settings_render.py (the repo's first
example wallpaper when you have none).
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

from kit_env import LANGUAGES  # noqa: E402
from polkit_env import PolkitEnv  # noqa: E402
from PySide6.QtCore import QEvent, Qt  # noqa: E402
from PySide6.QtGui import QGuiApplication, QKeyEvent  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_render import palette, wallpaper_state  # noqa: E402

MESSAGE = "Authentication is required to install software"
ACTION = "org.freedesktop.policykit.exec"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "polkit"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--size", default="1280x800")
    ap.add_argument("--wallpaper", default="")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = args.wallpaper or state.get("current", "") or str(REPO / "assets/wallpapers_example/wallpaper-01.png")
    for lang in args.languages:
        render(lang, args.mode, state, wall, out, w, h)
    return 0


def type_text(win, text: str) -> None:
    for ch in text:
        QGuiApplication.sendEvent(win, QKeyEvent(QEvent.KeyPress, Qt.Key_A, Qt.NoModifier, ch))
        QGuiApplication.sendEvent(win, QKeyEvent(QEvent.KeyRelease, Qt.Key_A, Qt.NoModifier, ch))


def render(lang: str, mode: str, state: dict, wall: str, out: Path, w: int, h: int) -> None:
    theme = {"language": lang, "lightMode": mode == "light"}
    env = PolkitEnv(f"polkit-render-{lang}", palette=palette(mode, state), overrides={"theme": theme})
    win = env.load(f"""
import QtQuick
import QtQuick.Window
import Quickshell.Services.Polkit
import qs.modules.components.kit
import qs.modules.polkit
Window {{
    id: win
    width: {w}; height: {h}; visible: true; color: "black"
    property alias dialog: dialog
    Image {{ anchors.fill: parent; source: {json.dumps("file://" + wall)}; fillMode: Image.PreserveAspectCrop }}
    Scrim {{ shown: true; strength: 0.6 }}
    Component {{ id: flowComp; AuthFlow {{}} }}
    QtObject {{ id: me; property int id: 1000; property string string: "user"; property string displayName: "user"; property bool isGroup: false }}
    QtObject {{ id: admin; property int id: 1001; property string string: "admin"; property string displayName: "Administrator"; property bool isGroup: false }}
    function makeFlow(two) {{
        return flowComp.createObject(win, {{ message: {json.dumps(MESSAGE)}, actionId: {json.dumps(ACTION)},
            identities: two ? [me, admin] : [me], selectedIdentity: me }});
    }}
    PolkitDialog {{ id: dialog; objectName: "dialog"; anchors.centerIn: parent; shown: true }}
}}""")
    ev = env.h.eval
    win.requestActivate()
    QTest.qWait(300)
    dialog = env.h.find(win, "dialog")

    def snap(name: str) -> None:
        QTest.qWait(700)
        path = out / f"polkit-{name}-{lang}{'' if mode == 'dark' else '-light'}.png"
        win.grabWindow().save(str(path))
        print(path)

    flow = ev(win, "makeFlow(false)")
    dialog.setProperty("flow", flow)
    ev(flow, 'request("Password: ", false)')
    QTest.qWait(200)
    type_text(win, "sample")
    snap("prompt")

    ev(dialog, "submit()")
    ev(flow, "completed(false)")
    ev(flow, 'request("Password: ", false)')
    snap("error")

    two = ev(win, "makeFlow(true)")
    dialog.setProperty("flow", two)
    ev(two, 'request("Password: ", false)')
    snap("identities")


if __name__ == "__main__":
    sys.exit(main())
