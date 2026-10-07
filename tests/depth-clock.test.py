"""DepthClock host + clock styles, offscreen with shell services stubbed.

Loads the real DepthClock.qml and every style from ClockStyleRegistry.js with
a synthetic mask result (subject on the left half) and checks: placement
picks the free side and draws behind the subject, both style parts load
with the same inputs, switching styles reloads them, unknown ids fall back,
12h adds the meridiem, videos never get depth, a palette ink role recolours
the style (auto restores the backdrop inks), the clock area is published
for desktop widgets, and nothing logs a QML error.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtCore import QDate, QDateTime, QTime, qInstallMessageHandler  # noqa: E402
from PySide6.QtGui import QColor, QImage  # noqa: E402
from PySide6.QtQuick import QQuickItem  # noqa: E402

W, H = 1280, 720
problems: list[str] = []
qInstallMessageHandler(lambda _m, _c, msg: problems.append(msg) if any(
    k in msg for k in ("TypeError", "ReferenceError", "Unable to assign", "is not a type", "Cannot read")) else None)

h = Harness("depth-clock")

# Synthetic wallpaper cutout + grid: the subject fills the left 45%.
cols, rows = 96, 54
cover = "".join("ff" if c < 43 else "00" for _r in range(rows) for c in range(cols))
lum = "33" * (cols * rows)
cutout = h.root / "cutout.png"
img = QImage(W, H, QImage.Format_ARGB32)
img.fill(QColor(0, 0, 0, 0))
for x in range(int(W * 0.45)):
    for y in range(0, H, 4):
        img.setPixelColor(x, y, QColor(200, 100, 100, 255))
img.save(str(cutout))
meta = {"ok": True, "cutout": str(cutout), "layouts": {f"{W}x{H}": {"grid": {"cols": cols, "rows": rows, "cover": cover, "lum": lum}}}}

h.singleton("qs.config", "Config", '''QtObject {
    property int animDuration: 0
    property bool showBackground: true
    property QtObject bar: QtObject { property string position: "top"; property bool use12hFormat: false; property bool frameEnabled: false; property int frameThickness: 0 }
    property QtObject theme: QtObject { property string font: "Sans" }
    property QtObject desktop: QtObject { property bool depthClock: true; property string depthClockStyle: "yozakura"; property string depthClockPosition: "auto"; property bool enabled: false; property int iconSize: 40; property int spacingVertical: 16; property string depthClockInk: "auto" }
}''')
roles = ["primaryFixed", "primaryFixedDim", "overPrimaryFixed", "overPrimaryFixedVariant", "shadow"]
roles += ["background", "overBackground", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh",
          "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red",
          "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]
h.singleton("qs.modules.theme", "Colors", "QtObject {\n" + "\n".join(
    f'    property color {r}: "{"#3366cc" if r == "tertiary" else "#808080"}"' for r in roles) + "\n}")
h.singleton("qs.modules.theme", "Motion",
            "QtObject { property var enter: ({ duration: 0, easing: Easing.OutCubic, overshoot: 1 }) }")
h.module("qs.modules.desktop.widgets", {
    "DesktopWidgets": "pragma Singleton\nQtObject { property var clockAreas: ({}); "
                      "function setClockArea(k, a) { const n = Object.assign({}, clockAreas); "
                      "if (a) n[k] = a; else delete n[k]; clockAreas = n; } }",
})
h.module("qs.modules.services", {
    "DepthMaskService": "pragma Singleton\nQtObject { property bool available: true; property var data: %s; "
                        "function result(p, w, h) { return data; } function request(p, w, h) {} }" % json.dumps(meta),
    "DesktopService": "pragma Singleton\nQtObject { property int maxRowsHint: 6; property QtObject items: QtObject { property int count: 0 } }",
})
h.module("qs.modules.bar.panels", {"Panels": 'pragma Singleton\nQtObject { property string primaryEdge: "top" }'})
h.copy("modules/desktop/DepthClock.qml", dest="modules/desktop")
for f in ("YozakuraClock.qml", "PosterClock.qml"):
    h.copy(f"modules/desktop/clockstyles/{f}", dest="modules/desktop/clockstyles")
root = h.load(f'''import QtQuick
import "../modules/desktop"
Item {{
    width: {W}; height: {H}
    DepthClock {{ objectName: "clock"; anchors.fill: parent; wallpaperPath: "/w/wall.jpg"; isVideo: false; tint: false; suppressed: false }}
}}''', auto_stub=False)
clock = h.find(root, "clock")
config = h.engine.singletonInstance("qs.config", "Config")


def styles():
    found = [c for c in clock.childItems() for c in c.childItems() if c.property("part") in ("behind", "front")]
    return {s.property("part"): s for s in found}


def texts(item):
    out = []
    for c in item.childItems():
        t = c.property("text")
        if isinstance(t, str) and c.metaObject().className().startswith("QQuickText"):
            out.append(t)
        out += texts(c)
    return out


clock.setProperty("now", QDateTime(QDate(2026, 10, 5), QTime(21, 47)))

# Placement: subject on the left -> clock on the right, behind the subject.
assert h.eval(clock, "placement.side") == "right", h.eval(clock, "placement.side")
assert h.eval(clock, "placement.depth") is True
assert h.eval(clock, "wantsDepth") is True

parts = styles()
assert set(parts) == {"behind", "front"}, parts
assert all("YozakuraClock" in p.metaObject().className() for p in parts.values())
for p in parts.values():
    assert p.property("side") == "right"
    assert p.property("layout") is not None
behind_texts = texts(parts["behind"])
assert {"21", "47", "時", "分"} <= set(behind_texts), behind_texts
assert "午後" in behind_texts  # present but hidden in 24h mode
front_chars = "".join(texts(parts["front"]))
for ch in "十月五日曜夜桜":
    assert ch in front_chars, front_chars

# 12h: hours become "9" and the 午後 unit is shown.
config.property("bar").setProperty("use12hFormat", True)
assert "9" in texts(styles()["behind"])
assert h.eval(clock, "use12h") is True
config.property("bar").setProperty("use12hFormat", False)

# Switching style reloads both parts; unknown ids fall back to the default.
desktop = config.property("desktop")
desktop.setProperty("depthClockStyle", "poster")
parts = styles()
assert all("PosterClock" in p.metaObject().className() for p in parts.values()), parts
assert {"21", "47"} <= set(texts(parts["behind"]))
desktop.setProperty("depthClockStyle", "bogus")
assert all("YozakuraClock" in p.metaObject().className() for p in styles().values())

# Forced side.
desktop.setProperty("depthClockPosition", "left")
assert h.eval(clock, "placement.side") == "left"
assert h.eval(clock, "placement.depth") is False  # the subject covers the left half
desktop.setProperty("depthClockPosition", "auto")

# Videos: never behind a frozen cutout.
clock.setProperty("isVideo", True)
assert h.eval(clock, "wantsDepth") is False
clock.setProperty("isVideo", False)

# Ink role: a palette role recolours the style, auto goes back.
desktop.setProperty("depthClockInk", "tertiary")
style = styles()["behind"]
assert style.property("inkRole") == "tertiary"
assert style.property("ink").name() == "#3366cc", style.property("ink").name()
desktop.setProperty("depthClockInk", "auto")
assert styles()["behind"].property("ink").name() == "#808080"

# The clock's area is published for desktop widgets under its areaKey.
widgets = h.engine.singletonInstance("qs.modules.desktop.widgets", "DesktopWidgets")
assert h.eval(clock, "publishedArea") is None  # no key yet
clock.setProperty("areaKey", "DP-1")
area = widgets.property("clockAreas").toVariant()["DP-1"]
bounds = h.eval(clock, "JSON.stringify(placement.layout.bounds)")
bounds = json.loads(bounds)
assert area and abs(area["x"] - bounds["x"]) < 0.5 and area["w"] > 0, (area, bounds)

# The settings gallery previews another style without touching the config.
clock.setProperty("styleId", "poster")
assert all("PosterClock" in p.metaObject().className() for p in styles().values())

assert isinstance(clock, QQuickItem)
assert not problems, "\n".join(problems)
print("depth-clock: ok")
