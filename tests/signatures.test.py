"""Signatures (theme.signatures.*): the brush highlight underlay and the lock
screen petals follow their flag, are created only while enabled and shown,
and switch off in game mode and the power-saver profile; petals are capped
at 40 particles and use palette colors."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lockscreen_env import LockscreenEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = LockscreenEnv("signatures", overrides={"theme": {"animDuration": 20}})
h = env.h
root = env.load(
    "import QtQuick\nimport qs.modules.lockscreen\nimport qs.modules.services\nimport qs.config\n"
    "import qs.modules.components.signatures\n"
    "Item { id: r; width: 800; height: 600\n"
    " property bool shown: true\n"
    " function sig(b, p) { Config.theme.signatures = { brushHighlight: b, petals: p } }\n"
    " Item { id: host; objectName: 'host'; width: 200; height: 40\n"
    "  BrushHighlight { objectName: 'brush'; shown: r.shown } }\n"
    " Petals { objectName: 'petals' } }"
)
brush, petals = h.find(root, "brush"), h.find(root, "petals")


def set_(expr: str) -> None:
    h.eval(root, expr)
    QTest.qWait(50)


def alive(obj) -> bool:
    return bool(h.eval(obj, "item !== null"))


# Off by default (the default shift turns them on later).
assert not alive(brush) and not alive(petals), "signatures must default to off"

# Flags switch them on.
set_("sig(true, false)")
assert alive(brush) and not alive(petals)
set_("sig(true, true)")
assert alive(petals)

# The brush follows `shown`.
set_("shown = false")
assert not alive(brush)
set_("shown = true")
assert alive(brush)

# Petals: at most 40, palette colors, gentle fall.
cap = h.eval(petals, "cap")
assert 0 < cap <= 40, cap
em = h.eval(petals, "item.children.filter(c => c.maximumEmitted !== undefined)[0]")
assert em is not None
assert h.eval(petals, "item.children.filter(c => c.maximumEmitted !== undefined)[0].maximumEmitted") <= 40
assert h.eval(petals, "item.tints.length") == 3

# Game mode switches both off, and back on.
set_("GameModeClient.toggled = true")
assert not alive(brush) and not alive(petals), "game mode must turn the signatures off"
set_("GameModeClient.toggled = false")
assert alive(brush) and alive(petals)

# Low performance profile switches both off.
set_("PowerProfileClient.currentProfile = 'power-saver'")
assert not alive(brush) and not alive(petals), "power-saver must turn the signatures off"
set_("PowerProfileClient.currentProfile = 'performance'")
assert alive(brush) and alive(petals)

# Petals need motion; the brush does not.
set_("Config.theme.animDuration = 0")
assert not alive(petals) and alive(brush)

# Flags off.
set_("Config.theme.animDuration = 20; sig(false, false)")
assert not alive(brush) and not alive(petals)
assert not env.errors, env.errors
print("ok")
