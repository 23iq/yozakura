"""A private preset world for the settings preset studio (tests, renders).

Builds the backend of this checkout once (.cache/preset-studio/<app>) and
runs `<app> preset ...` with HOME/XDG_* pointed at a temp root, so the
studio's real CLI calls (list, apply, try, mix, edit, delete...) never touch
the user's config. `bridge()` returns a QObject the QML store can call
synchronously:

    PresetStudio.runner = function (args, cb) {
        var r = presetBridge.run(args); cb(r[0], r[1], r[2]);
    }

`calls` records every command for assertions.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

from PySide6.QtCore import QObject, Slot
from qmlharness import REPO

APP_ID = "yozakura"
_BINARY = REPO / ".cache" / "preset-studio" / APP_ID


def build_backend() -> Path:
    _BINARY.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["go", "build", "-o", str(_BINARY), "./cmd/" + APP_ID], cwd=REPO / "backend", check=True)
    return _BINARY


class PresetSandbox:
    def __init__(self, root: Path, *, user_presets: Path | None = None, config: Path | None = None,
                 wallpapers: dict | None = None):
        self.root = Path(root)
        self.binary = build_backend()
        self.env = dict(os.environ)
        home = self.root / "home"
        self.dirs = {
            "XDG_CONFIG_HOME": home / ".config",
            "XDG_STATE_HOME": home / ".local" / "state",
            "XDG_CACHE_HOME": home / ".cache",
            "XDG_DATA_HOME": home / ".local" / "share",
        }
        for k, d in self.dirs.items():
            d.mkdir(parents=True, exist_ok=True)
            self.env[k] = str(d)
        self.env["HOME"] = str(home)
        self.env[APP_ID.upper() + "_SHELL"] = str(REPO)
        self.env[APP_ID.upper() + "_MODS_DISABLED"] = "1"
        self.config_dir = self.dirs["XDG_CONFIG_HOME"] / APP_ID
        self.presets_dir = self.config_dir / "presets"
        self.presets_dir.mkdir(parents=True, exist_ok=True)
        if user_presets and user_presets.is_dir():
            for p in user_presets.iterdir():
                if p.is_dir() and not p.name.startswith("."):
                    shutil.copytree(p, self.presets_dir / p.name, dirs_exist_ok=True)
            marker = user_presets / "active_preset"
            if marker.is_file():
                shutil.copy(marker, self.presets_dir / "active_preset")
        if config and config.is_dir():
            shutil.copytree(config, self.config_dir / "config", dirs_exist_ok=True)
        cache = self.dirs["XDG_CACHE_HOME"] / APP_ID
        cache.mkdir(parents=True, exist_ok=True)
        (cache / "wallpapers.json").write_text(json.dumps(wallpapers or {"matugenScheme": "scheme-tonal-spot"}))
        self.calls: list[list[str]] = []

    def run(self, args: list[str]) -> tuple[int, str, str]:
        r = subprocess.run([str(self.binary), "preset", *args], env=self.env, capture_output=True, text=True)
        return r.returncode, r.stdout, r.stderr

    def json(self, *args: str):
        code, out, err = self.run(list(args))
        assert code == 0, err
        return json.loads(out)

    def bridge(self) -> QObject:
        return _Bridge(self)


class _Bridge(QObject):
    def __init__(self, sandbox: PresetSandbox):
        super().__init__()
        self.sandbox = sandbox

    @Slot("QVariantList", result="QVariantList")
    def run(self, args):
        args = [str(a) for a in args]
        self.sandbox.calls.append(args)
        code, out, err = self.sandbox.run(args)
        return [code == 0, out, err]
