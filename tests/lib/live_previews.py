"""The real shell parts the settings stages preview (modules/settings/live:
the bar panels, the dock), for SettingsEnv: panels_env's import tree and
fixture desktop (workspaces, windows, tray, battery...) merged into the
settings harness, so a stage renders the shell's own bar exactly as
tools/render/panels_render.py does.

    live_previews.mirror(root)                  # after SettingsEnv._mirror
    services = live_previews.services(own)      # own stubs win, except YozdService
    modules = live_previews.quickshell(own)     # {module: {type: body}}
"""
from __future__ import annotations

import shutil
from pathlib import Path

from qmlharness import REPO

# Directories whose every QML gets a qmldir (the real bar and dock trees).
FULL_QMLDIRS = ["modules/bar", "modules/dock", "modules/corners", "modules/frame", "modules/components/preview",
                "modules/settings/live"]
# Trees the stages show beyond the bar's (the whole dock: DockContent).
EXTRA_DIRS = ["modules/dock"]
# Directories the settings harness already declares with a restricted type
# list: the bar's buttons are added to it.
EXTRA_TYPES = {
    "modules/widgets/dashboard": ["LauncherButton"],
    "modules/widgets/powermenu": ["PowerButton"],
}
# The screen previews are laid out on (LiveTarget): one 1920x1080 monitor.
SCREEN = ("DP-1", 1920, 1080)


def mirror(root: Path) -> None:
    """Copy the bar / dock trees panels_env uses into <root>/qs and write
    their qmldirs (the settings harness writes the rest)."""
    import panels_env  # (imports settings_env: loaded lazily)

    qs = root / "qs"
    for rel in panels_env.MIRROR_DIRS + EXTRA_DIRS:
        src = REPO / rel
        if src.is_dir():
            shutil.copytree(src, qs / rel, dirs_exist_ok=True)
    for rel in panels_env.MIRROR_FILES:
        src, dst = REPO / rel, qs / rel
        if src.is_file() and not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, dst)
    for rel, body in panels_env.OVERRIDES.items():
        (qs / rel).write_text(body)
    for top in FULL_QMLDIRS:
        base = qs / top
        if not base.is_dir():
            continue
        for d in sorted({p.parent for p in base.rglob("*.qml")}):
            _qmldir(d, ".".join(d.relative_to(root).parts))
    for rel, types in EXTRA_TYPES.items():
        d = qs / rel
        if d.is_dir():
            _qmldir(d, ".".join(d.relative_to(root).parts), only=types)


_PROBES: dict = {}


def wait_built(env, timeout_ms: float = 8000, settle_ms: float = 700) -> bool:
    """Wait until every live preview asked for is built (LiveGate's queue is
    empty), then `settle_ms` for the asynchronous parts and the pictures
    (snapshots) to land. For renders and tests that look at a stage."""
    from PySide6.QtTest import QTest
    from waits import wait_until

    probe = _PROBES.get(id(env))
    if probe is None:
        probe = env.load("import QtQuick\nimport qs.modules.components.preview\n"
                         "QtObject { function busy() { return LiveGate.queue.length > 0 || LiveGate.timer.running } }")
        _PROBES[id(env)] = probe
    ok = wait_until(lambda: env.h.eval(probe, "busy()") is False, timeout_ms=timeout_ms)
    QTest.qWait(int(settle_ms))
    return ok


_EXIT = {"code": 0, "installed": False}


def clean_exit(harness) -> None:
    """Leave through qmlharness.hard_exit with the test's own exit code.

    The live bar's modules (popup windows, timers) crash PySide's destructor
    pass at interpreter teardown (exit 139 after a passing test); like the
    tests that call h.exit, skip it. The code is the one sys.exit was given,
    1 after an uncaught exception, else 0."""
    if _EXIT["installed"]:
        return
    _EXIT["installed"] = True
    import atexit
    import sys

    import qmlharness

    real_exit, real_hook = sys.exit, sys.excepthook

    def _exit(code=0):
        _EXIT["code"] = code if isinstance(code, int) else (0 if code is None else 1)
        real_exit(code)

    def _hook(kind, value, tb):
        _EXIT["code"] = 1
        real_hook(kind, value, tb)

    sys.exit, sys.excepthook = _exit, _hook
    # registered last, so it runs first: the harness' own check runs in it
    def _leave():
        harness._check_type_errors()
        qmlharness.hard_exit(_EXIT["code"])

    atexit.register(_leave)


def _qmldir(d: Path, module: str, only: list[str] | None = None) -> None:
    lines = [f"module {module}"]
    for f in sorted(d.glob("*.qml")):
        if only is not None and f.stem not in only:
            continue
        single = f.read_text().lstrip().startswith("pragma Singleton")
        lines.append(f"{'singleton ' if single else ''}{f.stem} 1.0 {f.name}")
    (d / "qmldir").write_text("\n".join(lines) + "\n")


# Top-level Config properties the bar reads (like config/Config.qml), bound to
# the domains so a change in a test or a render follows.
CONFIG_EXTRA = """
    property bool barReady: true
    property bool dockReady: true
    property bool notchReady: true
    property bool workspacesReady: true
    property bool showBackground: theme.srBarBg.opacity > 0
    property string notchStyle: notch.style || (notch.theme === "island" ? "island" : "attached")
    property string notchTheme: notchStyle === "attached" ? "default" : "island"
    property string notchPosition: notch.position || "top"
    property QtObject pinnedApps: QtObject { property var apps: ["firefox", "kitty", "code", "org.gnome.Nautilus"] }
    function savePinnedApps() {}
"""


def icon_provider():
    """`image://icon/<name>` from the installed icon themes (panels_env)."""
    import panels_env

    return panels_env.IconProvider()


def services(own: dict) -> dict:
    """The bar's fixture services under the settings' own stubs (those win,
    but YozdService: the bar's fixture monitor and workspaces)."""
    import panels_env
    import panels_stubs

    out = {**panels_stubs.services(panels_env.icon_path), **own}
    out["YozdService"] = panels_stubs.services(panels_env.icon_path)["YozdService"]
    return out


def activities() -> dict:
    import panels_stubs

    return {"ActivityService": panels_stubs.ACTIVITY_SERVICE,
            "TimerActivity": "pragma Singleton\nQtObject { function attach(t) {} function detach(t) {} }"}


def quickshell(own: dict) -> dict:
    """panels_env's Quickshell stand-ins merged under the settings' own, with
    one screen in Quickshell.screens (the screen previews are laid out on)."""
    import panels_env
    import panels_stubs

    mods = {k: dict(v) for k, v in panels_stubs.quickshell_modules(panels_env.icon_path).items()}
    for module, types in own.items():
        mods.setdefault(module, {}).update(types)
    name, w, h = SCREEN
    qs = mods["Quickshell"]
    single = qs["Quickshell"].replace("property var screens: []; ", "")
    assert single.rstrip().endswith("}"), "Quickshell stub ends with its closing brace"
    qs["Quickshell"] = (single.rstrip()[:-1] +
                        f' property list<QtObject> screens: [ShellScreen {{ name: "{name}"; width: {w}; height: {h} }}] }}')
    return mods
