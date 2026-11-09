"""The kit-literals audit counts kit-bypassing literals per directory and ratchets them."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "tools" / "audit"))
from checks import kit_literals as K  # noqa: E402

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


SRC = """import QtQuick
Item {
    spacing: 8
    anchors.leftMargin: 12
    Layout.topMargin: 4
    rowSpacing: Space.m
    padding: 0
    anchors.margins: -Look.boxPadding
    // spacing: 99 in a comment
    property string s: "spacing: 4"
    Rectangle { radius: Styling.radius(4) }
    delegate: Text { font.pixelSize: 13 }
    KitText { font.pixelSize: Type.size("body") }
    Text {
        font.pixelSize: Config.theme.fontSize - 2
    }
    StyledRect { radius: Styling.radius(0) }
    Item { x: Styling.radius(-4) + Styling.radius(+2) }
}
"""
c = K.count_text(SRC)
check(c["spacing"] == 3, f"numeric spacing / margins / padding, not 0, tokens, comments or strings: {c}")
check(c["rectangle"] == 1, f"raw Rectangle: {c}")
check(c["text"] == 2, f"raw Text, as a property value too: {c}")
check(c["font-size"] == 1 + 1, f"literal and theme-size arithmetic pixel sizes: {c}")
check(c["radius"] == 3, f"Styling.radius with a non-zero literal offset: {c}")

sources = {
    "modules/bar/A.qml": "Item {\n    spacing: 4\n}\n",
    "modules/bar/B.qml": "Item {\n    Text {}\n}\n",
    "modules/components/kit/Group.qml": "Item {\n    spacing: 4\n    Rectangle {}\n}\n",
    "modules/theme/Styling.qml": "Item {\n    Text {}\n}\n",
    "modules/notch/C.qml": "Item {\n    spacing: Space.s\n}\n",
}
r = K.analyze(sources)
check(r == {"modules/bar": {"spacing": 1, "text": 1}}, f"per directory, kit / theme exempt, zeros dropped: {r}")

new, better = K.compare(r, {"modules/bar": {"spacing": 1, "text": 1}})
check(new == [] and better == [], f"matching baseline is clean: {new} {better}")
new, _ = K.compare({"modules/bar": {"spacing": 2, "text": 1}, "modules/dock": {"text": 1}},
                   {"modules/bar": {"spacing": 1, "text": 1}})
check(any("modules/bar: spacing 2 > baseline 1" in m for m in new), f"growth fails: {new}")
check(any(m.startswith("modules/dock: text 1 > baseline 0") for m in new), f"a new directory fails: {new}")
new, better = K.compare({"modules/bar": {"spacing": 1}}, {"modules/bar": {"spacing": 1, "text": 3}})
check(new == [] and better == ["modules/bar: text 0 < baseline 3"], f"fixes only ask for a refresh: {new} {better}")

# The committed baseline matches the tree (the audit run in `make check` relies on it)
issues = K.run({})
check(not [i for i in issues if i.severity == "error"], f"tree within the baseline: {[i.message for i in issues]}")

if failures:
    print("\n".join("FAIL: " + f for f in failures))
    sys.exit(1)
print("kit-literals audit: counting, exemptions and ratchet passed")
