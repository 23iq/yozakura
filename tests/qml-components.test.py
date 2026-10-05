"""Construct island QML offscreen with external shell services stubbed.

This checks QML type/loading errors, not live shell behavior or integration.
"""
import os, pathlib, tempfile, shutil
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401  (never a live window)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtCore import QUrl, QPointF, Qt
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
from PySide6.QtQml import QQmlExpression
app=QGuiApplication([])
repo=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='yozakura-components-') as tmp:
 p=pathlib.Path(tmp)
 def module(name, files):
  d=p/name.replace('.','/'); d.mkdir(parents=True)
  lines=['module '+name]
  for n, body in files.items():
   singleton=body.startswith('pragma Singleton')
   (d/(n+'.qml')).write_text(body)
   lines.append(('singleton ' if singleton else '')+n+' 1.0 '+n+'.qml')
  (d/'qmldir').write_text('\n'.join(lines))
  return d
 module('qs.config',{'Config':'''pragma Singleton
import QtQuick
QtObject { function resolveColor(c) { return c; } property QtObject performance: QtObject { property bool blurTransition: false }; property QtObject theme: QtObject { property QtObject srBg: QtObject { property var border: ["white", 1] } }; property int animDuration: 160; property bool showBackground: true; property int roundness: 12; property string notchTheme: "island"; property string notchPosition: "top"; property QtObject bar: QtObject { property string position: "top" }; property QtObject notch: QtObject { property bool disableHoverExpansion: false; property int hoverExpandDelay: 90; property int hoverCollapseDelay: 200; property int expandedMediaWidth: 440; property int expandedArtworkSize: 64; property int microphoneNoticeDuration: 1800; property int mediaAnimationDuration: 160; property string customText: "Yozakura"; property bool visualizer: true } }'''})
 module('qs.modules.theme',{
 'BarMetrics':(repo/'modules/theme/BarMetrics.qml').read_text(),
 'Styling':'''pragma Singleton
import QtQuick
QtObject { property string defaultFont: "Sans"; function fontSize(n) { return 14+n; } function radius(n) { return 12+n; } function srItem(n) { return "white"; } }''',
 'Colors':'''pragma Singleton
import QtQuick
QtObject { property color overBackground: "white"; property color criticalRed: "red"; property color primary: "blue"; property color tertiary: "green"; property color surfaceBright: "gray"; property color shadow: "black"; property color overSurfaceVariant: "silver"; property color error: "red"; property color green: "green"; property color red: "red"; property color yellow: "yellow" }''',
 'Icons':'''pragma Singleton
import QtQuick
QtObject { property string font: "Sans"; property string player: "P"; property string spotify: "S"; property string previous: "<"; property string next: ">"; property string play: "P"; property string pause: "II"; property string mic: "M"; property string micSlash: "X"; property string accept: "v"; property string copy: "c"; property string sync: "s"; property string downloadSimple: "d"; property string folder: "f"; property string cancel: "x"; property string stop: "S" }'''})
 module('qs.modules.services',{
 'I18n':'''pragma Singleton
import QtQuick
QtObject { function t(s) { return s; } }''',
 'MicrophoneStatus':'''pragma Singleton
import QtQuick
QtObject { property bool muted: false; property bool available: true; property bool noticeVisible: false; property string noticeScreen: "" }''',
 'MprisController':'''pragma Singleton
import QtQuick
QtObject { property var activePlayer: null; property var filteredPlayers: []; function setActivePlayer(p) {} }''',
 'Notifications':'''pragma Singleton
import QtQuick
QtObject { property var popupList: []; readonly property var notchPopupList: popupList; function showsOnScreen(n) { return true } }''',
 'Visibilities':'''pragma Singleton
import QtQuick
QtObject { property bool playerMenuOpen: false }''',
 'VoiceService':'''pragma Singleton
import QtQuick
QtObject { property bool panelOpen: false; property string panelScreen: "" }''',
 'CavaService':'''pragma Singleton
import QtQuick
QtObject { property bool available: true; property var values: [0.5, 1, 0.25]; property int consumerCount: 0; property var keys: ({}); function setConsumer(k, a) { if (!k) return; keys[k] = a; var n = 0; for (var x in keys) if (keys[x]) n++; consumerCount = n; } function levels(n) { var out = []; for (var i = 0; i < n; i++) out.push(values[i % values.length]); return out; } }'''})
 module('qs.modules.components',{
 'StyledRect':'''import QtQuick
Item { property string variant; property string glassSurface; property real radius; property bool enableBorder; property real backgroundOpacity; property bool animateRadius; property real topLeftRadius; property real topRightRadius; property real bottomLeftRadius; property real bottomRightRadius; property color item: "white" }''',
 'StyledSlider':'''import QtQuick
Item { property bool resizeParent; property bool wavy; property bool playing; property real wavyAmplitude; property real wavyFrequency; property real heightMultiplier; property color progressColor; property color backgroundColor; property bool smoothDrag; property bool scroll; property bool tooltip; property bool updateOnRelease; property bool isDragging: false; property real value: 0 }''',
 'Separator':'''import QtQuick
Item { property bool vert; width: 1; height: 10 }''',
 'StyledToolTip':'''import QtQuick
Item { property string tooltipText; property bool show }''',
 'BarPopup':'''import QtQuick
Item { property Item anchorItem; property var bar; property int contentWidth; property int contentHeight; property int popupPadding: 8; property bool isOpen: false; function toggle() { isOpen = !isOpen; } }'''})
 module('qs.modules.notch', {'NotchNotificationView':'''import QtQuick
Item { property bool isNavigating: false; property bool notchHovered: false; implicitHeight: 80 }'''})
 module('qs.modules.globals', {'GlobalStates': 'pragma Singleton\nimport QtQuick\nQtObject {}'})
 module('qs.modules.corners', {'RoundCorner': 'import QtQuick\nItem { enum CornerEnum { TopRight, BottomRight, TopLeft, BottomLeft } property int corner; property real size; property color color }'})
 # Live activities inside the notch: real components, stubbed service
 module('qs.modules.services.activities', {'ActivityService': '''pragma Singleton
import QtQuick
QtObject { property string presentation: "notch"; property var activities: []; property var tasks: []; property var privacy: []; property var transfers: []; property int count: 0; property bool showSpeed: true; function activate(a, b, s) {} function transferAction(t, a) {} function iconUrl(n) { return ""; } }'''})
 shutil.copy(repo/'modules/services/activities/TransferModel.js', p/'qs/modules/services/activities')
 module('Quickshell.Widgets', {'IconImage': 'import QtQuick\nImage { property real implicitSize }'})
 module('qs.modules.bar.activities', {n: (repo/'modules/bar/activities'/(n+'.qml')).read_text() for n in ['ActivityIndicator', 'ActivityRing']})
 notchActs = repo/'modules/widgets/defaultview/activities'
 d = module('qs.modules.widgets.defaultview.activities', {f.stem: f.read_text() for f in sorted(notchActs.glob('*.qml'))})
 shutil.copy(notchActs/'NotchActivities.js', d)
 children=p/'children'; children.mkdir()
 names=['NotchVisualizer','AlbumBackdrop','MediaTimeline','MediaTransportControls','ExpandedMedia','MediaSummary','IslandHeader','IslandNotifications','DefaultView']
 for n in ['Notch', 'NotchViewTransition']: shutil.copy(repo/'modules/notch'/(n+'.qml'), children)
 for n in names: shutil.copy(repo/'modules/widgets/defaultview'/(n+'.qml'),children)
 shutil.copy(repo/'modules/widgets/defaultview/IslandMedia.js',children)
 # Notch panels module; MediaPanel reaches ExpandedMedia through '..'
 dv=p/'qs/modules/widgets/defaultview'; dv.mkdir(parents=True, exist_ok=True)
 for f in children.iterdir(): shutil.copy(f, dv)
 panels_src=repo/'modules/widgets/defaultview/panels'
 module('qs.modules.widgets.defaultview.panels', {f.stem: f.read_text() for f in sorted(panels_src.glob('*.qml'))})
 shutil.copy(panels_src/'NotchPanels.js', dv/'panels')
 for n in ['UserInfo','NotificationIndicator']:
  (children/(n+'.qml')).write_text('import QtQuick\nItem { width: 20; height: 20 }')
 (children/'CompactPlayer.qml').write_text('import QtQuick\nItem { property var player; property bool notchHovered }')
 (children/'NotchSmoke.qml').write_text('import QtQuick\nNotch { defaultViewComponent: Component { Item { implicitWidth: 300; implicitHeight: 44 } } }')
 names += ['NotchViewTransition', 'NotchSmoke']
 engine=QQmlEngine(); engine.addImportPath(tmp)
 failed=False
 for n in names:
  c=QQmlComponent(engine,QUrl.fromLocalFile(str(children/(n+'.qml'))))
  obj=c.createWithInitialProperties({'player':None} if n in ['MediaTimeline','MediaTransportControls','ExpandedMedia','MediaSummary','IslandHeader'] else {})
  print(n+': '+('PASS' if obj else 'FAIL'))
  for e in c.errors(): print(e.toString())
  failed = failed or obj is None
 if failed: raise SystemExit(1)

 c=QQmlComponent(engine,QUrl.fromLocalFile(str(children/'DefaultView.qml')))
 view=c.create()
 def evaluate(obj, expression):
  e=QQmlExpression(engine.contextForObject(obj), obj, expression)
  result=e.evaluate()
  assert not e.hasError(), e.error().toString()
  return result[0] if isinstance(result, tuple) else result
 evaluate(view, 'MprisController.activePlayer = ({trackTitle: "Song", identity: "Player"})')
 evaluate(view, 'Notifications.popupList = [{id: 1}]')
 window=QQuickWindow(); window.resize(700, 500)
 view.setParentItem(window.contentItem()); view.setX(100); view.setY(100)
 window.show(); QTest.qWait(40)
 def move(item):
  point=item.mapToScene(item.boundingRect().center()).toPoint()
  QTest.mouseMove(window, point); QTest.qWait(350)
 header=evaluate(view, 'header')
 # The media summary is the widest Loader (activity segments are Loaders too)
 summary=max((i for i in header.childItems() if 'Loader' in i.metaObject().className()), key=lambda i: i.width())
 def move_badge():
  point=summary.mapToScene(QPointF(summary.width()-12, summary.height()/2)).toPoint()
  QTest.mouseMove(window, point); QTest.qWait(350)
  return point
 notification=evaluate(view, 'notificationSlot')
 move_badge()
 assert not view.property('mediaHoverExpanded'), 'selector badge must not open a collapsed player'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 assert evaluate(view, 'header.selectorOpen'), 'badge click must open player selector'
 assert not view.property('mediaHoverExpanded'), 'selector menu must not open a collapsed player'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(notification)
 assert not view.property('mediaHoverExpanded'), 'notification hover must not expand media'
 assert evaluate(view, 'notifications.hovered'), 'notification hover must enlarge notification'
 move(summary)
 assert view.property('mediaHoverExpanded'), 'player hover must expand media'
 assert evaluate(view, 'notifications.hovered'), 'player hover must also enlarge notification'
 move_badge()
 assert view.property('mediaHoverExpanded'), 'selector badge must keep an expanded player open'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(header.childItems()[0])
 assert view.property('mediaHoverExpanded'), 'selector menu must keep an already expanded player open'
 QTest.mouseClick(window, Qt.LeftButton, pos=move_badge()); QTest.qWait(350)
 move(evaluate(view, 'panelSlot'))
 assert view.property('mediaHoverExpanded'), 'expanded player controls must keep media open'
 move(header.childItems()[0])
 assert not view.property('mediaHoverExpanded'), 'user area must not keep media expanded'
 assert not evaluate(view, 'notifications.hovered'), 'user area must not enlarge notification'
 evaluate(view, 'MprisController.activePlayer = null')
 move(summary)
 assert not evaluate(view, 'notifications.hovered'), 'idle text without a player must not enlarge notifications'
 evaluate(view, 'MprisController.activePlayer = ({trackTitle: "Song", identity: "Player"})')
 evaluate(view, 'Notifications.popupList = []')
 move(summary)
 assert view.property('mediaHoverExpanded'), 'player must expand without notifications'
 window.close()

 # Visualizer registers with the shared cava service only while visible and playing.
 c=QQmlComponent(engine,QUrl.fromLocalFile(str(children/'NotchVisualizer.qml')))
 viz=c.createWithInitialProperties({'width': 40, 'height': 20})
 for e in c.errors(): print(e.toString())
 assert viz is not None
 cava=evaluate(viz, 'CavaService')
 count=lambda: cava.property('consumerCount')
 assert count()==0, 'paused visualizer must not run cava'
 viz.setProperty('playing', True)
 assert count()==1, 'playing visualizer must request cava'
 assert evaluate(viz, 'levels.length')==6
 viz.setProperty('shown', False)
 assert count()==0, 'hidden island must release cava'
 viz.setProperty('shown', True)
 evaluate(viz, 'Config.notch.visualizer = false')
 assert count()==0, 'disabled visualizer must release cava'
 evaluate(viz, 'Config.notch.visualizer = true')
 assert count()==1
 viz.deleteLater(); QTest.qWait(20)
 assert count()==0, 'destroyed visualizer must release cava'
 print('Notch visualizer: cava consumer gating passed')
 print('Island pointer routing: notification, player, controls, user area and no notifications passed')
