#!/usr/bin/env python3
"""Render every onboarding wizard step offscreen (private Xvfb).

    tools/render/onboarding_render.py [--out DIR] [--mode dark|light|both]
                                      [--size 1600x1000] [--lang en]

Uses your real config (read-only), palette, wallpaper and binds.json (see
settings_render.py) and the real environment probe (installed terminals,
agents, whisper); nothing is applied. Writes <out>/<NN>-<step>-<mode>.png
plus a few in-progress states (preset picked, tour half done, voice setup
running).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tests" / "lib"))
from settings_render import REPO, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from PySide6.QtTest import QTest  # noqa: E402
from onboarding_env import OnboardingEnv  # noqa: E402
from settings_env import USER_BINDS, default_binds  # noqa: E402


def probe() -> str:
    lib = REPO / "tests" / "lib" / "qmljs.cjs"
    model = REPO / "modules" / "onboarding" / "OnboardingModel.js"
    data = Path.home() / ".local" / "share" / "yozakura"
    script = subprocess.run(["node", "-e", "const q=require(process.argv[1]);"
                             "console.log(q.loadLibrary(process.argv[2]).detectScript(process.argv[3]))",
                             str(lib), str(model), str(data)], capture_output=True, text=True, check=True).stdout
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True).stdout


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "onboarding"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1600x1000")
    ap.add_argument("--lang", default="en")
    args = ap.parse_args()
    w, h_ = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    detected = probe()
    try:
        binds = json.loads(USER_BINDS.read_text())
    except (OSError, ValueError):
        binds = default_binds()
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        env = OnboardingEnv(f"onboarding-{mode}", lang=args.lang, palette=palette(mode, state), user_config=True,
                            overrides={"theme": {"lightMode": mode == "light"}}, wallpaper=state, binds=binds)
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.onboarding
import qs.modules.services
Window {{
    id: w
    width: {w}; height: {h_}; visible: true; color: "black"
    readonly property var wizard: flow.wizard
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    Rectangle {{ anchors.fill: parent; color: Colors.background; opacity: 0.62; visible: !OnboardingService.peek }}
    OnboardingFlow {{ id: flow; objectName: "flow"; anchors.fill: parent; visible: !OnboardingService.peek }}
    PeekPill {{ shown: true; visible: OnboardingService.peek; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 48 }}
}}""")
        h = env.h
        h.eval(win, f"wizard.applyDetect({json.dumps(detected)})")

        def shot(name: str, wait: int = 900, win=win, mode=mode) -> None:
            QTest.qWait(wait)
            path = out / f"{name}-{mode}.png"
            win.grabWindow().save(str(path))
            print(path)

        count = h.eval(win, "wizard.count")
        for i in range(count):
            h.eval(win, f"wizard.go({i})")
            sid = h.eval(win, "wizard.step.id")
            shot(f"{i + 1:02d}-{sid}", 2600 if i == 0 else 1100)
            if sid == "preset":
                names = json.loads(h.eval(win, "JSON.stringify(PresetsService.presets.map(p => p.name))"))
                if names:
                    pick = "Neon Tokyo" if "Neon Tokyo" in names else names[0]
                    h.eval(win, f"wizard.choosePreset({json.dumps(pick)})")
                    shot(f"{i + 1:02d}-{sid}-picked", 500)
            elif sid == "ai":
                h.eval(win, "wizard.voiceStatus = 'running'; wizard.voiceProgress = 0.42;"
                            " wizard.voiceLine = 'Building (CUDA, 16 jobs; this takes a few minutes)'")
                shot(f"{i + 1:02d}-{sid}-voice-setup", 700)
                h.eval(win, "wizard.voiceStatus = ''")
            elif sid == "specials":
                editor = h.find(win, "specialsEditor")
                if editor is not None:
                    h.eval(editor, 'addFromTemplate("chat"); addFromTemplate("custom")')
                    shot(f"{i + 1:02d}-{sid}-added", 700)
                    h.eval(editor, 'write([])')
            elif sid == "keybinds":
                h.eval(win, 'GlobalShortcuts.run("keybinds")')
                h.eval(win, 'OnboardingService.peek = false')
                shot(f"{i + 1:02d}-{sid}-progress", 900)
                h.eval(win, 'wizard.markTask("launcher", "skipped"); GlobalShortcuts.run("assistant");'
                            ' GlobalShortcuts.run("overview"); OnboardingService.peek = false')
                shot(f"{i + 1:02d}-{sid}-complete", 900)
        # peek: the wizard collapses to the pill over the bare desktop
        h.eval(win, "wizard.go(2); OnboardingService.peek = true")
        shot("peek", 1400)
        h.eval(win, "OnboardingService.peek = false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
