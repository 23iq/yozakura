"""Composed dashboard home (modules/widgets/dashboard/home/HomeView.qml),
offscreen with stub services.

The view loads with a Metrics-based size; each toggle chip calls the same
service as QuickControls (and reflects its state); the levels write the sink
volume and the brightness; the notification list
shows the intentional empty state, then a count, rows and Clear.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402

h = Harness("dashboard-home")
h.singleton("qs.config", "Config", """QtObject {
    property int animDuration: 0
    property QtObject theme: QtObject { property string font: "Sans"; property int fontSize: 14 }
    property QtObject bar: QtObject { property bool use12hFormat: false }
}""")
h.singleton("qs.modules.theme", "Colors", """QtObject {
    property color surface: "#171217"; property color overBackground: "#ebdfe7"
    property color outline: "#9a8d99"; property color overSurfaceVariant: "#d2c2cf"
    property color outlineVariant: "#4e434e"; property color surfaceContainerHigh: "#2e282e"
    property color primary: "#f5adff"; property color overPrimary: "#520e62"
}""")
h.singleton("qs.modules.theme", "Styling", """QtObject {
    function radius(n) { return Math.max(16 + n, 0) }
    function fontSize(n) { return 14 + n }
}""")
h.singleton("qs.modules.theme", "Metrics", """QtObject {
    property int rowHeight: 48; property int iconSize: 32; property int badgeHeight: 22; property int spacing: 8
    property int padding: 16; property int sheetW: 420; property int launcherLeftPanelW: 300; property int dashH: 430
    property int menuW: 160
}""")
h.singleton("qs.modules.theme", "Icons", """QtObject {
    property string font: "Sans"
    property string wifiHigh: "w"; property string wifiOff: "W"; property string bluetooth: "b"
    property string bluetoothOff: "B"; property string bluetoothConnected: "c"; property string moon: "m"
    property string caffeine: "k"; property string gameMode: "g"; property string musicNotes: "n"
    property string previous: "<"; property string next: ">"; property string play: "p"; property string pause: "P"
    property string bellZ: "z"; property string bell: "Z"; property string speakerHigh: "s"; property string speakerX: "S"; property string sun: "o"
}""")
h.singleton("qs.modules.services", "I18n", """QtObject {
    property string resolvedLanguage: "en"
    function t(k, a) { return a === undefined ? k : k + ":" + a }
}""")
h.singleton("qs.modules.services", "WeatherService", """QtObject {
    property bool dataAvailable: true; property real currentTemp: 12.6; property string weatherDescription: "Overcast"
}""")
h.singleton("qs.modules.services", "MprisController", """QtObject {
    property var activePlayer: null; property bool isPlaying: false
    property bool canGoPrevious: false; property bool canGoNext: false; property bool canTogglePlaying: false
    function previous() {} function next() {} function togglePlaying() {}
}""")
h.singleton("qs.modules.services", "NetworkService", """QtObject {
    property bool wifiEnabled: true; property string networkName: "Home-5G"; property int calls: 0
    function toggleWifi() { calls++; wifiEnabled = !wifiEnabled }
}""")
h.singleton("qs.modules.services", "BluetoothService", """QtObject {
    property bool enabled: true; property bool connected: true; property int calls: 0
    property var friendlyDeviceList: [{ "name": "Buds", "connected": true }]
    function initialize() {} function toggle() { calls++; enabled = !enabled }
}""")
h.singleton("qs.modules.services", "Notifications", """QtObject {
    property bool silent: false; property int cleared: 0
    property var list: []; property var groupsByAppName: ({}); property var appNameList: []
    function toggleDnd() { silent = !silent }
    function discardAllNotifications() { cleared++; list = []; groupsByAppName = {}; appNameList = [] }
}""")
h.singleton("qs.modules.services", "CaffeineClient", """QtObject {
    property bool inhibit: false; function toggle() { inhibit = !inhibit }
}""")
h.singleton("qs.modules.services", "GameModeClient", """QtObject {
    property bool toggled: false; function toggle() { toggled = !toggled }
}""")
h.singleton("qs.modules.services", "Audio", """QtObject {
    property QtObject sink: QtObject { property QtObject audio: QtObject { property real volume: 0.5; property bool muted: false } }
}""")
h.singleton("qs.modules.services", "Brightness", """QtObject {
    property bool syncBrightness: false
    property QtObject mon: QtObject {
        property var screen: ({ "name": "DP-1" }); property bool ready: true; property real brightness: 0.4
        function setBrightness(v) { brightness = v }
    }
    property var monitors: [mon]
}""")
h.singleton("qs.modules.services", "YozdService", "QtObject { property var focusedMonitor: ({ \"name\": \"DP-1\" }) }")
h.module("qs.modules.notifications", {"NotificationAppIcon": """Item {
    property var appIcon; property string appName; property var summary; property var image
    property real size; property real radius
}"""})
h.module("Quickshell.Widgets", {"ClippingRectangle": "Rectangle {}"})
h.module("qs.modules.components", {
    "StyledRect": "Rectangle { property string variant; property bool enableShadow; property color item: \"black\" }",
    "Separator": "Rectangle { property bool vert }",
    "PositionSlider": "Item { property var player; property bool useCustomColors; property color customProgressColor; property color customBackgroundColor }",
    "StyledSlider": "Item { property real value; property bool isDragging; property bool resizeParent; property bool tooltip; property color progressColor }",
})
h.module("qs.modules.widgets.dashboard.widgets.calendar", {"Calendar": "Item {}"})
h.copy("modules/widgets/dashboard/home/HomeView.qml")

win = h.load("""
import QtQuick
import QtQuick.Window
Window {
    width: 900; height: 500; visible: true
    HomeView { objectName: "home" }
}""", auto_stub=False)
home = h.find(win, "home")


def check(cond, what: str) -> None:
    if not cond:
        print("FAIL:", what, file=sys.stderr)
        sys.exit(1)


def ev(obj, expr: str):
    return h.eval(obj, expr)


QTest.qWait(50)
check(ev(home, "implicitWidth") > 0 and ev(home, "implicitHeight") >= 430, "sized from Metrics")

# Toggles: each chip calls its service and follows its state.
chips = {n: h.find(home, n) for n in ("wifiChip", "bluetoothChip", "silenceChip", "awakeChip", "gameChip")}
check(ev(chips["wifiChip"], "label") == "Home-5G" and ev(chips["wifiChip"], "active"), "wifi shows the SSID")
check(ev(chips["bluetoothChip"], "label") == "Buds", "bluetooth shows the connected device")
for name, state in (("wifiChip", "NetworkService.wifiEnabled"), ("bluetoothChip", "BluetoothService.enabled"),
                    ("silenceChip", "Notifications.silent"), ("awakeChip", "CaffeineClient.inhibit"),
                    ("gameChip", "GameModeClient.toggled")):
    before = ev(chips[name], state)
    ev(chips[name], "clicked()")
    after = ev(chips[name], state)
    check(before != after, name + " toggles its service")
    check(ev(chips[name], "active") == after, name + " follows the service state")
check(ev(chips["wifiChip"], "label") == "dashboard.home.wifi", "wifi off falls back to its name")

# Levels: the sliders write the sink volume and the monitor brightness.
vol = h.find(home, "volumeRow")
light = h.find(home, "lightRow")
check(abs(ev(vol, "level") - 0.5) < 1e-6 and abs(ev(light, "level") - 0.4) < 1e-6, "levels read the services")
ev(vol, "moved(0.8)")
ev(light, "moved(0.7)")
check(abs(ev(vol, "Audio.sink.audio.volume") - 0.8) < 1e-6, "volume written")
check(abs(ev(vol, "Brightness.mon.brightness") - 0.7) < 1e-6, "brightness written")

# Notifications: intentional empty state, then a count and rows, then Clear.
empty = h.find(home, "emptyState")
check(ev(empty, "visible"), "empty state shown with no notifications")
check(ev(h.find(home, "notifTitle"), "text") == "dashboard.home.notifications", "no count when empty")
check(not ev(h.find(home, "clearButton"), "visible"), "no Clear when empty")
ev(empty, """(function() {
    var a = { appName: "chat", summary: "Ann", body: "see you", appIcon: "", image: "" };
    var b = { appName: "notify-send", summary: "test", body: "1", appIcon: "", image: "" };
    Notifications.list = [a, b, b];
    Notifications.groupsByAppName = { "chat": { appName: "chat", notifications: [a] },
                                      "notify-send": { appName: "notify-send", notifications: [b, b] } };
    Notifications.appNameList = ["chat", "notify-send"];
})()""")
QTest.qWait(50)
check(not ev(empty, "visible"), "empty state hidden with notifications")
check(ev(h.find(home, "notifTitle"), "text") == "dashboard.home.notifications · 3", "count in the title")
check(ev(h.find(home, "notifList"), "count") == 2, "one row per group")
ev(h.find(home, "clearButton"), "children[0].clicked(null)")
check(ev(empty, "Notifications.cleared") == 1, "Clear discards all")
QTest.qWait(50)
check(ev(empty, "visible"), "empty state back after Clear")

print("dashboard-home: ok")
h.exit(0)
