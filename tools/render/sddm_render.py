#!/usr/bin/env python3
"""Render the SDDM theme for every lock screen style offscreen (private Xvfb,
never the live session; no root, nothing installed).

    tools/render/sddm_render.py [--out DIR] [--styles glass,paper] [--size 1920x1080]
                                [--greeter]

Runs scripts/sddm-sync.sh with your real config, palette and wallpaper into a
temporary data dir (never /var/lib), then loads assets/sddm/<app>/Main.qml
with stubbed SDDM context properties (tests/lib/sddm_env.py) and saves
<out>/<style>-<tone>.png for every tone the style has.
--greeter also runs the real `sddm-greeter-qt6 --test-mode` in its own Xvfb
for each style and saves <out>/<style>-greeter.png (needs ImageMagick
`import`).
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tests" / "lib"))
import headless  # noqa: E402
from sddm_env import THEME, read_conf  # noqa: E402

if "--greeter" not in sys.argv:
    headless.ensure(gl=True)

TONES = {"glass": ["dark", "light"], "paper": ["light", "dark"], "terminal": ["dark", "light"],
         "aurora": ["light", "dark"], "neon": ["dark"], "poster": ["dark", "light"]}


def sync(target: Path) -> dict:
    target.mkdir(parents=True, exist_ok=True)
    subprocess.run(["bash", str(REPO / "scripts" / "sddm-sync.sh"), "--target", str(target), "--force", "--quiet"],
                   check=True)
    return read_conf(target / "theme.conf")


def greeter_shot(theme_src: Path, conf: Path, style: str, out: Path, size: str) -> str:
    """Real greeter in test mode on a private Xvfb; returns '' or an error."""
    if not shutil.which("sddm-greeter-qt6") or not shutil.which("Xvfb") or not shutil.which("import"):
        return "sddm-greeter-qt6, Xvfb or import missing"
    with tempfile.TemporaryDirectory(prefix="sddm-greeter-") as tmp:
        theme = Path(tmp) / "theme"
        shutil.copytree(theme_src, theme)
        text = conf.read_text()
        own = {"style": f'"{style}"', "tone": f'"{TONES[style][0]}"'}
        text = "\n".join(f"{ln.split('=', 1)[0]}={own[ln.split('=', 1)[0]]}" if ln.split("=", 1)[0] in own else ln
                         for ln in text.splitlines())
        (theme / "theme.conf.user").write_text(text + "\n")
        r, w = os.pipe()
        xvfb = subprocess.Popen(["Xvfb", "-displayfd", str(w), "-screen", "0", f"{size}x24", "-nolisten", "tcp"],
                                pass_fds=(w,), stderr=subprocess.DEVNULL)
        os.close(w)
        display = ":" + os.read(r, 32).decode().strip()
        os.close(r)
        env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "QT_QPA_PLATFORM")}
        env.update(DISPLAY=display, QT_QPA_PLATFORM="xcb", XDG_SESSION_TYPE="x11")
        greeter = subprocess.Popen(["sddm-greeter-qt6", "--test-mode", "--theme", str(theme)], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            time.sleep(6)
            if greeter.poll() is not None:
                return "greeter exited: " + (greeter.stdout.read() or "")[-600:]
            subprocess.run(["import", "-window", "root", str(out)], env=env, check=True)
            return ""
        finally:
            greeter.kill()
            greeter.wait()
            xvfb.kill()
            xvfb.wait()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / ".cache" / "render" / "sddm"))
    ap.add_argument("--styles", default="")
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--greeter", action="store_true")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    wanted = [s for s in args.styles.split(",") if s] or list(TONES)
    w, h = (int(x) for x in args.size.split("x"))
    data = Path(tempfile.mkdtemp(prefix="sddm-render-"))
    try:
        base = sync(data)
        if args.greeter:
            for style in wanted:
                path = out / f"{style}-greeter.png"
                err = greeter_shot(THEME, data / "theme.conf", style, path, args.size)
                print(path if not err else f"{style}: real greeter failed: {err}")
            return 0
        from PySide6.QtTest import QTest
        from sddm_env import SddmEnv
        for style in wanted:
            for tone in TONES[style]:
                env = SddmEnv({**base, "style": style, "tone": tone}, size=(w, h))
                QTest.qWait(1500)
                path = out / f"{style}-{tone}.png"
                env.view.grabWindow().save(str(path))
                print(path)
                env.view.close()
                env.view.deleteLater()
    finally:
        shutil.rmtree(data, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
