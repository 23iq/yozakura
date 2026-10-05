#!/usr/bin/env python3
"""Render the settings window offscreen (private Xvfb, never the live desktop).

    tools/render/settings_render.py [--out DIR] [--mode dark|light|both]
                                    [--size 1180x780] [--set KEY=JSON ...] [CATEGORY ...]

Uses tests/lib/settings_env.py with your real config (~/.config/yozakura),
palette (~/.cache/yozakura/colors.json; light mode is generated with matugen
from the current wallpaper) and wallpapers. Scheme previews come from
`yozakura schemes` (the backend in this checkout is built on the fly).
`--set theme.surfaceEffect='"crt"'` overrides a config key for the render
(value parsed as JSON, plain strings allowed). Writes <out>/<category>-<mode>.png.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401  (wraps the Window as QQuickWindow)
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import DEFAULT_PALETTE, SettingsEnv  # noqa: E402

CACHE = Path.home() / ".cache" / "yozakura"


def camel(role: str) -> str:
    if role.startswith("on_"):
        role = "over_" + role[3:]
    head, *rest = role.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def wallpaper_state() -> dict:
    try:
        cfg = json.loads((CACHE / "wallpapers.json").read_text())
    except (OSError, ValueError):
        return {}
    root = cfg.get("wallPath", "").rstrip("/")
    exts = (".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".webm", ".mkv", ".mov")
    paths = sorted(str(p) for p in Path(root).rglob("*") if p.suffix.lower() in exts) if root else []
    thumbs = {}
    for p in paths:
        rel = Path(p).relative_to(root)
        t = CACHE / "thumbnails" / rel.parent / (rel.name + ".jpg")
        if t.exists():
            thumbs[p] = str(t)
    return {"dir": root, "scanDirs": [root], "paths": paths, "current": cfg.get("currentWall", ""),
            "thumbs": thumbs, "presets": []}


def color_source(state: dict) -> str:
    cur = state.get("current", "")
    if cur and Path(cur).suffix.lower() in (".mp4", ".webm", ".mkv", ".mov", ".gif"):
        return state.get("thumbs", {}).get(cur, "")
    return cur


def palette(mode: str, state: dict) -> dict:
    if mode == "dark":
        try:
            return json.loads((CACHE / "colors.json").read_text())
        except (OSError, ValueError):
            return DEFAULT_PALETTE
    src = color_source(state)
    if not src:
        return DEFAULT_PALETTE
    r = subprocess.run(["matugen", "image", src, "--dry-run", "-q", "-j", "hex", "-m", "light",
                        "--source-color-index", "0"], capture_output=True, text=True)
    if r.returncode != 0:
        return DEFAULT_PALETTE
    colors = json.loads(r.stdout)["colors"]
    out = dict(DEFAULT_PALETTE)
    out.update({camel(k): v["light"]["color"] for k, v in colors.items() if "light" in v})
    return out


def scheme_palettes(state: dict) -> dict:
    src = color_source(state)
    if not src:
        return {}
    binary = REPO / ".cache" / "render" / "yozakura"
    binary.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["go", "build", "-o", str(binary), "./cmd/yozakura"], cwd=REPO / "backend", check=True)
    r = subprocess.run([str(binary), "schemes", src], capture_output=True, text=True)
    return json.loads(r.stdout).get("schemes", {}) if r.returncode == 0 else {}


def overrides_from(sets: list[str]) -> dict:
    out: dict = {}
    for item in sets:
        key, _, raw = item.partition("=")
        try:
            value = json.loads(raw)
        except ValueError:
            value = raw
        node = out
        parts = key.split(".")
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = value
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("categories", nargs="*", default=["appearance", "bar", "wallpapers"])
    ap.add_argument("--out", default=str(REPO / ".cache" / "render"))
    ap.add_argument("--mode", default="both", choices=["dark", "light", "both"])
    ap.add_argument("--size", default="1180x780")
    ap.add_argument("--scroll", type=int, default=0, help="scroll the page by N pixels")
    ap.add_argument("--search", default="", help="type a query in the search field")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=JSON",
                    help="override a config key (domain.key[.sub]=value), repeatable")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    state = wallpaper_state()
    schemes = scheme_palettes(state)
    modes = ["dark", "light"] if args.mode == "both" else [args.mode]
    for mode in modes:
        extra = overrides_from(args.set)
        extra["theme"] = {**extra.get("theme", {}), "lightMode": mode == "light"}
        env = SettingsEnv(f"render-{mode}", palette=palette(mode, state), user_config=True,
                          overrides=extra, wallpaper=state)
        win = env.load(f"""
import QtQuick
import QtQuick.Window
import qs.modules.settings
import qs.modules.settings.store
Window {{
    width: {w}; height: {h}; visible: true; color: "black"
    SettingsShell {{ objectName: "shell"; anchors.fill: parent }}
}}""")
        shell = env.h.find(win, "shell")
        env.h.eval(shell, f"SchemePreviews.palettes = {json.dumps(schemes)}")
        env.h.eval(shell, "SchemePreviews.loadedSource = SchemePreviews.source")
        for cat in args.categories:
            env.h.eval(shell, f'select("{cat}")')
            if args.search:
                env.h.find(win, "settingsSearch").setProperty("text", args.search)
            QTest.qWait(900)
            if args.scroll:
                page = env.h.find(win, "settingsPage").property("item")
                page.setProperty("contentY", args.scroll)
                QTest.qWait(300)
            suffix = (f"-s{args.scroll}" if args.scroll else "") + ("-search" if args.search else "")
            path = out / f"{cat}{suffix}-{mode}.png"
            win.grabWindow().save(str(path))
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
