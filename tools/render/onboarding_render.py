#!/usr/bin/env python3
"""Render every onboarding wizard step offscreen (private Xvfb).

    tools/render/onboarding_render.py [--out DIR] [--mode dark|light|both]
                                      [--size 1920x1080,1280x720] [--lang en]

Uses your real config (read-only), palette, wallpaper and binds.json (see
settings_render.py), the real environment probe (installed terminals,
agents, whisper) and the real prompt previews (terminal_render.py); the
monitors are a sample pair (one 60 Hz panel that can do 165 Hz). Nothing is
applied. Writes <out>/<WxH>/<NN>-<step>-<mode>.png plus a few in-progress
states (wallpaper tab, preset picked, monitor details, tour half done,
voice setup running).
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
from terminal_env import PRESETS, STATUS, sample_previews  # noqa: E402

OUTPUTS = [
    {"id": "AOC-Q27-1", "name": "DP-1", "make": "AOC", "model": "Q27G2", "enabled": True,
     "width": 2560, "height": 1440, "refresh": 60, "x": 0, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 597, "physical_height_mm": 336,
     "modes": [{"width": w, "height": h, "refresh": r} for (w, h, rates) in
               [(2560, 1440, [165, 144, 120, 60]), (1920, 1080, [144, 60])] for r in rates]},
    {"id": "BOE-0x0bca-2", "name": "eDP-1", "make": "BOE", "model": "NE135FBM", "enabled": True,
     "width": 2256, "height": 1504, "refresh": 60, "x": 2560, "y": 0, "scale": 1, "transform": 0, "vrr": False,
     "physical_width_mm": 285, "physical_height_mm": 190,
     "modes": [{"width": 2256, "height": 1504, "refresh": 60}]},
]


def prompt_previews(pal: dict) -> tuple[list, dict]:
    try:
        from terminal_render import previews
        return previews(pal)
    except Exception as e:  # noqa: BLE001  (no Go toolchain: hand-made samples)
        print("prompt previews: using samples:", e, file=sys.stderr)
        return PRESETS, {"starship:" + k: v for k, v in sample_previews().items()}


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
    ap.add_argument("--size", default="1920x1080,1280x720")
    ap.add_argument("--lang", default="en")
    args = ap.parse_args()
    sizes = [tuple(int(x) for x in sz.split("x")) for sz in args.size.split(",")]
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    detected = probe()
    try:
        binds = json.loads(USER_BINDS.read_text())
    except (OSError, ValueError):
        binds = default_binds()
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        pal = palette(mode, state)
        presets, previews = prompt_previews(pal)
        env = OnboardingEnv(f"onboarding-{mode}", lang=args.lang, palette=pal, user_config=True,
                            overrides={"theme": {"lightMode": mode == "light"}}, wallpaper=state, binds=binds,
                            outputs=OUTPUTS)
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.onboarding
import qs.modules.services
Window {{
    id: w
    width: {sizes[0][0]}; height: {sizes[0][1]}; visible: true; color: "black"
    readonly property var wizard: flow.wizard
    Image {{ anchors.fill: parent; source: {json.dumps(("file://" + wall) if wall else "")}; fillMode: Image.PreserveAspectCrop }}
    Rectangle {{ anchors.fill: parent; color: Colors.background; opacity: 0.62; visible: !OnboardingService.peek }}
    OnboardingFlow {{ id: flow; objectName: "flow"; anchors.fill: parent; visible: !OnboardingService.peek }}
    PeekPill {{ shown: true; visible: OnboardingService.peek; anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 48 }}
}}""")
        h = env.h
        h.eval(win, f"wizard.applyDetect({json.dumps(detected)})")
        h.eval(win, f"TerminalLookService.presets = {json.dumps(presets)}; TerminalLookService.status = {json.dumps(STATUS)};"
                    f" TerminalLookService.previews = {json.dumps(previews)}")

        for (w, h_) in sizes:
            out = Path(args.out) / f"{w}x{h_}"
            out.mkdir(parents=True, exist_ok=True)
            win.setWidth(w)
            win.setHeight(h_)

            def shot(name: str, wait: int = 900, win=win, mode=mode, out=out) -> None:
                QTest.qWait(wait)
                path = out / f"{name}-{mode}.png"
                win.grabWindow().save(str(path))
                print(path)

            count = h.eval(win, "wizard.count")
            for i in range(count):
                h.eval(win, f"wizard.go({i})")
                sid = h.eval(win, "wizard.step.id")
                shot(f"{i + 1:02d}-{sid}", 2600 if i == 0 else 1100)
                if sid == "displays":
                    item = h.find(win, "stepLoader").property("item")
                    h.eval(item, "(function f(it) { if (it.objectName === 'moreButton') { it.clicked(); return true }"
                                 " for (const c of it.children) if (f(c)) return true; return false })(this)")
                    shot(f"{i + 1:02d}-{sid}-more", 600)
                elif sid == "look":
                    names = json.loads(h.eval(win, "JSON.stringify(PresetsService.presets.map(p => p.name))"))
                    if names:
                        pick = "Neon Tokyo" if "Neon Tokyo" in names else names[0]
                        h.eval(win, f"wizard.choosePreset({json.dumps(pick)})")
                        shot(f"{i + 1:02d}-{sid}-picked", 500)
                    h.eval(win, 'wizard.remember("lookTab", "wallpaper")')
                    shot(f"{i + 1:02d}-{sid}-wallpaper", 900)
                    h.eval(win, 'wizard.remember("lookTab", "style")')
                elif sid == "ai":
                    h.eval(win, "wizard.voiceStatus = 'running'; wizard.voiceProgress = 0.42;"
                                " wizard.voiceLine = 'Building (CUDA, 16 jobs; this takes a few minutes)'")
                    shot(f"{i + 1:02d}-{sid}-voice-setup", 700)
                    h.eval(win, "wizard.voiceStatus = ''")
                elif sid == "keybinds":
                    h.eval(win, 'GlobalShortcuts.run("keybinds")')
                    h.eval(win, 'OnboardingService.peek = false')
                    shot(f"{i + 1:02d}-{sid}-progress", 900)
                    h.eval(win, 'wizard.markTask("launcher", "skipped"); GlobalShortcuts.run("assistant");'
                                ' GlobalShortcuts.run("overview"); OnboardingService.peek = false')
                    shot(f"{i + 1:02d}-{sid}-complete", 900)
                    h.eval(win, "wizard.resetTour()")
            # peek: the wizard collapses to the pill over the bare desktop
            h.eval(win, "wizard.go(2); OnboardingService.peek = true")
            shot("peek", 1400)
            h.eval(win, "OnboardingService.peek = false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
