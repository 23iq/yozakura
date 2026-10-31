"""Window reservations come only from what occupies an edge: a bottom-only or
left-only panel leaves the top edge free whatever the legacy bar.position, the
notch (attached, dot or off) never reserves, the top panel still does."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import PanelsEnv  # noqa: E402
import qmlharness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

ENVS = []


def zones(bar, notch=None):
    env = PanelsEnv("reservation-edges", bar=bar, notch=notch)
    ENVS.append(env)
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(150)
    host = env.h.find(win, "host")
    z = json.loads(env.h.eval(host, "JSON.stringify(zones)"))
    win.close()
    return z


STATUS = {"id": "status", "edge": "bottom", "style": "statusline", "groups": {"start": ["workspaceTags"]}}
DOCKLIKE = {"id": "main", "edge": "bottom", "style": "dock-like", "groups": {"center": ["taskbar"]}}
RAIL = {"id": "rail", "edge": "left", "style": "rail", "groups": {"start": ["workspaces"]}}
TOP = {"id": "top", "edge": "top", "style": "classic", "groups": {"start": ["clock"]}}

# Legacy bar.position stays "top" (as in the Tatami/CRT layouts) while the
# only panel sits on the bottom: nothing reserves the top edge.
for panel in (STATUS, DOCKLIKE):
    z = zones({"position": "top", "frameEnabled": False, "panels": [panel]})
    assert z["top"] == 0 and z["left"] == 0 and z["right"] == 0 and z["bottom"] > 0, z

# Notch off / dot / attached never adds a top reservation
for notch in ({"enabled": False}, {"enabled": True, "style": "dot"}, {"enabled": True, "style": "attached", "position": "top"}):
    z = zones({"position": "top", "frameEnabled": False, "panels": [STATUS]}, notch)
    assert z["top"] == 0, (notch, z)

# Vertical bar on the left: only the left edge
z = zones({"position": "top", "frameEnabled": False, "panels": [RAIL]})
assert z["left"] > 0 and z["top"] == 0 and z["bottom"] == 0 and z["right"] == 0, z

# A panel on the top still reserves the top, and only the top
z = zones({"position": "top", "frameEnabled": False, "panels": [TOP]})
assert z["top"] > 0 and z["bottom"] == 0, z

print("reservation-edges: ok", flush=True)
# PySide tears several QML engines down in an order that can crash
qmlharness.hard_exit(0)
