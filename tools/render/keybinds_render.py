#!/usr/bin/env python3
"""Render the keybind cheatsheet and editor offscreen (private Xvfb).

    tools/render/keybinds_render.py [--out DIR] [--mode dark|light|both]

Uses your real config, binds.json, palette and wallpaper (see
settings_render.py) and, when Hyprland runs, the compositor's own binds
(`hyprctl binds -j`, read-only) for conflict detection. Writes
<out>/cheatsheet[-search]-<mode>.png and
<out>/editor[-expanded|-record|-app|-advanced|-conflict]-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from PySide6.QtTest import QTest  # noqa: E402
from settings_env import USER_BINDS, SettingsEnv, default_binds  # noqa: E402


def hypr_binds() -> list:
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not shutil.which("hyprctl"):
        return []
    r = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True)
    try:
        return json.loads(r.stdout) if r.returncode == 0 else []
    except ValueError:
        return []


def with_cheatsheet_bind(binds: dict) -> dict:
    """The shell's repair pass adds new core binds; mirror it for the render."""
    app = next((k for k in binds if k not in ("custom", "disabled")), None)
    if app and "keybinds" not in binds[app].get("system", {}):
        binds[app].setdefault("system", {})["keybinds"] = {
            "modifiers": ["SUPER"], "key": "SLASH", "action": {"id": app + ".keybinds", "args": {}}}
    return binds


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    hypr = hypr_binds()
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        try:
            binds = json.loads(USER_BINDS.read_text())
        except (OSError, ValueError):
            binds = default_binds()
        env = SettingsEnv(f"keybinds-{mode}", palette=palette(mode, state), user_config=True,
                          overrides={"theme": {"lightMode": mode == "light"}}, wallpaper=state,
                          binds=with_cheatsheet_bind(binds))
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.keybinds
import qs.modules.settings
import qs.modules.settings.store
import qs.config
Window {{
    id: w
    width: 1600; height: 1000; visible: true; color: "black"
    property string page: "cheatsheet"
    function findItem(name, from) {{
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) {{ var f = findItem(name, kids[i]); if (f) return f; }}
        return null;
    }}
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    Item {{
        anchors.fill: parent
        visible: w.page === "cheatsheet"
        Rectangle {{ anchors.fill: parent; color: Colors.background; opacity: 0.72 }}
        CheatsheetPanel {{
            objectName: "panel"
            anchors.fill: parent
            anchors.margins: 48
        }}
    }}
    SettingsShell {{
        objectName: "shell"
        visible: w.page === "settings"
        width: 1180; height: 900
        anchors.centerIn: parent
    }}
}}""")
        h = env.h
        panel = h.find(win, "panel")
        shell = h.find(win, "shell")
        h.eval(panel, f"KeybindsStore.hyprBinds = {json.dumps(hypr)}")
        h.eval(panel, "KeybindsStore.revision++")

        def shot(name: str, wait: int = 700, win=win, mode=mode) -> None:
            QTest.qWait(wait)
            path = out / f"{name}-{mode}.png"
            win.grabWindow().save(str(path))
            print(path)

        shot("cheatsheet")
        h.eval(win, 'w.findItem("cheatsheetSearch").text = "work"')
        h.eval(panel, "selectedIndex = 1")
        shot("cheatsheet-search")

        h.eval(win, 'w.findItem("cheatsheetSearch").text = ""')
        h.eval(win, 'page = "settings"')
        h.eval(shell, 'select("input")')
        shot("editor", 900)
        h.eval(shell, 'KeybindsStore.expandedUid = "core:system.screenshot"')
        h.eval(shell, 'SettingsStore.navigate("input", "screenshots", "binds.screenshots")')
        shot("editor-expanded", 1200)
        recorder = h.eval(win, 'w.findItem("keyCapture")')
        if recorder is not None:
            h.eval(shell, 'KeybindsStore.expandedUid = "core:system.screenshot"')
            h.eval(recorder, "parent.start(); parent.chipMods = ['SUPER', 'SHIFT']")
            shot("editor-record", 900)
        # A new bind: "Open app" with the app list open, then Advanced.
        uid = h.eval(shell, 'KeybindsStore.addCustom("apps.launch")')
        h.eval(shell, f'KeybindsStore.expandedUid = "{uid}"')
        h.eval(shell, 'SettingsStore.navigate("input", "apps", "binds.apps")')
        QTest.qWait(400)
        pad = h.eval(win, f'w.findItem("keyCapture", w.findItem("keybindRow:{uid}"))')
        if pad is not None:
            h.eval(pad, "parent.cancel()")
        # bring the open app list into view
        h.eval(win, f"(function(){{ var p = w.findItem('keybindRow:{uid}'); "
                    "while (p && p.contentY === undefined) p = p.parent; if (p) p.contentY += 300 })()")
        shot("editor-app", 900)
        adv = h.eval(win, f'w.findItem("keybindAdvanced", w.findItem("keybindRow:{uid}"))')
        if adv is not None:
            h.eval(adv, "clicked()")
            shot("editor-advanced", 900)
        h.eval(shell, f'KeybindsStore.remove("{uid}")')
        # A conflict on purpose: a compositor bind on the first custom combo.
        rows = h.eval(shell, "JSON.stringify(KeybindsStore.rows.filter(r => r.kind === 'custom').slice(0, 1))")
        first = json.loads(rows or "[]")
        if first:
            k = first[0]["keys"][0]
            mask = sum({"SUPER": 64, "CTRL": 4, "ALT": 8, "SHIFT": 1}.get(m.upper(), 0) for m in k["modifiers"])
            demo = hypr + [{"modmask": mask, "key": k["key"], "has_description": True,
                            "description": "Demo: native compositor bind", "submap": ""}]
            h.eval(shell, f"KeybindsStore.hyprBinds = {json.dumps(demo)}")
            h.eval(shell, f'KeybindsStore.expandedUid = "{first[0]["uid"]}"')
            h.eval(shell, f'SettingsStore.navigate("input", "{first[0]["group"]}", "binds.{first[0]["group"]}")')
            shot("editor-conflict", 1200)
    return 0


if __name__ == "__main__":
    sys.exit(main())
