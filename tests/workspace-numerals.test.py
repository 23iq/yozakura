"""Workspace number label offscreen: numeral systems, optical fit and fonts.

Checks the label text per numeral system, that optically fitted labels stay
inside their fit box and centered on the slot, that long labels are
condensed, and how NumeralFonts picks the font (override, probe result).
"""
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import REPO, Harness  # noqa: E402
from PySide6.QtCore import QCoreApplication  # noqa: E402

SLOT = 28
PROBE = "file:/shell/assets/fonts/workspaces/kanji.subset.ttf\\nNoto Serif CJK JP,Noto Serif CJK JP Bold\\nNoto Sans CJK KR\\nNoto Sans CJK JP,Noto Sans CJK JP Black"

h = Harness("workspace-numerals")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property int fontSize: 14 }
    property QtObject workspaces: QtObject { property string numeralStyle: "arabic"; property string numeralFont: "" }
}""")
h.module("Quickshell", {
    "Quickshell": "pragma Singleton\nQtObject { property string shellDir: '/shell' }",
    "Singleton": "Item {}",
})
h.module("Quickshell.Io", {
    "StdioCollector": "QtObject { property string text; signal streamFinished() }",
    "Process": """QtObject {
    id: p
    property var command: []
    property bool running: false
    property int runs: 0
    property QtObject stdout
    signal exited(int exitCode, int exitStatus)
    onRunningChanged: if (running) Qt.callLater(function() {
        p.runs++;
        p.stdout.text = "%s";
        p.stdout.streamFinished();
        p.running = false;
        p.exited(0, 0);
    })
}""" % PROBE,
})
fonts = h.copy("modules/services/NumeralFonts.qml", dest="qs/modules/services")
h._write_qmldir(fonts.parent, "qs.modules.services")
label_qml = h.copy("modules/bar/workspaces/WorkspaceNumberLabel.qml", siblings=False)
# The registry is shared by both copies; copy() only copies a file once.
shutil.copy(REPO / "modules/bar/workspaces/WorkspaceNumerals.js", label_qml.parent)
root = h.load(f"""import QtQuick
import qs.config
import qs.modules.services
Item {{
    width: {SLOT}; height: {SLOT}
    WorkspaceNumberLabel {{ objectName: "label"; anchors.fill: parent; workspaceId: 3; color: "white" }}
}}""", auto_stub=False)
label = h.find(root, "label")
# Evaluate inside the label's own context so its ids (root, label) resolve.
inner = next(c for c in label.children() if c.metaObject().className().startswith("QQuickText_"))

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + str(detail) if detail else ""))


def ev(expr, obj=inner):
    return h.eval(obj, expr)


def settle():
    for _ in range(5):
        QCoreApplication.processEvents()


def show(style, n):
    ev(f'Config.workspaces.numeralStyle = "{style}"')
    ev(f"root.workspaceId = {n}")
    settle()
    # Ink box of the drawn text in slot coordinates, condensing included.
    x, y, w, hgt, condense = (ev(e) for e in (
        "label.x + label.ink.x + label.ink.width / 2 * (1 - root.fitting.condense)",
        "label.y + label.baselineOffset + label.ink.y",
        "label.ink.width * root.fitting.condense", "label.ink.height", "root.fitting.condense"))
    return ev("root.text"), (x, y, w, hgt), condense


text, _, _ = show("arabic", 3)
check("arabic keeps digits", text == "3", text)
check("arabic keeps the legacy metrics", not ev("root.optical") and ev("label.font.pixelSize") == 14)

for style, n, want in (("kanji", 3, "三"), ("kanji", 11, "十一"), ("kanji", 20, "二十"),
                       ("roman", 4, "IV"), ("roman", 8, "VIII"), ("roman", 18, "XVIII")):
    text, (x, y, w, hgt), condense = show(style, n)
    fit = ev("root.fit")
    fit = {k: fit.property(k).toNumber() for k in ("width", "height")}
    check(f"{style} {n} text", text == want, text)
    check(f"{style} {n} ink fits the box", w <= SLOT * fit["width"] + 0.5 and hgt <= SLOT * fit["height"] + 1.5,
          f"{w:.1f}x{hgt:.1f}")
    cx, cy = x + w / 2, y + hgt / 2
    check(f"{style} {n} optically centered", abs(cx - SLOT / 2) <= 1 and abs(cy - SLOT / 2) <= 1, f"({cx:.1f}, {cy:.1f})")
    if len(want) >= 4 or (style == "kanji" and len(want) >= 2):
        check(f"{style} {n} condensed", condense < 1, condense)

# Font choice: the probe ran once for kanji; the bundled file is not loadable
# here, so the preferred (sans, never serif) family wins at a heavy weight;
# the override beats everything.
ev('Config.workspaces.numeralStyle = "kanji"')
settle()
check("probe picked the Japanese gothic", ev('NumeralFonts.family("百")') == "Noto Sans CJK JP")
check("kanji label uses it", ev("root.fontFamily") == "Noto Sans CJK JP", ev("root.fontFamily"))
check("kanji label is heavy", ev("label.font.weight") >= 700, ev("label.font.weight"))
ev('Config.workspaces.numeralFont = "My Font"')
check("numeralFont overrides the auto font", ev("root.fontFamily") == "My Font")
ev('Config.workspaces.numeralFont = ""')
ev('Config.workspaces.numeralStyle = "roman"')
settle()
check("roman uses the theme font", ev("root.fontFamily") == "Sans")
ev('Config.workspaces.numeralStyle = "kanji"')
settle()
check("probe is cached per numeral system", ev("JSON.stringify(Object.keys(NumeralFonts.probes))") == '["kanji"]')
ev('Config.workspaces.numeralStyle = "nonsense"')
settle()
check("unknown style falls back to arabic", ev("root.text") == "18" and not ev("root.optical"))

sys.exit(0 if ok_all else 1)
