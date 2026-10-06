"""Settings > AI providers, offscreen: the page renders the AI bar's Connect
sheet embedded (grid -> form -> Save through Ai.providers), the per-provider
picker switches (ai.providers.hidden) and the default-model choice. Real
modules/settings + modules/aicenter/providers on tests/lib/settings_env.py
(Ai.providers is a scripted stub there).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

env = SettingsEnv("ai-providers-settings")
h = env.h
errors: list[str] = []
_prev = qInstallMessageHandler(None)


def _capture(mode, ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "is not installed",
                              "failed to load", "Error:")):
        errors.append(msg)
    if _prev:
        _prev(mode, ctx, msg)


qInstallMessageHandler(_capture)

win = env.load("""
import QtQuick
import QtQuick.Window
import qs.modules.services
import qs.modules.settings
Window {
    id: w
    width: 1180; height: 900; visible: true; color: "black"
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        if (item.contentItem && item.contentItem !== item && kids.indexOf(item.contentItem) === -1)
            kids = kids.concat([item.contentItem]);
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    SettingsShell { objectName: "shell"; anchors.fill: parent }
}""")
shell = h.find(win, "shell")


def ev(expr: str):
    return h.eval(shell, expr)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


ev('select("ai-providers")')
QTest.qWait(600)
check(ev('w.findItem("settingsConnectSheet") !== null'), "the Connect sheet is embedded in the page")
for pid in ("openai", "openrouter", "deepseek", "lmstudio", "ollama", "custom"):
    check(ev(f'w.findItem("tile_{pid}") !== null'), f"tile {pid}")
check(ev('w.findItem("tileState_ollama").text') == "Running", "state from Ai.providers.status()")
check(ev('w.findItem("connectClose") === null || !w.findItem("connectClose").visible'), "no close button when embedded")

ev('w.findItem("settingsConnectSheet").provider = "deepseek"')
QTest.qWait(200)
check(ev('w.findItem("connectKeyInput") !== null'), "the form replaces the grid")
ev('w.findItem("connectKeyInput").text = "ds-key"')
ev('w.findItem("connectSave").clicked()')
QTest.qWait(200)
check(ev("JSON.stringify(Ai.providers.saved)") == '["deepseek"]', "Save goes through Ai.providers.save()")
check(ev('w.findItem("tile_openai") !== null'), "after saving the embedded sheet returns to the grid")

check(ev('w.findItem("showProvider_minimax") !== null'), "one picker switch per provider")
ev("Ai.providers.setHidden('minimax', true)")
check(ev("JSON.stringify(Ai.providers.hidden)") == '["minimax"]', "switch state")
check(ev('w.findItem("defaultModelChoice") !== null'), "default model choice")

if errors:
    print("\n".join(errors[:10]), file=sys.stderr)
    sys.exit(1)
print("ai-providers-settings: ok")
h.exit(0)
