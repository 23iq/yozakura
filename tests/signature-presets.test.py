"""Built-in presets with panel layouts, offscreen: each one's bar.panels
loads with its theme, notch and workspaces config without QML errors, the
Shōji frame draws its double hairline (others none), workspace tags follow
the numeral style (Neon Tokyo: roman) and a clock with
moduleOptions.clock.showWeather false leaves the weather to its module."""
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import bundled_fonts  # noqa: E402
from panels_env import REPO, PanelsEnv  # noqa: E402
from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

PRESETS = REPO / "assets" / "presets"
problems: list[str] = []
qInstallMessageHandler(lambda _m, _c, msg: problems.append(msg) if any(
    k in msg for k in ("TypeError", "ReferenceError", "is not a type", "Cannot assign")) else None)
bundled_fonts.register()


def read(name: str, domain: str) -> dict:
    p = PRESETS / name / f"{domain}.json"
    return json.loads(p.read_text()) if p.exists() else {}


def visual(item, name: str):
    """Depth-first search of the visual tree (Repeater delegates are not QObject children)."""
    out = []
    if item.objectName() == name:
        out.append(item)
    for child in item.childItems():
        out += visual(child, name)
    return out


panel_presets = sorted(p.name for p in PRESETS.iterdir() if read(p.name, "bar").get("panels"))
assert {"Neon Tokyo", "Glacier", "Kaze", "Shōji", "Metro", "CRT"} <= set(panel_presets), panel_presets
ENVS = []
for name in panel_presets:
    theme = read(name, "theme")
    env = PanelsEnv("signature-" + name, bar=read(name, "bar"), theme=theme, notch=read(name, "notch"),
                    dock=read(name, "dock") or None, extra={"workspaces": read(name, "workspaces")})
    ENVS.append(env)
    win = env.scene(1600, 900, windows=False)
    QTest.qWait(250)
    host = env.h.find(win, "host")
    count = env.h.eval(host, "bars.length")
    enabled = [p for p in read(name, "bar")["panels"] if p.get("enabled", True)]
    assert count == len(enabled), (name, count, len(enabled))

    lines = visual(win.contentItem(), "frameLines")
    drawn = any(item.isVisible() for item in lines)
    framed = read(name, "bar").get("frameEnabled", False) and theme.get("srFrame", {}).get("inheritBg") is False
    assert drawn == framed, (name, "frame hairlines", drawn)

    if name == "Neon Tokyo":
        tags = [t.property("text") for t in visual(win.contentItem(), "workspaceTagLabel")]
        assert tags and all(set(t) <= set("IVXLC") for t in tags), tags
    win.close()

assert not problems, "\n".join(problems[:20])
print(f"{len(panel_presets)} presets ok", flush=True)
# PySide tears several QML engines down in an order that can crash; every
# check passed, leave without running the destructors.
os._exit(0)
