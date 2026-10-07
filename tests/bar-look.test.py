"""The bar drawn with the shared kit (modules/bar/look): a module's box per
visual language and bar surface, the accent state of an open popup and of
the active workspace, and the kit controls inside the bar popups (levels as
LineSliders, power profiles as Chips, layouts / tray menu / window menu as
ListRows, downloads with a ProgressLine), offscreen."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from panels_env import PanelsEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

LAYOUT = {"style": "classic", "left": ["launcher", "workspaces", "layoutSelector", "appMenu"],
          "right": ["downloads", "systray", "controls", "battery", "clock"], "drawer": []}
ENV = PanelsEnv("bar-look", bar={"position": "top", "frameEnabled": False, "containBar": False, "layout": LAYOUT})
WIN = ENV.scene(1600, 900, windows=False)
H = ENV.h
QTest.qWait(400)

# Kit components by their API (QML types are not visible from Python)
COUNT = """(function(root, test) {
    let n = 0;
    const walk = it => { if (!it) return; if (test(it)) n++; for (const c of it.children || []) walk(c); };
    walk(root);
    return n;
})"""
IS_SLIDER = "it => it.fraction !== undefined && it.showValue !== undefined"
IS_CHIP = "it => it.active !== undefined && it.text !== undefined && it.icon !== undefined && it.look !== undefined"
IS_ROW = "it => it.visible && it.title !== undefined && it.subtitle !== undefined && it.selected !== undefined"
IS_PROGRESS = "it => it.fraction !== undefined && it.value !== undefined && it.showValue === undefined && it.from === undefined"


def theme(language, bar_opacity):
    host = H.find(WIN, "host")
    H.eval(host, f"Config.theme.language = '{language}'")
    H.eval(host, f"Config.theme.srBarBg = Object.assign({{}}, Config.theme.srBarBg, {{ opacity: {bar_opacity} }})")
    QTest.qWait(150)


def find(item, name):
    """Depth-first in the visual tree (Loader / Repeater items have no QObject parent)."""
    if item.objectName() == name:
        return item
    for child in item.childItems():
        found = find(child, name)
        if found is not None:
            return found
    return None


def box(module, name):
    return find(find(WIN.contentItem(), module), name)


def count(item, test):
    return H.eval(item, f"{COUNT}(this, {test})")


# Rest look: on a transparent bar the group box is the theme's "bg" pill
# (every kit language); on a visible strip it is the language's group box
for language, opacity, surface, group in [("ink", 0, True, False), ("glass", 0, True, True),
                                          ("ink", 0.9, False, False), ("glass", 0.9, False, True),
                                          ("tiles", 0, False, True), ("classic", 0.9, True, False)]:
    theme(language, opacity)
    where = (language, opacity)
    assert H.eval(box("batteryModule", "moduleSurface"), "visible") is surface, where
    assert H.eval(box("batteryModule", "moduleGroupBox"), "visible") is group, where
    assert H.eval(box("batteryModule", "moduleActive"), "visible") is False, where

# Popup open = the kit's accent state (a tint in ink, solid in tiles)
for language, solid in [("ink", False), ("tiles", True)]:
    theme(language, 0.9)
    popup = find(find(WIN.contentItem(), "batteryModule"), "batteryPopup")
    H.eval(popup, "open()")
    QTest.qWait(300)
    active = box("batteryModule", "moduleActive")
    assert H.eval(active, "visible") is True, language
    assert (H.eval(active, "backgroundOpacity") > 0.5) is solid, language
    assert count(popup, IS_CHIP) == 3, "one chip per power profile"
    assert count(popup, IS_PROGRESS) == 1, "the charge line"
    H.eval(popup, "close()")
    QTest.qWait(300)

# Active workspace: the pill indicator is the accent state
theme("ink", 0.9)
pill = find(WIN.contentItem(), "activeIndicator")
assert H.eval(pill, f"{COUNT}(this, it => it.variant === 'primary' && it.backgroundOpacity > 0 && it.backgroundOpacity < 1)") == 1
theme("tiles", 0.9)
assert H.eval(pill, f"{COUNT}(this, it => it.variant === 'primary' && it.backgroundOpacity === -1)") == 1

# Popups are built from kit controls
POPUPS = [("controlsModule", "controlsPopup", IS_SLIDER, 3), ("layoutSelectorModule", "layoutPopup", IS_ROW, -1),
          ("appMenu", "appMenuPopup", IS_ROW, 5), ("downloads", "downloadsPopup", IS_PROGRESS, 1),
          ("trayItem", "systrayMenu", IS_ROW, 5)]
theme("ink", 0)
for module, name, test, expected in POPUPS:
    popup = find(find(WIN.contentItem(), module), name)
    H.eval(popup, "open()")
    QTest.qWait(300)
    n = count(popup, test)
    assert (n >= 1 if expected < 0 else n == expected), (name, n)
    H.eval(popup, "close()")
    QTest.qWait(300)

print("bar look: module boxes per language, accent states and kit popups passed", flush=True)
# Type check + temp cleanup, then leave without Qt's destructor pass
H.exit(0)
