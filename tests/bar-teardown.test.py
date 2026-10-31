"""Bar modules survive their bar going away: switching the panel style or edge
(what applying a preset does) rebuilds the bar, and bindings of modules
being torn down still run once with `bar` / `barRoot` already null. None of
them may throw (BarModuleSlot, SysTray, Clock, BatteryIndicator,
ControlsButton, BarPinButton, Workspaces: "Cannot read property ... of null").
`YOZAKURA_TEST_REPO` runs it against another checkout (to see it fail)."""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import REPO, PanelsEnv  # noqa: E402
from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

NULL_READ = re.compile(r"modules/bar/.*Cannot read property '\w+' of null")
LAYOUT = {"left": ["launcher", "workspaces", "pin"], "center": ["clock"],
          "right": ["systray", "controls", "battery", "power"]}
repo = Path(os.environ.get("YOZAKURA_TEST_REPO", REPO))
ENV = PanelsEnv("bar-teardown", repo=repo, bar={"position": "top", "layout": {"style": "classic", **LAYOUT}})

seen: list[str] = []
_prev = None


def record(mode, ctx, msg):
    if NULL_READ.search(msg):
        seen.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


_prev = qInstallMessageHandler(record)
WIN = ENV.scene(1600, 900, windows=False)
HOST = ENV.h.find(WIN, "host")
QTest.qWait(200)

for style, edge in (("islands", "top"), ("pills", "left"), ("none", "bottom"), ("classic", "right"),
                    ("floating", "top"), ("classic", "top")):
    ENV.h.eval(HOST, "Config.bar.position = '%s'" % edge)
    ENV.h.eval(HOST, "Config.bar.layout = Object.assign({}, Config.bar.layout, {style: '%s'})" % style)
    QTest.qWait(150)

assert not seen, "null reads while the bar was rebuilt:\n  " + "\n  ".join(sorted(set(seen)))
print("bar-teardown: ok")
ENV.h.exit(0)
