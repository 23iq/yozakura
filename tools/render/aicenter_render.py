#!/usr/bin/env python3
"""Render the AI center offscreen in every visual language (never the live desktop).

    tools/render/aicenter_render.py [--out DIR] [--mode dark|light] [LANGUAGE ...]

Runs tests/ai-center-ui.test.py (real AI center components, stubbed
services, its own offscreen platform) once per visual language (all five by
default): chat, agent wide mode, quick ask, the selection popup (+ result),
the session drawer and the AI settings editors. Writes
<out>/<scene>-<language>.png (default .cache/render/aicenter/).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
from languages import LANGUAGES  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("languages", nargs="*", default=LANGUAGES)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "aicenter"))
    ap.add_argument("--mode", default="dark", choices=["dark", "light"])
    args = ap.parse_args()
    unknown = set(args.languages) - set(LANGUAGES)
    if unknown:
        ap.error(f"unknown language(s): {', '.join(sorted(unknown))} (known: {', '.join(LANGUAGES)})")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "AI_CENTER_RENDER": str(out), "AI_CENTER_LANGUAGES": ",".join(args.languages),
           "AI_CENTER_MODE": args.mode}
    rc = subprocess.run([sys.executable, str(REPO / "tests" / "ai-center-ui.test.py")], env=env).returncode
    for png in sorted(out.glob("*.png")):
        print(png)
    return rc


if __name__ == "__main__":
    sys.exit(main())
