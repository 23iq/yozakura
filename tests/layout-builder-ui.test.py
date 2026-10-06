"""Layout builder (modules/settings/layout/LayoutBuilder.qml), offscreen on
tests/lib/settings_env.py (real Config defaults, SettingsStore, ShellLayout
and LayoutModel): dragging the bar chip to the left edge writes
bar.position; dropping the notch on the shelf hides it (notch.enabled) and
the inspector notes where its activities went; a notch dropped on a side
edge is refused; the inspector switch shows it again and its style picker
writes notch.style. Nothing logs a QML error.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint, Qt, qInstallMessageHandler  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402

errors: list[str] = []


def _capture(_mode, _ctx, msg):
    if any(s in msg for s in ("TypeError", "ReferenceError", "is not a type", "Cannot assign", "Unable to assign",
                              "failed to load", "Error:", "is not installed", "unavailable")):
        errors.append(msg)


qInstallMessageHandler(_capture)

env = SettingsEnv("layout-builder", overrides={"theme": {"animDuration": 0}})
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import qs.config
import qs.modules.services
import qs.modules.settings.layout
import qs.modules.settings.store
Window {
    id: w
    width: 820; height: 860; visible: true; color: "#202020"
    function findItem(name, from) {
        var item = from || w.contentItem;
        if (item.objectName === name) return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) { var f = findItem(name, kids[i]); if (f) return f; }
        return null;
    }
    function get(k) { return JSON.stringify(SettingsStore.get(k)) }
    LayoutBuilder { objectName: "builder"; x: 20; y: 20; width: 760 }
}""")


def settle(ms: int = 120) -> None:
    QTest.qWait(ms)


def check(cond: bool, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        if errors:
            print("QML errors:\n  " + "\n  ".join(errors), file=sys.stderr)
        sys.exit(1)


def find(name: str):
    return h.eval(win, f"findItem({json.dumps(name)})")


def get(key: str):
    return json.loads(h.eval(win, f"get({json.dumps(key)})"))


def point(item, fx: float, fy: float) -> QPoint:
    p = h.eval(item, f"mapToItem(null, width * {fx}, height * {fy})")
    return QPoint(int(p.x()), int(p.y()))


def drag(p0: QPoint, p1: QPoint) -> None:
    QTest.mousePress(win, Qt.LeftButton, Qt.NoModifier, p0)
    for i in range(1, 11):
        QTest.mouseMove(win, QPoint(p0.x() + (p1.x() - p0.x()) * i // 10, p0.y() + (p1.y() - p0.y()) * i // 10))
        settle(15)
    QTest.mouseRelease(win, Qt.LeftButton, Qt.NoModifier, p1)
    settle(150)


settle(300)
screen = find("layoutPreviewScreen")
check(screen is not None, "the mock shows the screen")
for part in ("bar", "notch", "dock"):
    check(find("partChip_" + part) is not None, f"a chip per part: {part}")
check(get("bar.position") == "top", "default bar on top")

# Drag the bar to the left edge
drag(point(find("partChip_bar"), 0.5, 0.5), point(screen, 0.03, 0.5))
check(get("bar.position") == "left", f"bar dragged to the left: {get('bar.position')}")
bar = find("partChip_bar")
check(h.eval(bar, "vertical") is True, "the bar chip turns vertical")

# The notch refuses a side edge
drag(point(find("partChip_notch"), 0.5, 0.5), point(screen, 0.97, 0.5))
check(get("notch.position") == "top", "notch stays on a top/bottom edge")
check(get("notch.enabled") is True, "a refused drop changes nothing")

# Drop the notch on the shelf: hidden, and its activities go to the bar's
# corner (vertical bar)
drag(point(find("partChip_notch"), 0.5, 0.5), point(find("screenMockShelf"), 0.6, 0.5))
check(get("notch.enabled") is False, "notch hidden on the shelf")
inspector = find("partInspector")
check(h.eval(inspector, "part") == "notch", "the dragged part is selected")
check(h.eval(inspector, "notes.length") == 1, "the inspector notes the re-homed activities")
check(h.eval(find("screenMockCornerPill"), "visible") is True, "the corner pill shows in the mock")

# The inspector switch shows it again; the style picker writes notch.style
h.eval(find("partToggle"), "toggled(true)")
settle()
check(get("notch.enabled") is True, "switch shows the notch again")
h.eval(inspector, "edit('notch', 'style', 'pill')")
check(get("notch.style") == "pill", "style picker writes notch.style")

# Hiding the bar moves the clock and tray into the notch
h.eval(find("builder"), "apply('bar', 'enabled', false)")
settle()
check(get("bar.layout.style") == "none", "hiding the legacy bar writes style none")
check(json.loads(h.eval(win, "JSON.stringify(ShellLayout.notchSegments)")) == ["clock", "tray"], "clock and tray in the notch")

check(not errors, "QML errors:\n  " + "\n  ".join(errors))
print("layout-builder-ui: ok")
h.exit(0)
