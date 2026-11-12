"""While the polkit password dialog is up, the shell's own surfaces never
hold or take the keyboard from it: the real Visibilities closes the open
module when the dialog opens and refuses to open one while it is up, and
the real PolkitService lets GlobalShortcuts run only the commands that map
no surface (locking, media, brightness, do not disturb, wallpaper)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402

h = Harness("polkit-focus-yield")
h.module("Quickshell", {"Singleton": "Item {}"})
h.singleton("qs.modules.services", "YozdService", """QtObject {
    property var focusedMonitor: ({name: "A"})
    function monitorFor(screen) { return null }
}""")
h.copy("modules/services/Visibilities.qml", "qs/modules/services")
h.copy("modules/services/PolkitService.qml", "qs/modules/services")
h.module("qs.modules.services", {})
root = h.load("""import QtQuick
import qs.modules.services
Item {}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


def settle():
    for _ in range(3):
        h.app.processEvents()


ev('Visibilities.setActiveModule("launcher")')
settle()
assert ev('Visibilities.getForScreen("A").launcher') is True, "launcher did not open"

ev("PolkitService.dialogOpen = true")
settle()
assert ev('Visibilities.getForScreen("A").launcher') is False and ev("Visibilities.currentActiveModule") == "", \
    "the open module stayed up under the password dialog"
for module in ["launcher", "dashboard", "overview", "keybinds", "presets"]:
    ev(f'Visibilities.setActiveModule("{module}")')
    settle()
    assert ev("Visibilities.currentActiveModule") == "" and ev(f'Visibilities.getForScreen("A").{module}') is False, \
        f"{module} opened while the password dialog is up"

for cmd in ["launcher", "assistant", "ai-quickask", "screenshot", "screenrecord", "config", "terminal", "onboarding", "overview"]:
    assert ev(f'PolkitService.allowsCommand("{cmd}")') is False, f"{cmd} runs while the password dialog is up"
for cmd in ["lockscreen", "media-play-pause", "brightness-up", "dnd-toggle", "wallpaper-next"]:
    assert ev(f'PolkitService.allowsCommand("{cmd}")') is True, f"{cmd} is refused while the password dialog is up"

ev("PolkitService.dialogOpen = false")
settle()
assert ev('PolkitService.allowsCommand("launcher")') is True, "commands stay refused after the dialog"
ev('Visibilities.setActiveModule("dashboard")')
settle()
assert ev('Visibilities.getForScreen("A").dashboard') is True, "modules stay refused after the dialog"

# Every keybind / `<app> run` command goes through GlobalShortcuts.run(),
# which asks PolkitService before it dispatches.
src = (REPO / "modules/services/GlobalShortcuts.qml").read_text()
run = src[src.index("    function run(command) {"):]
assert re.search(r"if \(!PolkitService\.allowsCommand\(command\)\)[^}]*return;", run[:run.index("switch (command)")]), \
    "GlobalShortcuts.run() dispatches without asking PolkitService.allowsCommand"
print("polkit-focus-yield: ok")
h.exit(0)
