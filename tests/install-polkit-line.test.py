"""install.sh's polkit_autostart writes the Hyprland polkit line with the
launcher path as one sh word (quoted only when sh would split or expand it),
`#` doubled in hyprlang and backslash / `"` escaped in the Lua string: the same
text backend/cmd/yozakura/hypr_polkit.go writes (TestRepairPolkitLineCRLFAndQuoting
checks the Go side against these literals)."""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
src = (REPO / "install.sh").read_text()
fn = re.search(r"^polkit_autostart\(\) \{\n.*?^\}\n", src, re.M | re.S)
assert fn, "install.sh has no polkit_autostart()"

SCRIPT = fn.group(0) + """
APP_ID=yozakura POLKIT_FALLBACK=polkit-fallback
hypr_entry() { echo "$ENTRY"; }
polkit_autostart
"""

CASES = {
    ("/opt/bin", "hyprland.conf"): "exec-once = /opt/bin/yozakura polkit-fallback # yozakura: polkit",
    ("/opt/bin", "hyprland.lua"):
        'hl.on("hyprland.start", function() hl.exec_cmd("/opt/bin/yozakura polkit-fallback") end) -- yozakura: polkit',
    ("/home/a b/#1", "hyprland.conf"): "exec-once = '/home/a b/##1/yozakura' polkit-fallback # yozakura: polkit",
    ('/home/a "b"', "hyprland.lua"):
        r"""hl.on("hyprland.start", function() hl.exec_cmd("'/home/a \"b\"/yozakura' polkit-fallback") end) -- yozakura: polkit""",
    ("/home/o'neil", "hyprland.conf"): r"exec-once = '/home/o'\''neil/yozakura' polkit-fallback # yozakura: polkit",
    (r"/x\y", "hyprland.lua"):
        r"""hl.on("hyprland.start", function() hl.exec_cmd("'/x\\y/yozakura' polkit-fallback") end) -- yozakura: polkit""",
}

failures = []
for (bin_dir, entry), want in CASES.items():
    with tempfile.TemporaryDirectory() as cfg:
        (Path(cfg) / "hypr").mkdir()
        env = {**os.environ, "XDG_CONFIG_HOME": cfg, "BIN_DIR": bin_dir, "ENTRY": entry}
        subprocess.run(["bash", "-c", SCRIPT], env=env, check=True)
        got = (Path(cfg) / "hypr" / entry).read_text().strip("\n")
        if got != want:
            failures.append(f"{bin_dir!r} {entry}:\n  got  {got}\n  want {want}")

for f in failures:
    print("FAIL:", f)
print(f"install-polkit-line: {'ok' if not failures else 'FAILED'}")
sys.exit(1 if failures else 0)
