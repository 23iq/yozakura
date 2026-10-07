"""Kit progress role (theme.progressRole): progress fills, rings and slider
fills follow the configured palette role; the accent stays primary."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 300; height: 200; visible: true
    Column {
        ProgressLine { objectName: "progress"; width: 200; value: 0.5 }
        Ring { objectName: "ring"; value: 0.4 }
    }
}"""

for role in ("primary", "secondary", "tertiary"):
    env = KitEnv(f"kit-progress-{role}", overrides={"theme": {"progressRole": role}})
    h = env.h
    win = env.load(SCENE)
    want = h.eval(win, f"Colors.{role}.toString()")
    assert h.eval(win, "Type.progress.toString()") == want, role
    assert h.eval(h.find(win, "ring"), "color.toString()") == want, role
    fill = h.eval(h.find(win, "progress"), "children[0].color.toString()")
    assert fill == want, (role, fill)
    assert h.eval(win, "Type.accent.toString()") == h.eval(win, "Colors.primary.toString()"), role

print("kit-progress-role: ok")
