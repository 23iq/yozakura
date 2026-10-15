"""Sidebar hover keeps the theme/effect graph stable in kit visual languages.

Regresses ListRow switching its entire StyledRect to focus even though the
ControlBox already paints the hover. Masked corners and ink effects made
that invisible switch allocate effects and reparent content on every entry.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from settings_env import SettingsEnv  # noqa: E402
from PySide6.QtCore import QPoint, Qt  # noqa: E402
from PySide6.QtTest import QSignalSpy, QTest  # noqa: E402

env = SettingsEnv("settings-sidebar-hover", overrides={"theme": {
    "shape": {"corners": "squircle"}, "surfaceEffect": "ink",
}})
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.settings
Window {
    id: w
    width: 320; height: 180; visible: true
    property int clicks: 0
    NavItem {
        objectName: "nav"; x: 20; y: 20; width: 240
        category: ({id: "appearance", title: "prefs.cat.appearance", icon: "gear"})
        onClicked: w.clicks++
    }
}
""")
nav = h.find(win, "nav")
h.eval(nav, 'children.find(c => c.title !== undefined).objectName = "navRow"')
row = h.find(nav, "navRow")


def move(x, y):
    QTest.mouseMove(win, QPoint(x, y))
    QTest.qWait(20)


churn = {}
for language in ("ink", "glass", "tiles"):
    h.eval(win, f'Config.theme.language = "{language}"')
    move(300, 150)
    config_changes = QSignalSpy(row.variantConfigChanged)
    mask_changes = QSignalSpy(row.cornerMaskedChanged)
    effect_loads = QSignalSpy(h.find(row, "surfaceEffect").loaded)
    for _ in range(4):
        move(40, 35)
        assert row.property("hovered"), language
        assert h.eval(row, 'children.some(c => c.shown === true && c.visible && c.color.a > 0)'), (
            language, "the kit hover box remains visible")
        move(300, 150)
        assert not row.property("hovered"), language
    print(language, "hover cycles:", "style resolutions", config_changes.count(),
          "corner mask transitions", mask_changes.count(), "effect loads", effect_loads.count())
    churn[language] = (config_changes.count(), mask_changes.count(), effect_loads.count())

    # Keyboard focus uses the same hover box; selecting still uses the
    # accent surface and pointer feedback must not remove that selection.
    row.setProperty("highlighted", True)
    assert row.property("hovered") and row.property("boxed"), language
    nav.setProperty("selected", True)
    assert row.property("variant") == "primary", language
    nav.setProperty("selected", False)
    row.setProperty("highlighted", False)

QTest.mouseClick(win, Qt.LeftButton, pos=QPoint(40, 35))
assert win.property("clicks") == 1, "sidebar navigation remains clickable"

# Classic has no kit control box: its configured focus variant still paints hover.
h.eval(win, 'Config.theme.language = "classic"')
move(300, 150)
move(40, 35)
assert row.property("variant") == "focus", "classic keeps its theme-defined hover surface"
assert churn == {"ink": (0, 0, 0), "glass": (0, 0, 0), "tiles": (0, 0, 0)}, (
    "hover must not re-resolve styles, rebuild corner-mask layers or load hidden ink effects", churn)
print("settings sidebar hover: ok")
