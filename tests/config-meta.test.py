"""Config validator and catalog metadata load in a real QML engine.

config/ConfigValidator.js takes its allowed-value lists from
config/meta/Enums.js, which imports the bar, clock-style, numeral and voice
registries; config/meta/Meta.js (read at build time by tools/schema) imports
every domain file. Node tests cover the logic; this checks the QML `.import`
chains resolve and the shared lists reach the validator.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402

h = Harness("config-meta")
qml = h.write(f"""import QtQuick
import "file://{REPO}/config/ConfigValidator.js" as V
import "file://{REPO}/config/meta/Meta.js" as M
QtObject {{
    property string barStyle: V.validate({{"style": "weird"}}, {{"style": "classic"}}).style
    property string gradient: V.validate({{"gradientType": "nope"}}, {{"gradientType": "linear"}}).gradientType
    property string kept: V.validate({{"gradientType": "radial"}}, {{"gradientType": "linear"}}).gradientType
    property int domains: Object.keys(M.domains).length
    property string edges: M.domains.bar.keys.position["enum"].join(",")
    property string clockStyles: M.domains.desktop.keys.depthClockStyle["enum"].join(",")
}}
""", name="Probe.qml")
obj = h.load(qml, auto_stub=False)

assert h.eval(obj, "barStyle") == "classic", h.eval(obj, "barStyle")
assert h.eval(obj, "gradient") == "linear"
assert h.eval(obj, "kept") == "radial"
assert h.eval(obj, "domains") >= 16, h.eval(obj, "domains")
assert h.eval(obj, "edges") == "top,bottom,left,right"
assert "poster" in h.eval(obj, "clockStyles").split(","), h.eval(obj, "clockStyles")
print("ok config-meta")
