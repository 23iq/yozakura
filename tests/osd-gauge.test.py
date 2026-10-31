"""The gauge OSD (styles/OsdGauge.qml): the needle swings to the level and
drops to zero when muted, the well shows the value (segment digits where
the language reads out in segments) or the accent "Muted" label, and the
footer names the device after a switch."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from osd_env import OsdEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.shell.osd.styles
Window {
    width: 300; height: 300; visible: true
    OsdGauge { objectName: "gauge"; width: implicitWidth; height: implicitHeight; kind: "volume"; value: 0.62 }
}"""

for lang in ("ink", "device"):
    env = OsdEnv(f"osd-gauge-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    win = env.load(SCENE)
    g = h.find(win, "gauge")
    ev = h.eval
    QTest.qWait(800)  # the needle settles
    assert abs(g.property("needle") - 0.62) < 0.01, lang
    assert g.property("width") > 100 and g.property("height") > 100, lang
    assert ev(g, "segment") is (lang == "device"), lang

    ev(g, "muted = true")
    QTest.qWait(800)
    assert g.property("needle") < 0.01, "muted drops the needle"
    assert ev(g, "readout.accent") is True and ev(g, "deviceLine") == "", lang

    ev(g, "muted = false; device = 'Headphones'")
    QTest.qWait(50)
    assert ev(g, "deviceLine") == "Headphones", lang

print("osd-gauge: ok")
