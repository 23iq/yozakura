"""The AI center's look knobs sit on the kit tokens.

The real BarLook and AiText over stub kit tokens: the density picks a step
of the Space scale (gap / groupGap / pad), text sizes are the Type roles
scaled by ai.appearance.fontScale (clamped to 0.6..2, never under 8 px),
the mono size follows the theme's mono / body ratio, and AiText applies
them (the mono face with `mono: true`).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-barlook")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 200
    property QtObject theme: QtObject { property int fontSize: 14; property int monoFontSize: 12 }
    property QtObject ai: QtObject {
        property bool showThinking: true
        property var appearance: ({density: "comfortable", fontScale: 1.5})
        property var behavior: ({})
    }
}""")
h.module("qs.modules.components.kit", {
    "Space": "pragma Singleton\nQtObject { property int xs: 4; property int s: 8; property int m: 12; property int l: 16 }",
    "Type": "pragma Singleton\nQtObject { property string monoFont: 'Mono'; "
            "readonly property var scale: ({body: 1, secondary: 0.93, caption: 0.86, title: 1.3}); "
            "function size(r) { return Math.max(8, Math.round(14 * (scale[r] || 1))) } function family(r) { return 'Sans' } }",
    "KitText": "Text { property string role: 'body' }",
})
h.copy("modules/aicenter/common/BarLook.qml", "qs/modules/aicenter/common", siblings=False)
h.copy("modules/aicenter/common/AiText.qml", "qs/modules/aicenter/common", siblings=False)
h.module("qs.modules.aicenter.common", {})
root = h.load("""import QtQuick
import qs.config
import qs.modules.aicenter.common
Item {
    property var look: BarLook
    AiText { objectName: "caption"; role: "caption"; text: "x" }
    AiText { objectName: "mono"; role: "caption"; mono: true; text: "x" }
}""", auto_stub=False)


def ev(expr):
    return h.eval(root, expr)


assert ev("look.gap") == 8 and ev("look.groupGap") == 16 and ev("look.pad") == 12, "comfortable density: s / l / m"
assert ev('look.size("caption")') == 18, "caption 12 px at 1.5x"
assert ev('look.size("body")') == 21
assert ev('look.monoSize("caption")') == 15, "mono: 12 * 12/14 * 1.5"
caption = h.find(root, "caption")
mono = h.find(root, "mono")
assert h.eval(caption, "font.pixelSize") == 18 and h.eval(caption, "font.family") == "Sans"
assert h.eval(mono, "font.pixelSize") == 15 and h.eval(mono, "font.family") == "Mono"

ev('Config.ai.appearance = ({density: "compact", fontScale: 9})')
assert ev("look.gap") == 4 and ev("look.groupGap") == 12 and ev("look.pad") == 8, "compact density: xs / m / s"
assert ev('look.size("body")') == 28, "fontScale is clamped to 2"
ev('Config.ai.appearance = ({fontScale: 0.1})')
assert ev('look.size("caption")') == 8, "never under 8 px (12 * 0.6 = 7)"
print("ai-barlook: ok")
