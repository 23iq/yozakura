"""The instrument pieces of the kit: Knob (detents, clamping, keys, wheel
steps), SegmentDigits (cells, separators, lit / off segments) and how
LevelSlider / Tile follow the language's instrument tokens (Look.levelControl,
Look.readout, Look.ledIndicator): a knob strip and LED tiles in device, the
pill slider and solid tiles elsewhere."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 500; height: 500; visible: true
    property int moved: 0
    Column {
        spacing: 4
        Knob { objectName: "knob"; value: 0.5; detents: 10; onMoved: parent.Window.window.moved++ }
        Knob { objectName: "smooth"; from: 0; to: 100; value: 30 }
        SegmentDigits { objectName: "digits"; text: "21:05"; digitHeight: 40 }
        LevelSlider { objectName: "level"; width: 300; icon: Icons.speakerHigh; value: 0.62 }
        Tile { objectName: "tile"; width: 200; icon: Icons.wifiHigh; text: "Wi-Fi"; active: true }
    }
}"""

for lang in ("ink", "device"):
    env = KitEnv(f"kit-device-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    win = env.load(SCENE)
    get = functools.partial(h.find, win)
    ev = h.eval
    device = lang == "device"

    assert ev(win, "Look.levelControl") == ("knob" if device else "slider"), lang
    assert ev(win, "Look.readout") == ("segment" if device else "text"), lang
    assert ev(win, "Look.ledIndicator") is device, lang
    assert ev(win, "Look.wellFill.a") > 0, lang
    assert (ev(win, "Type.family('label')") == ev(win, "Config.theme.monoFont")) is device, lang

    # Knob: detents snap and clamp, keys and steps move it by one detent.
    knob = get("knob")
    ev(knob, "setValue(0.53)")
    assert abs(knob.property("value") - 0.5) < 1e-6 and win.property("moved") == 0, "snapped to the same detent"
    ev(knob, "stepBy(1)")
    assert abs(knob.property("value") - 0.6) < 1e-6 and win.property("moved") == 1, lang
    ev(knob, "setValue(4)")
    assert knob.property("value") == 1, "clamped"
    win.requestActivate()
    ev(knob, "forceActiveFocus()")
    QTest.qWait(50)
    QTest.keyClick(win, Qt.Key_Down)
    QTest.qWait(20)
    assert abs(knob.property("value") - 0.9) < 1e-6, "Down steps down"
    QTest.keyClick(win, Qt.Key_Home)
    QTest.qWait(20)
    assert knob.property("value") == 0, "Home goes to the start"
    smooth = get("smooth")
    ev(smooth, "stepBy(1)")
    assert abs(smooth.property("value") - 35) < 1e-6, "no detents: (to - from) / 20 a step"
    assert smooth.property("fraction") == 0.35, lang

    # SegmentDigits: one cell per character, the colon a narrow dot pair.
    digits = get("digits")
    assert digits.property("implicitHeight") == 40, lang
    w, dot, sp = (digits.property(k) for k in ("digitWidth", "dotWidth", "spacing"))
    assert abs(digits.property("implicitWidth") - (4 * w + dot + 4 * sp)) < 1, lang

    # LevelSlider: a knob strip where levels are knobs, the pill fill otherwise.
    level = get("level")
    assert level.property("knob") is device, lang
    assert ev(h.find(level, "levelFill"), "visible") is not device, lang
    if device:
        assert abs(h.find(level, "levelKnob").property("value") - 0.62) < 1e-6, lang
        assert ev(h.find(level, "levelWell"), "visible"), lang

    # Tile: an LED on a matte tile, or the solid accent fill.
    tile = get("tile")
    QTest.qWait(300)
    assert ev(h.find(tile, "tileLed"), "visible") is device, lang
    assert ev(h.find(tile, "tileOn"), "visible") is not device, lang
    if device:
        assert ev(tile, "glyphInk.toString()") == ev(win, "Type.accent.toString()"), "the icon carries the state"

print("kit-device: ok")
