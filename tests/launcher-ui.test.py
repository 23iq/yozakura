"""Launcher (modules/widgets/launcher) behaviour, offscreen: provider routing
and merged results, keyboard activation, options, Tab to AI, commands,
prefix tabs, async file results and provider settings (order / disabled)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from launcher_env import LauncherEnv  # noqa: E402

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

env = LauncherEnv("launcher-ui")
h = env.h
win = env.load("""
import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import qs.modules.widgets.launcher
Window {
    width: 520; height: 340; visible: true; color: "black"
    LauncherView { objectName: "view"; anchors.fill: parent }
}""")
view = h.find(win, "view")
results = h.find(win, "launcherResults")
search = h.find(win, "launcherSearch")
fails: list[str] = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("FAIL:", msg, file=sys.stderr)


def settle(ms=60):
    QTest.qWait(ms)


def type_text(t):
    h.eval(view, f"GlobalStates.launcherSearchText = {json.dumps(t)}")
    settle()


def items():
    return json.loads(h.eval(search, "JSON.stringify(items.map(i => ({p: i.provider, t: i.title, k: i.key, inert: !!i.inert})))"))


def search_view(expr):
    return h.eval(search, "(function(v){ return " + expr + " })(this)")


settle(200)

# Empty search: every app, nothing selected.
rows = items()
check(len(rows) == 10 and all(r["p"] == "apps" for r in rows), f"empty search lists apps: {rows}")
check(search_view("v.selectedIndex") == -1, "nothing selected on empty search")

# Mixed search: apps + AI row last, first row selected.
type_text("fire")
rows = items()
check([r["p"] for r in rows] == ["apps", "ai"], f"mixed 'fire' -> apps + ai: {rows}")
check(rows[0]["t"] == "Firefox", "firefox first")
check(search_view("v.selectedIndex") == 0, "first row selected")

# Calculator in mixed search comes first (configured order).
type_text("12*7")
rows = items()
check(rows and rows[0]["p"] == "calculator" and rows[0]["t"] == "= 84", f"calc first: {rows}")
type_text("5 kg in lb")
rows = items()
check(rows and rows[0]["t"].startswith("= 11.0231"), f"unit conversion: {rows[:1]}")
type_text("100 usd in rub")
settle(100)
rows = items()
check(rows and rows[0]["p"] == "calculator" and "RUB" in rows[0]["t"], f"currency conversion: {rows[:1]}")

# Enter on the calculator copies the result and closes.
h.eval(view, "Quickshell.detached = []")
type_text("= 6*7")
search_view("v.runSelected()")
detached = json.loads(h.eval(view, "JSON.stringify(Quickshell.detached)"))
check(["wl-copy", "--", "42"] in detached, f"calc copies 42: {detached}")
check(h.eval(view, "Visibilities.module") == "", "launcher closes after copy")
h.eval(view, 'Visibilities.module = "launcher"')

# Commands: prefix lists all, args complete, run goes through GlobalShortcuts.
type_text(">")
rows = items()
check(len(rows) > 10 and all(r["p"] == "commands" for r in rows), f"> lists commands: {len(rows)}")
type_text("> dnd")
search_view("v.runSelected()")
settle()
check("dnd-toggle" in json.loads(h.eval(view, "JSON.stringify(GlobalShortcuts.ran)")), "> dnd runs dnd-toggle")
h.eval(view, 'Visibilities.module = "launcher"')
type_text("> random wallpaper")
check(items()[0]["k"] == "wallpaper:random", f"random wallpaper parsed: {items()[:1]}")
type_text("> pre")
check(items()[0]["k"] == "preset:", f"'> pre' offers preset: {items()[:2]}")
search_view("v.tab()")
settle()
check(h.eval(view, "GlobalStates.launcherSearchText") == ">preset ", "Tab completes '> pre' to '>preset '")
rows = items()
check(any(r["k"] == "preset:Neon Tokyo" for r in rows), f"preset choices listed: {rows}")
h.eval(view, "Quickshell.detached = []")
type_text("> preset neon")
search_view("v.runSelected()")
detached = json.loads(h.eval(view, "JSON.stringify(Quickshell.detached)"))
check(["yozakura", "preset", "apply", "Neon Tokyo"] in detached, f"preset applies via CLI: {detached}")
h.eval(view, 'Visibilities.module = "launcher"')
h.eval(view, "Quickshell.detached = []")
type_text("> glass 0.6")
search_view("v.runSelected()")
detached = json.loads(h.eval(view, "JSON.stringify(Quickshell.detached)"))
check(["yozakura", "config", "set", "theme.glass.amount", "0.6"] in detached, f"glass via config set: {detached}")
h.eval(view, 'Visibilities.module = "launcher"')
type_text("> glass 7")
check(not search_view("v.items[0].data.check.ok"), "glass 7 out of range")

# AI: '?' prefix and Tab in mixed search.
type_text("?why is the sky blue")
search_view("v.runSelected()")
settle()
check(json.loads(h.eval(view, "JSON.stringify(Ai.asked)")) == ["why is the sky blue"], "? prefix asks AI")
h.eval(view, 'Visibilities.module = "launcher"')
type_text("what is a monad")
search_view("v.tab()")
settle()
check(json.loads(h.eval(view, "JSON.stringify(Ai.asked)"))[-1] == "what is a monad", "Tab asks AI")
h.eval(view, 'Visibilities.module = "launcher"')

# Apps: Enter launches + records usage; Shift+Enter options; pin option.
type_text("kitty")
search_view("v.runSelected()")
check(json.loads(h.eval(view, "JSON.stringify(AppSearch.launched)"))[-1] == "kitty", "Enter launches app")
check("kitty" in json.loads(h.eval(view, "JSON.stringify(UsageTracker.used)")), "usage recorded")
h.eval(view, 'Visibilities.module = "launcher"')
type_text("kitty")
search_view("v.expand(0)")
check(search_view("v.expandedOptions.length") == 3, "app options expanded")
search_view("v.optionIndex = 1")
search_view("v.runSelected()")
check(json.loads(h.eval(view, "JSON.stringify(TaskbarApps.pinned)")) == ["kitty"], "pin option pins")
check(search_view("v.expandedIndex") == -1, "options collapse after run")

# Files: prefix routes, async output parsed (home-scoped, excludes applied).
type_text("ff notes")
files = h.eval(search, "resultsHost.providers.files")
h.eval(files, "detected = true; tools = ({fd: 'fd'})")
type_text("ff notesx")
type_text("ff notes")
QTest.qWait(260)
home = env.home
out = "\\n".join([f"f\\t{home}/Documents/notes.md", f"d\\t{home}/notes", f"f\\t{home}/.git/notes", "f\\t/etc/notes"])
h.eval(files, f'proc.stdout.text = "{out}"; proc.stdout.streamFinished()')
settle()
rows = items()
check([r["t"] for r in rows] == ["notes", "notes.md"], f"file results: {rows}")

# Wallpapers prefix: random row first.
type_text("ww ")
rows = items()
check(rows and rows[0]["p"] == "wallpapers", f"ww routes to wallpapers: {rows[:1]}")

# Prefix tabs: "cc " switches to the clipboard tab, Backspace comes back.
type_text("cc ")
check(h.eval(view, "currentTab") == 1, "cc switches to clipboard tab")
h.eval(view, "leaveTab(1)")
settle()
check(h.eval(view, "currentTab") == 0 and h.eval(view, "GlobalStates.launcherSearchText") == "cc ", "backspace returns with prefix")
check(h.eval(view, "currentTab") == 0, "stays on search while prefixDisabled")
type_text("")

# Settings: a disabled provider drops out; order changes the merge order.
# (The generated Config holds prefix.launcher as one object: replace it.)
h.eval(view, 'Config.prefix.launcher = Object.assign({}, Config.prefix.launcher, {disabled: ["ai"]})')
type_text("fire")
check("ai" not in [r["p"] for r in items()], "disabled ai provider hidden")
h.eval(view, 'Config.prefix.launcher = Object.assign({}, Config.prefix.launcher, {disabled: []})')
h.eval(view, 'Config.prefix.launcher = Object.assign({}, Config.prefix.launcher, {order: ["ai", "apps"]})')
type_text("firef")
check([r["p"] for r in items()][:2] == ["ai", "apps"], f"order respected: {items()}")

# Esc closes but keeps the query (and its results) through the close
# animation; the reset is deferred instead of flashing the full app list.
h.eval(view, 'Visibilities.module = "launcher"; currentTab = 0')
type_text("fire")
h.eval(view, "focusSearchInput()")
settle(120)
QTest.keyClick(win, Qt.Key_Escape)
settle()
check(h.eval(view, "Visibilities.module") == "", "Esc closes the launcher")
check(h.eval(view, "GlobalStates.launcherSearchText") == "fire", "Esc keeps the query while closing")
check(h.eval(view, "GlobalStates.resetAfter") > 0, "Esc schedules the reset after the close animation")

if fails:
    print(f"{len(fails)} failure(s)", file=sys.stderr)
    h.exit(1)
print("launcher-ui: ok")
h.exit(0)
