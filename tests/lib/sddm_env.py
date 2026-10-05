"""Run the SDDM theme (assets/sddm/<app>) outside the greeter, never on the
live session.

SDDM gives the theme context properties; they are stubbed here:
  * sddm         login()/suspend()/reboot()/powerOff() recorders, can*
                 flags, hostName, loginFailed/loginSucceeded/informationMessage
  * userModel    ListModel (name, realName, icon, needsPassword) + lastIndex
  * sessionModel ListModel (name) + lastIndex
  * keyboard     capsLock, layouts, currentLayout
  * config       the theme.conf keys (a dict; theme.conf parsed by read_conf)
  * primaryScreen

Import tests/lib/headless.py (or call headless.ensure) before this module.
Used by tests/sddm-theme.test.py and tools/render/sddm_render.py.
"""
from __future__ import annotations

import configparser
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickView

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "lib"))
import brand  # noqa: E402

THEME = REPO / "assets" / "sddm" / brand.APP_ID

STUBS = """
import QtQuick
QtObject {
    property QtObject sddm: QtObject {
        objectName: "sddm"
        property string hostName: "sakura"
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        property var logins: []
        property int powerOffs: 0
        signal loginFailed()
        signal loginSucceeded()
        signal informationMessage(string message)
        function login(user, password, session) { logins = logins.concat([[user, password, session]]) }
        function suspend() {}
        function reboot() {}
        function powerOff() { powerOffs++ }
    }
    property ListModel userModel: ListModel {
        objectName: "userModel"
        property int lastIndex: 0
        ListElement { name: "lazy"; realName: "Lazy"; icon: ""; needsPassword: true }
        ListElement { name: "guest"; realName: ""; icon: ""; needsPassword: true }
    }
    property ListModel sessionModel: ListModel {
        objectName: "sessionModel"
        property int lastIndex: 0
        ListElement { name: "Hyprland" }
        ListElement { name: "niri" }
    }
    property QtObject keyboard: QtObject {
        objectName: "keyboard"
        property bool capsLock: false
        property int currentLayout: 0
        property var layouts: [{ shortName: "us", longName: "English (US)" }, { shortName: "ru", longName: "Russian" }]
    }
}
"""

# Modules the styles import: load them on the main thread first. A module
# first imported by a Loader'd URL is loaded on the QML loader thread, whose
# warnings reach the Python message handler and wait for the GIL: deadlock.
PRELOAD = """
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
Item { TextField {} }
"""


def read_conf(path: Path) -> dict:
    """theme.conf [General] as {key: str} (quotes stripped, like SDDM)."""
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    cp.read_string(path.read_text())
    return {k: v.strip().strip('"') for k, v in (cp["General"].items() if cp.has_section("General") else [])}


class SddmEnv:
    def __init__(self, config: dict, *, size: tuple[int, int] = (1920, 1080), primary: bool = True,
                 theme: Path = THEME):
        self.app = QGuiApplication.instance() or QGuiApplication([])
        self.view = QQuickView()
        self.engine: QQmlEngine = self.view.engine()
        self._keep = []
        pre = QQmlComponent(self.engine)
        pre.setData(PRELOAD.encode(), QUrl())
        self._keep += [pre, pre.create()]
        comp = QQmlComponent(self.engine)
        comp.setData(STUBS.encode(), QUrl())
        self.stubs = comp.create()
        assert self.stubs is not None, comp.errors()
        self._keep.append(comp)
        ctx = self.engine.rootContext()
        for name in ("sddm", "userModel", "sessionModel", "keyboard"):
            obj = self.stubs.findChild(QObject, name)
            assert obj is not None, name
            ctx.setContextProperty(name, obj)
        ctx.setContextProperty("config", config)
        ctx.setContextProperty("primaryScreen", primary)
        self.view.setResizeMode(QQuickView.SizeRootObjectToView)
        self.view.resize(*size)
        self.view.setSource(QUrl.fromLocalFile(str(theme / "Main.qml")))
        errors = [e.toString() for e in self.view.errors()]
        assert self.view.rootObject() is not None, "Main.qml failed to load:\n" + "\n".join(errors)
        self.root = self.view.rootObject()
        self.view.show()
        self.view.requestActivate()

    def eval(self, expr: str):
        from PySide6.QtQml import QQmlExpression
        e = QQmlExpression(self.engine.contextForObject(self.root), self.root, expr)
        r = e.evaluate()
        assert not e.hasError(), e.error().toString()
        return r[0] if isinstance(r, tuple) else r

    def stub(self, expr: str):
        from PySide6.QtQml import QQmlExpression
        e = QQmlExpression(self.engine.contextForObject(self.stubs), self.stubs, expr)
        r = e.evaluate()
        assert not e.hasError(), e.error().toString()
        return r[0] if isinstance(r, tuple) else r
