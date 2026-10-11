"""The AI bar's conversation column is centred on the whole bar, also next to the docked history."""
import os
import sys
from pathlib import Path

os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QObject, QUrl, QCoreApplication, QElapsedTimer  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

app = QGuiApplication.instance() or QGuiApplication(sys.argv)
repo = Path(__file__).resolve().parents[1]
root = aiscene.build('Yozakura Night', 'dark', (repo / 'tests/fixtures/aicenter-ai-stub.qml.in').read_text())


def pump(ms=200):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def composer_center(width, wide, fullscreen):
    scene = root / f'Layout_{width}_{wide}_{fullscreen}.qml'
    scene.write_text('''import QtQuick
import qs.modules.aicenter
import qs.modules.globals
Item {
    width: %d; height: 860
    AiCenterPanel { id: panel; anchors.fill: parent }
    Component.onCompleted: { GlobalStates.assistantWide = %s; GlobalStates.assistantFullscreen = %s; }
}''' % (width, wide, fullscreen))
    view = QQuickView()
    view.engine().addImportPath(str(root))
    view.resize(width, 860)
    view.setSource(QUrl.fromLocalFile(str(scene)))
    assert view.status() == QQuickView.Ready, view.errors()
    view.show()
    pump()
    composer = view.rootObject().findChild(QObject, 'workspaceComposer')
    assert composer
    item = composer
    x = 0.0
    while item is not None and item is not view.rootObject():
        x += item.property('x')
        item = item.parent()
    center = x + composer.property('width') / 2
    view.close()
    view.deleteLater()
    return center


c = composer_center(1700, 'false', 'true')
assert abs(c - 850) < 2, f'fullscreen column must be centred on the bar, got {c}'
c = composer_center(404, 'false', 'false')
assert abs(c - 202) < 2, f'compact column must be centred, got {c}'
print('ai-center-layout: ok')
