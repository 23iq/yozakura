#!/usr/bin/env python3
"""Render the visual-language sweep offscreen (private Xvfb, never the live desktop).

    tools/render/render_sweep.py [--out DIR] [--mode dark|light] [--only kit,settings,...]
                                 [LANGUAGE ...]

Runs the kit sheets, the settings window, the dashboard (and its tool tabs),
the bar matrix and the OSDs once per visual language (every language of VisualLanguage.js by
default) into <out>/<sheet>/ (default .cache/render/sweep/), so a change to
the kit tokens can be checked across every language in one go
(`make render-sweep`). Each sheet is its own process (a fresh QML engine and
Xvfb); a sheet that writes no render fails, the others still run.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tests" / "lib"))
from languages import LANGUAGES  # noqa: E402


def sheets(langs: list[str], mode: str) -> dict[str, list[str]]:
    """sheet -> tool argv (without --out); every one renders each language."""
    joined = ",".join(langs)
    return {
        "kit": ["kit_render.py", "--mode", mode, *langs],
        "kit-bold": ["kit_render.py", "--mode", mode, "--sheet", "KitGalleryBold", *langs],
        "settings": ["settings_render.py", "--mode", mode, "--languages", joined, "appearance", "bar"],
        "dashboard": ["dashboard_render.py", "--mode", mode, *langs],
        "bar-matrix": ["panels_render.py", "--bar-matrix", "--mode", mode],
        "osd": ["osd_render.py", "--mode", mode, "--languages", joined],
        "dashtabs": ["dashtabs_render.py", "--mode", mode, *langs],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "sweep"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    ap.add_argument("--only", default="", help="comma separated sheets (kit, kit-bold, settings, dashboard, bar-matrix, osd, dashtabs)")
    args = ap.parse_args()
    unknown = set(args.languages) - set(LANGUAGES)
    if unknown:
        ap.error(f"unknown language(s): {', '.join(sorted(unknown))} (known: {', '.join(LANGUAGES)})")
    plan = sheets(args.languages, args.mode)
    wanted = [s for s in args.only.split(",") if s] or list(plan)
    failed = []
    for name in wanted:
        if name not in plan:
            ap.error(f"unknown sheet {name!r}")
        out = Path(args.out) / name
        out.mkdir(parents=True, exist_ok=True)
        argv = [sys.executable, str(HERE / plan[name][0]), *plan[name][1:], "--out", str(out)]
        print(f"== {name} -> {out}", flush=True)
        start = time.time()
        code = subprocess.run(argv, cwd=REPO).returncode
        written = [p for p in out.glob("*.png") if p.stat().st_mtime >= start - 1]
        if not written:
            failed.append(name)
        elif code != 0:
            # Some tools crash in Qt's teardown after saving (exit 139 on main
            # too): the renders are there, say so instead of failing the sweep.
            print(f"   {name}: {len(written)} render(s) written, tool exited with {code} afterwards", flush=True)
    if failed:
        print(f"render-sweep: failed: {', '.join(failed)}", file=sys.stderr)
        return 1
    print(f"render-sweep: {len(wanted)} sheet(s) in {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
