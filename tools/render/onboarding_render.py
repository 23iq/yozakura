#!/usr/bin/env python3
"""Render every onboarding wizard step offscreen (private Xvfb).

    tools/render/onboarding_render.py [--out DIR] [--mode dark|light|both]
                                      [--size 1920x1080,1280x720] [--lang en]
                                      [--language ink,glass,tiles] [--palette '#3f8f4f']
                                      [--steps welcome,look]

Uses your real config (read-only), palette, wallpaper and binds.json (see
settings_render.py), the real environment probe (installed terminals,
the real extras catalog (a sample install state: Firefox, Claude Code and
Ollama installed) and the real prompt previews (terminal_render.py); the
monitors are a sample pair (one 60 Hz panel that can do 165 Hz). Nothing is
applied or installed. `--language` renders each visual language (default:
your config's), `--palette` swaps your palette for one generated from a seed
colour (matugen), `--steps` keeps only those step ids (peek always).
Writes <out>/<WxH>/<NN>-<step>-<mode>[-<language>].png plus a few
in-progress states (wallpaper tab, preset picked, monitor details, apps
installing, a model pull, tour half done, summary with installs running and
the exclusive toggle on, summary when done).
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tests" / "lib"))
from settings_render import DEFAULT_PALETTE, REPO, camel, palette, wallpaper_state  # noqa: E402  (also enters the private Xvfb)

from PySide6.QtTest import QTest  # noqa: E402
from onboarding_env import OnboardingEnv  # noqa: E402
from settings_env import USER_BINDS, default_binds  # noqa: E402
from terminal_env import PRESETS, STATUS, sample_previews  # noqa: E402
from extras_env import PLATFORM, full_catalog  # noqa: E402
from exclusive_env import PLAN, STATUS_OFF  # noqa: E402

INSTALLED = {"firefox", "claude-code", "ollama", "fish", "kitty"}


def extras_replies() -> dict:
    cat = full_catalog()
    status = {e["id"]: {"id": e["id"], "state": "installed" if e["id"] in INSTALLED else "missing"}
              for e in cat["entries"]}
    return {"extras.catalog": {**cat, "platform": PLATFORM}, "extras.status": status,
            "extras.ollamaPull": {"jobs": [{"id": "pull-1", "kind": "ollama", "entries": []}]},
            "exclusive.status": STATUS_OFF, "exclusive.plan": PLAN,
            "providers.ollama.probe": {"reachable": True, "models": [{"id": "llama3.2:latest"}]}}

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


def seed_palette(seed: str, mode: str) -> dict:
    """A full palette from one seed colour (a non-default palette check)."""
    r = subprocess.run(["matugen", "color", "hex", seed, "--dry-run", "-q", "-j", "hex", "-m", mode],
                       capture_output=True, text=True, check=True)
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v[mode]["color"] for k, v in json.loads(r.stdout)["colors"].items() if mode in v})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "onboarding"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1920x1080,1280x720")
    ap.add_argument("--lang", default="en")
    ap.add_argument("--language", default="", help="comma list of visual languages (ink,glass,tiles)")
    ap.add_argument("--palette", default="", help="seed colour of a generated palette, e.g. '#3f8f4f'")
    ap.add_argument("--steps", default="", help="comma list of step ids to render")
    args = ap.parse_args()
    only = set(filter(None, args.steps.split(",")))
    sizes = [tuple(int(x) for x in sz.split("x")) for sz in args.size.split(",")]
    state = wallpaper_state()
    wall = state.get("thumbs", {}).get(state.get("current", ""), state.get("current", ""))
    detected = probe()
    try:
        binds = json.loads(USER_BINDS.read_text())
    except (OSError, ValueError):
        binds = default_binds()
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    languages = [x for x in args.language.split(",") if x] or [""]
    for mode, language in [(m, lg) for lg in languages for m in modes]:
        pal = seed_palette(args.palette, mode) if args.palette else palette(mode, state)
        presets, previews = prompt_previews(pal)
        theme = {"lightMode": mode == "light", **({"language": language} if language else {})}
        suffix = f"{mode}-{language}" if language else mode
        env = OnboardingEnv(f"onboarding-{suffix}", lang=args.lang, palette=pal, user_config=True,
                            overrides={"theme": theme}, wallpaper=state, binds=binds,
                            outputs=OUTPUTS, replies=extras_replies())
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

            def shot(name: str, wait: int = 900, win=win, suffix=suffix, out=out) -> None:
                QTest.qWait(wait)
                path = out / f"{name}-{suffix}.png"
                win.grabWindow().save(str(path))
                print(path)

            # every size starts from a fresh install state (apps preselected again)
            h.eval(win, "ExtrasService.jobs = ({}); ExtrasService.progress = ({}); ExtrasService.pulls = ({});"
                        " (function () { const c = Object.assign({}, wizard.choices); delete c.apps; delete c.installs;"
                        " wizard.choices = c })()")
            count = h.eval(win, "wizard.count")
            for i in range(count):
                h.eval(win, f"wizard.go({i})")
                sid = h.eval(win, "wizard.step.id")
                if only and sid not in only:
                    continue
                if sid == "apps":  # the catalog and its status first: the preselection shows
                    for _ in range(50):
                        if h.eval(win, "!!ExtrasService.catalog && Object.keys(ExtrasService.status).length > 0"):
                            break
                        QTest.qWait(100)
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
                elif sid == "apps":
                    h.eval(win, 'ExtrasService.install(["vesktop", "steam", "spotify"], true);'
                                ' BackendService.emit("extras.progress", {job: "r1", kind: "system",'
                                ' entries: ["vesktop"], state: "running", percent: 46, phase: "Downloading vesktop"});'
                                ' BackendService.emit("extras.progress", {job: "r2", kind: "flatpak",'
                                ' entries: ["steam", "spotify"], state: "queued", percent: 0, phase: ""})')
                    shot(f"{i + 1:02d}-{sid}-installing", 700)
                elif sid == "ai":
                    h.eval(win, 'ExtrasService.ollamaPull("qwen2.5-coder"); BackendService.emit("extras.progress",'
                                ' {job: "pull-1", kind: "ollama", entries: [], state: "running", percent: 38, phase: ""})')
                    h.eval(h.find(win, "stepLoader").property("item"),
                           '(function f(it) { if (it.objectName === "catalogFlick") { it.contentY = it.contentHeight - it.height; return true }'
                           ' for (const c of it.children) if (f(c)) return true; return false })(this)')
                    shot(f"{i + 1:02d}-{sid}-pulling", 700)
                elif sid == "finish":
                    h.eval(win, 'wizard.remember("exclusive", true)')
                    shot(f"{i + 1:02d}-{sid}-installing", 700)
                    h.eval(win, 'wizard.remember("exclusive", false);'
                                ' ["r1", "r2", "pull-1"].forEach(j => BackendService.emit("extras.progress", Object.assign({},'
                                ' ExtrasService.jobs[j], {state: "done", percent: 100})))')
                    shot(f"{i + 1:02d}-{sid}-done", 700)
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
