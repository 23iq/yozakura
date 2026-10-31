"""Copies of read-only sources (the Nix store) stay writable.

Runs the shell snippets that seed the config files and apply a colour
preset, as written in the QML, against a 0444 source: QSaveFile refuses to
save over a read-only config, and matugen / the next preset must be able to
overwrite colors.json.
"""
import os
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
failures = []


def snippet(rel, marker):
    """The single-quoted sh -c script on the line containing marker."""
    for line in (REPO / rel).read_text().splitlines():
        if marker in line:
            m = re.search(r"\"sh\", \"-c\", '([^']*)'", line)
            if m:
                return m.group(1)
    failures.append(f"{rel}: no sh -c snippet with {marker!r}")
    return "exit 1"


def writable(p):
    return bool(os.stat(p).st_mode & stat.S_IWUSR)


with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    src = tmp / "store"
    src.mkdir()
    for name in ("theme", "bar"):
        (src / f"{name}.json").write_text("{}")
        (src / f"{name}.json").chmod(0o444)

    # Config.qml: seed every domain
    dst = tmp / "config"
    script = snippet("config/Config.qml", "seed-config")
    subprocess.run(["sh", "-c", script, "seed-config", str(src), str(dst), "theme", "bar"], check=True,
                   capture_output=True)
    for name in ("theme", "bar"):
        if not writable(dst / f"{name}.json"):
            failures.append(f"Config.qml seed left {name}.json read-only")

    # An older read-only copy is repaired when the preset dir is read-only
    (dst / "theme.json").chmod(0o444)
    src.chmod(0o555)
    subprocess.run(["sh", "-c", snippet("config/Config.qml", "seed-config"), "seed-config", str(src), str(dst), "theme"],
                   check=True, capture_output=True)
    src.chmod(0o755)
    if not writable(dst / "theme.json"):
        failures.append("Config.qml seed did not repair an older read-only copy")

    # ConfigFile.qml: one missing domain
    one = tmp / "one.json"
    script = snippet("config/ConfigFile.qml", "seed-config")
    subprocess.run(["sh", "-c", script, "seed-config", str(src / "theme.json"), str(one)], check=True)
    if not writable(one):
        failures.append("ConfigFile.qml seed left the file read-only")

    # WallpaperColorPresets.qml: applied twice (the second over the first copy)
    colors = tmp / "colors.json"
    script = snippet("modules/widgets/dashboard/wallpapers/WallpaperColorPresets.qml", "color-preset")
    for _ in range(2):
        r = subprocess.run(["sh", "-c", script, "color-preset", str(src / "bar.json"), str(tmp / "none"), str(colors)])
        if r.returncode != 0:
            failures.append("colour preset apply failed over a previous copy")
    if not writable(colors):
        failures.append("colour preset left colors.json read-only")

for f in failures:
    print("FAIL:", f)
sys.exit(1 if failures else 0)
