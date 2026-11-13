"""Nothing in the settings window moves on its own, offscreen.

* Open a tab: the geometry of every card, row and header part on screen is
  the same at the first shown frame, 200 ms, 1 s and 2 s later (async
  pictures and editors have their room reserved).
* Hover: moving the pointer over every row and card on screen changes no
  geometry (hover may light, never move).
(Resizing through the breakpoints: settings-resize.test.py.)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import headless  # noqa: E402

headless.ensure(gl=True)

from PySide6.QtCore import QPoint  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402,F401
from PySide6.QtTest import QTest  # noqa: E402
from settings_env import SettingsEnv  # noqa: E402
from settings_probe import window  # noqa: E402
from waits import wait_until  # noqa: E402

env = SettingsEnv("settings-stability", devices=True)
h = env.h
failures: list[str] = []


def check(ok: bool, what: str) -> None:
    if not ok:
        failures.append(what)
        print("FAIL:", what, file=sys.stderr)


win = env.load(window(env))
shell = h.find(win, "shell")

# geometry on screen: {name: [x, y, w, h]} (page items in page coordinates,
# so a scroll would not count as a move)
SNAP = """JSON.stringify((function () {
    var out = {};
    var host = find("settingsPage");
    var page = host ? host.item : null;
    ["backPill", "destinationTitle", "destinationTabs", "pageUndo"].forEach(n => {
        var it = find(n);
        if (it && shown(it)) out[n] = rect(it);
    });
    if (page) walk(page, x => {
        if (!x.visible) return false;
        var n = String(x.objectName);
        if (n.indexOf("settingsSection:") === 0 || n.indexOf("settingRow:") === 0 || n === "pageStage" || n === "heroHint") {
            var p = x.mapToItem(page.contentItem || page, 0, 0);
            if (p.y - (page.contentY || 0) < page.height)
                out[n] = [Math.round(p.x), Math.round(p.y), Math.round(x.width), Math.round(x.height)];
        }
    });
    return out;
})())"""


def snap() -> dict:
    return json.loads(h.eval(win, SNAP))


def diff(a: dict, b: dict) -> list[str]:
    out = []
    for k, v in a.items():
        if k in b and b[k] != v:
            out.append(f"{k} {v} -> {b[k]}")
    for k in b:
        if k not in a:
            out.append(f"{k} appeared")
    return out


TABS = ["bar", "notch", "appearance", "terminal", "network", "ai"]
for cat in TABS:
    h.eval(shell, f'select("{cat}")')
    check(env.wait_page(win), f"{cat}: page built")
    check(wait_until(lambda: h.eval(win, 'find("settingsPage").opacity * find("settingsPageView").opacity') == 1),
          f"{cat}: shown")
    first = snap()
    for ms in (200, 800, 1000):
        QTest.qWait(ms)
        moved = diff(first, snap())
        check(not moved, f"{cat}: moved by itself after the page showed: {moved[:4]}")
    # hover every row and card on screen
    before = snap()
    points = json.loads(h.eval(win, """JSON.stringify((function () {
        var pts = [];
        walk(find("settingsPage").item, x => {
            if (!x.visible) return false;
            var n = String(x.objectName);
            if ((n.indexOf("settingRow:") === 0 || n.indexOf("settingsSection:") === 0) && shown(x)) {
                var r = rect(x);
                if (r[1] + r[3] / 2 > 0 && r[1] + r[3] / 2 < w.height) pts.push([r[0] + r[2] / 2, r[1] + Math.min(r[3] / 2, 20)]);
            }
        });
        return pts;
    })())"""))
    for x, y in points[:40]:
        QTest.mouseMove(win, QPoint(int(x), int(y)))
        QTest.qWait(15)
    QTest.qWait(300)
    moved = diff(before, snap())
    check(not moved, f"{cat}: hover changed the layout: {moved[:4]}")
    QTest.mouseMove(win, QPoint(2, 2))


if failures:
    print(f"settings-stability: {len(failures)} failure(s)")
    h.exit(1)
print("settings-stability: ok")
h.exit(0)
