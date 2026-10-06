"""Shared UI kit (modules/components/kit): every component loads in each
visual language, sizes follow the Type roles and Space scale (density
included), and the interactive states switch the look."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 400; height: 900; visible: true
    property int triggered: 0
    property int moved: 0
    Column {
        KitText { objectName: "display"; role: "display"; text: "21:47" }
        KitText { objectName: "title"; role: "title"; text: "Title" }
        KitText { objectName: "body"; text: "Body" }
        KitText { objectName: "secondary"; role: "secondary"; text: "Secondary" }
        KitText { objectName: "caption"; role: "caption"; text: "Caption" }
        KitText { objectName: "label"; role: "label"; text: "Label" }
        SectionLabel { objectName: "section"; width: 300; text: "Notifications"; action: "Clear"
                       onTriggered: parent.Window.window.triggered++ }
        Divider { objectName: "hline"; width: 300 }
        Divider { objectName: "vline"; vertical: true; height: 20 }
        IconButton { objectName: "btnS"; size: "s"; icon: Icons.gear }
        IconButton { objectName: "btnM"; icon: Icons.gear }
        Chip { objectName: "chip"; icon: Icons.wifiHigh; text: "Wi-Fi" }
        ListRow { objectName: "row"; width: 300; title: "Mira"; subtitle: "Sent the deck"
                  leading: Component { Avatar { objectName: "avatar"; name: "Mira Tanaka" } }
                  trailing: Component { KeyHint { objectName: "key"; text: "Esc" } } }
        LineSlider { objectName: "slider"; width: 240; icon: Icons.speakerHigh; showValue: true; value: 0.25
                     onMoved: parent.Window.window.moved++ }
        LineSlider { objectName: "vslider"; vertical: true }
        ProgressLine { objectName: "progress"; width: 200; value: 0.5 }
        Ring { objectName: "ring"; value: 0.4; KitText { text: "18:24" } }
        Art { objectName: "art" }
        Surface { objectName: "surface"; Item { width: 100; height: 50 } }
    }
}"""

CASES = [("ink", "cozy"), ("glass", "cozy"), ("tiles", "cozy"), ("classic", "cozy"), ("ink", "compact")]
SCALE = {"display": 3, "title": 1.3, "body": 1, "secondary": 0.93, "caption": 0.86, "label": 0.78}

for lang, density in CASES:
    env = KitEnv(f"kit-{lang}-{density}", overrides={"theme": {"language": lang, "density": density}})
    h = env.h
    win = env.load(SCENE)
    get = functools.partial(h.find, win)
    space = functools.partial(lambda hh, w, key: hh.eval(w, f"Space.{key}"), h, win)
    tag = f"{lang}/{density}"

    # Type roles
    base = h.eval(win, "Config.theme.fontSize")
    for role, f in SCALE.items():
        px = h.eval(get(role), "font.pixelSize")
        assert px == max(8, int(base * f + 0.5)), (tag, role, px)
    assert h.eval(get("display"), "font.weight") == 300, tag
    assert h.eval(get("display"), "tabular") is True, tag
    assert h.eval(get("title"), "font.weight") == 600, tag
    assert h.eval(get("label"), "font.capitalization") == 1, tag  # AllUppercase
    assert h.eval(get("label"), "font.letterSpacing") > 0, tag
    assert h.eval(get("label"), "color.toString()") == h.eval(win, "Colors.outline.toString()"), tag
    assert h.eval(get("secondary"), "color.toString()") == h.eval(win, "Colors.overSurfaceVariant.toString()"), tag

    # Space scale (density)
    factor = {"compact": 7 / 8, "cozy": 1}[density]
    for key, v in (("xs", 4), ("s", 8), ("m", 12), ("l", 16), ("xl", 24), ("xxl", 32)):
        assert space(key) == int(v * factor + 0.5), (tag, key, space(key))
    assert space("controlRadius") == space("surfaceRadius") - 4, tag
    assert space("smallRadius") == space("surfaceRadius") - 8, tag

    # Structure
    assert get("hline").property("height") == 1 and get("vline").property("width") == 1, tag
    section = get("section")
    h.eval(section, "triggered()")
    assert win.property("triggered") == 1, tag

    # IconButton sizes and states
    s, m = get("btnS"), get("btnM")
    assert s.property("width") == space("controlS") and m.property("width") == space("controlM"), tag
    assert m.property("radius") == m.property("height") / 2, tag
    assert m.property("variant") == "common" and m.property("look") == "normal", tag
    rest = m.property("rectOpacity")
    if lang == "ink":
        assert rest == 0, (tag, rest)  # ghost
    if lang == "tiles":
        assert rest == 1, (tag, rest)  # solid tile
    m.setProperty("highlighted", True)
    assert m.property("variant") == "focus" and m.property("look") == "hover", tag
    m.setProperty("active", True)
    assert m.property("variant") == "primary" and m.property("look") == "active", tag
    assert 0 < m.property("rectOpacity") < 0.3, (tag, m.property("rectOpacity"))
    m.setProperty("primary", True)
    assert m.property("look") == "primary" and m.property("rectOpacity") > 0.85, tag

    # Chip
    chip = get("chip")
    assert chip.property("height") == space("chip"), tag
    chip.setProperty("active", True)
    assert chip.property("variant") == "primary" and chip.property("look") == "active", tag

    # ListRow: ghost at rest, focus on hover, tint when selected; slots load
    row = get("row")
    assert row.property("height") == h.eval(win, "Metrics.rowHeight"), tag
    assert row.property("variant") == "transparent", tag
    row.setProperty("highlighted", True)
    assert row.property("variant") == "focus", tag
    row.setProperty("selected", True)
    assert row.property("variant") == "primary", tag
    assert h.eval(get("avatar"), "placeholderText") == "MT", tag
    assert get("key").property("height") == space("keyHint"), tag

    # LineSlider / ProgressLine / Ring
    slider = get("slider")
    assert slider.property("fraction") == 0.25, tag
    h.eval(slider, "setFraction(0.5)")
    assert slider.property("value") == 0.5 and win.property("moved") == 1, tag
    h.eval(slider, "setFraction(1.7)")
    assert slider.property("value") == 1, tag
    vs = get("vslider")
    assert vs.property("implicitHeight") > vs.property("implicitWidth"), tag
    assert get("progress").property("height") == space("stroke"), tag
    assert get("ring").property("fraction") == 0.4, tag

    # Surface: the popup box with the standard padding around its content
    surf = get("surface")
    assert surf.property("variant") == "popup" and surf.property("padding") == space("l"), tag
    assert surf.property("implicitWidth") == 100 + 2 * space("l"), (tag, surf.property("implicitWidth"))
    assert surf.property("radius") == space("surfaceRadius"), tag

print("kit: ok")
