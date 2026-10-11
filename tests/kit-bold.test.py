"""The kit's big controls (Tile, LevelSlider, Segmented, Sparkline) and
their tokens (Look.raisedFill / bigRadius, Type.load) in every visual
language: raised at rest, solid accent when on, the detail zones, the
slider's fill holding its icon, the sliding segment pill."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 500; height: 600; visible: true
    property int clicks: 0
    property int mores: 0
    property int moved: 0
    property int mutes: 0
    property int picked: -1
    Column {
        spacing: 4
        Tile { objectName: "tile"; width: 200; icon: Icons.wifiHigh; text: "Wi-Fi"; subtext: "Home"; hasMore: true
               onClicked: parent.Window.window.clicks++; onMore: parent.Window.window.mores++ }
        Tile { objectName: "square"; width: 80; vertical: true; hasMore: true; icon: Icons.bell; text: "Silence" }
        LevelSlider { objectName: "level"; width: 300; icon: Icons.speakerHigh; value: 0.5; iconClickable: true
                      onMoved: parent.Window.window.moved++; onIconClicked: parent.Window.window.mutes++ }
        LevelSlider { objectName: "levelMore"; width: 300; icon: Icons.mic; hasMore: true; value: 0 }
        Segmented { objectName: "seg"; currentIndex: 1
                    model: [{ name: "segA", text: "One" }, { name: "segB", icon: Icons.gear, text: "Two" }]
                    onActivated: i => parent.Window.window.picked = i }
        Sparkline { objectName: "spark"; width: 80; height: 20; values: [0.1, 0.5, 0.3] }
        Sparkline { objectName: "sparkEmpty"; values: [] }
    }
}"""

for lang in ("ink", "glass", "tiles", "classic"):
    env = KitEnv(f"kit-bold-{lang}", overrides={"theme": {"language": lang}})
    h = env.h
    win = env.load(SCENE)
    get = functools.partial(h.find, win)
    ev = h.eval
    tag = lang

    # Raised surfaces exist even where small controls are ghosts.
    assert ev(win, "Look.raisedFill(false).a") > 0, tag
    assert ev(win, "Look.raisedFill(true).a") >= ev(win, "Look.raisedFill(false).a"), tag
    square = lang == "tiles"
    assert ev(win, "Look.bigRadius(100)") == ev(win, "Space.controlRadius" if square else "Space.surfaceRadius"), tag
    assert ev(win, "Look.bigRadius(10)") == 5, tag
    assert ev(win, "Type.load(0.2).toString()") == ev(win, "Type.progress.toString()"), tag
    assert ev(win, "Type.load(0.75).toString()") == ev(win, "Colors.warning.toString()"), tag
    assert ev(win, "Type.load(0.95).toString()") == ev(win, "Colors.error.toString()"), tag

    # Tile: raised off, solid accent on; the caret zone only on row tiles.
    tile, sq = get("tile"), get("square")
    assert tile.property("height") == ev(win, "Space.controlM + Space.l"), tag
    assert ev(h.find(tile, "tileRest"), "visible") and not ev(h.find(tile, "tileOn"), "visible"), tag
    assert ev(h.find(tile, "tileMore"), "visible"), tag
    assert not ev(h.find(sq, "tileMore"), "visible"), "vertical tiles keep only right-click / hold"
    ev(tile, "active = true")
    QTest.qWait(400)  # the accent cross-fades in
    assert ev(h.find(tile, "tileOn"), "visible") and not ev(h.find(tile, "tileRest"), "visible"), tag
    assert ev(tile, "ink.toString()") == ev(win, "Type.accentInk.toString()"), tag
    ev(tile, "clicked(); more()")
    assert win.property("clicks") == 1 and win.property("mores") == 1, tag

    # LevelSlider: the fill always holds the icon, steps clamp, the caret
    # zone narrows the span, mute through the cap.
    level, lmore = get("level"), get("levelMore")
    cap = level.property("height")
    assert cap == ev(win, "Space.controlM + Space.xs"), tag  # the gallery's own height
    assert abs(level.property("fillW") - (cap + 0.5 * (300 - cap))) < 1, tag
    ev(level, "setFraction(1.4)")
    assert level.property("value") == 1 and win.property("moved") == 1, tag
    ev(level, "stepBy(-2)")
    assert abs(level.property("value") - 0.9) < 1e-6, tag
    ev(level, "setFraction(0.9)")
    assert win.property("moved") == 2, "no move without a change"
    assert lmore.property("fillW") == lmore.property("height"), "an empty fill still holds the icon"
    assert lmore.property("span") == 300 - 2 * lmore.property("height"), tag
    assert ev(h.find(lmore, "levelMore"), "visible") and not ev(h.find(level, "levelMore"), "visible"), tag
    assert ev(level, "fillColor.toString()") == ev(win, "Look.tonal(Type.progress).toString()"), "tonal fill"
    ev(level, "dimmed = true")
    QTest.qWait(400)  # the fill colour eases
    assert ev(level, "fillColor.toString()") == ev(win, "Qt.alpha(Type.muted, 0.45).toString()"), tag
    assert not ev(h.find(level, "levelMeter"), "visible"), tag
    ev(level, "level = 0.5")
    assert ev(h.find(level, "levelMeter"), "visible"), tag
    ev(level, "iconClicked()")
    assert win.property("mutes") == 1, tag

    # Segmented: the pill sits on the current segment and follows it.
    seg = get("seg")
    assert ev(seg, "currentItem.objectName") == "segB" and ev(seg, "currentItem.active") is True, tag
    assert ev(seg, "currentItem.text") == "Two", tag
    pill = h.find(seg, "segmentPill")
    assert abs(pill.property("width") - ev(seg, "currentItem.width")) < 1, tag
    ev(seg, "activated(0)")
    assert win.property("picked") == 0, tag

    # Sparkline counts its values; fewer than two draw nothing.
    assert get("spark").property("count") == 3 and get("sparkEmpty").property("count") == 0, tag

print("kit-bold: ok")
