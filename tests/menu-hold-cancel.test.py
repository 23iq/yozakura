"""Actual power menu styles cancel pending destructive holds on lifecycle changes.
Quickshell records commands; all windows use the offscreen harness.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from lib.menus_env import MenusEnv  # noqa: E402
from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = MenusEnv("menu-hold-cancel", overrides={"theme": {"animDuration": 0}})
h = env.h
root = env.load("""import QtQuick
import QtQuick.Window
import Quickshell
import qs.modules.widgets.powermenu.styles as Styles
Window {
    width: 1280; height: 720; visible: true
    property string page: "notch"
    property bool showing: true
    function holding(item) {
        var n = item.objectName === "holdRing" && item.holding ? 1 : 0;
        for (var child of item.children || []) n += holding(child);
        return n;
    }
    function ran() { return JSON.stringify(Quickshell.detached) }
    Item { objectName: "otherFocus"; focus: false }
    Styles.Notch { objectName: "notch"; visible: page === "notch" && showing; focus: page === "notch" }
    Styles.Radial { objectName: "radial"; anchors.fill: parent; visible: page === "radial" && showing;
        shown: page === "radial" && showing; focus: page === "radial" }
    Styles.Fullscreen { objectName: "full"; anchors.fill: parent; visible: page === "full" && showing;
        shown: page === "full" && showing; focus: page === "full" }
}""")
root.requestActivate()
QTest.qWait(50)

for page, name in [("notch", "powerStrip"), ("radial", "radial"), ("full", "full")]:
    root.setProperty("page", page)
    root.setProperty("showing", True)
    QTest.qWait(50)
    host = h.find(root, name)
    if page == "radial":
        host = h.eval(host, "children.find(c => typeof c.itemAt === 'function')")
    for cancel in ["navigate", "selection", "focus", "hide", "dismiss"] + ([] if page == "notch" else ["shown"]):
        root.setProperty("showing", True)
        h.eval(host, "forceActiveFocus()")
        QTest.qWait(30)
        if page == "full":
            h.eval(host, "focusAt(5)")
        else:
            h.eval(host, "forceActiveFocus(); currentIndex = 5")
        QTest.qWait(30)
        QTest.keyPress(root, Qt.Key_Return)
        QTest.qWait(80)
        assert h.eval(root, "holding(contentItem)") == 1, (page, cancel, "hold did not start")
        if cancel == "navigate":
            QTest.keyClick(root, Qt.Key_Left)
        elif cancel == "selection":
            h.eval(host, "focusAt(4)" if page == "full" else "currentIndex = 4")
        elif cancel == "focus":
            h.eval(h.find(root, "otherFocus"), "forceActiveFocus()")
        elif cancel == "hide":
            root.setProperty("showing", False)
        elif cancel == "shown":
            h.eval(h.find(root, page), "shown = false")
        else:
            QTest.keyClick(root, Qt.Key_Escape)
        QTest.keyRelease(root, Qt.Key_Return)
        QTest.qWait(650)
        assert json.loads(h.eval(root, "ran()")) == [], (page, cancel, h.eval(root, "ran()"))

print("menu-hold-cancel: ok")
h.exit(0)
