"""OverviewWindowFace (modules/widgets/overview): the window thumbnail shared by
the grid and scrolling overviews. Without a live preview (or, in the grid,
before the first frame) the plain box with the app icon shows; over a live
preview only the outline layer does (the scrolling view shows it only while
hovered / pressed / matched / selected). Hover and search matches take the
accent outline, the selected match the tertiary one at the stroke width plus
a soft glow; XWayland windows get a dot, and the tooltip names the title,
class and XWayland."""
import functools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.kit_env import KitEnv  # noqa: E402
from lib.settings_env import global_states_qml  # noqa: E402

SCENE = """import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.theme
import qs.modules.components.kit
Window {
    width: 300; height: 300; visible: true
    Item {
        x: 50; y: 80; width: 200; height: 120
        OverviewWindowFace {
            objectName: "face"
            windowData: ({ title: "Terminal", class: "kitty", xwayland: true })
            iconPath: "kitty"
        }
    }
}"""

FAILED = []


def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        FAILED.append(msg)


env = KitEnv("overview-window-face", overrides={"theme": {"animDuration": 0}})
h = env.h
# The overview is open (the live preview captures only then)
h.module("qs.modules.globals", {"GlobalStates": global_states_qml({}).replace(
    "property bool themeHasChanges", "property bool overviewOpen: true\n    property bool themeHasChanges")})
h.module("Quickshell.Wayland", {
    "ScreencopyView": "Item { property var captureSource: null; property bool live: false; property bool hasContent: false }",
})
h.copy("modules/widgets/overview/OverviewWindowFace.qml", siblings=False)
win = env.load(SCENE)
get = functools.partial(h.find, win)
ev = functools.partial(h.eval, win)
face, box, overlay, preview = get("face"), get("faceBox"), get("faceOverlay"), get("facePreview")


def shown(o):
    return bool(h.eval(o, "visible"))


def color(o, p):
    return h.eval(o, f"{p}.toString()")


# Grid (fallbackOnEmpty): the plain box until the preview has a frame
check(ev("Config.performance.windowPreview") is True, "the live preview is on by default")
check(shown(box) and not shown(overlay), "grid: the plain box while the preview has no frame")
preview.setProperty("hasContent", True)
check(not shown(box) and shown(overlay), "grid: the outline layer over a live frame")
check(h.eval(overlay, "border.width") == 0, "an idle window has no outline")

# Hover / match: the accent outline
face.setProperty("hovered", True)
check(h.eval(overlay, "border.width") > 0 and color(overlay, "border.color") == ev("Type.accent.toString()"),
      "a hovered window takes the accent outline")
face.setProperty("hovered", False)
face.setProperty("matched", True)
check(h.eval(overlay, "border.width") > 0, "a search match is outlined")

# Selected match: tertiary at the stroke width, with the glow
face.setProperty("selected", True)
face.setProperty("glow", True)
check(color(overlay, "border.color") == ev("Colors.tertiary.toString()"), "the selected match is tertiary")
check(h.eval(overlay, "border.width") == ev("Space.stroke"), "the selected match is drawn at the stroke width")
check(shown(get("faceGlow")), "the selected match glows")
face.setProperty("selected", False)
face.setProperty("glow", False)
face.setProperty("matched", False)

# Scrolling (no fallback on an empty preview): the outline only while it means something
face.setProperty("fallbackOnEmpty", False)
preview.setProperty("hasContent", False)
check(not shown(box) and not shown(overlay), "scrolling: nothing over an idle preview")
face.setProperty("pressed", True)
check(shown(overlay), "scrolling: the press wash over the preview")
face.setProperty("pressed", False)

# Preview off: the plain box everywhere, the icon in its middle
ev("Config.performance.windowPreview = false")
check(shown(box) and not shown(overlay), "without previews the plain box shows")

check(shown(get("faceXwayland")), "XWayland windows get their dot")
tip = get("faceTooltip")
check(not shown(tip), "the tooltip waits for the pointer")
face.setProperty("tooltipShown", True)
text = h.eval(get("faceTooltipText"), "text")
check(shown(tip) and "Terminal" in text and "[kitty]" in text and "[XWayland]" in text,
      f"the tooltip names title, class and XWayland: {text!r}")
win.close()

if FAILED:
    sys.exit(1)
print("overview-window-face: ok")
