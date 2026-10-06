"""Usage in the AI bar (sub-project D) on the real AiCenterPanel with the
real UsageService and a scripted BackendService (tests/lib/aiscene.py).

- The strip shows the session's tokens and cost (usage.session, then
  usage.updated events) and, for Claude Code / Codex, the fullest
  subscription window (`5h 85%`, amber from ai.usage.warnAt).
- The settings are pushed on connect (claudeLimits.enable, alerts.set).
- HTTP requests are recorded with provider/model/session/space.
- The Usage screen opens from the strip and the header, lists providers
  (hidden ones left out, models on expand), switches ranges and shows the
  subscription windows.
"""
import json
import os
import sys
from pathlib import Path

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import headless  # noqa: E402,F401
from lib import aiscene  # noqa: E402
from PySide6.QtCore import QCoreApplication, QElapsedTimer, Qt, QUrl, qInstallMessageHandler  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlEngine, QQmlExpression  # noqa: E402
from PySide6.QtQuick import QQuickView  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
qInstallMessageHandler(lambda mode, ctx, msg: errors.append(msg) if ("aicenter" in msg and "Binding loop" not in msg and "aiproviders" not in msg) or "TypeError" in msg or "ReferenceError" in msg else None)

root = aiscene.build("Yozakura Night", "dark", (REPO / "tests/fixtures/aicenter-ai-stub.qml.in").read_text())
(root / "qs/modules/services/BackendService.qml").write_text("""pragma Singleton
import QtQuick
QtObject {
    property bool socketAvailable: true
    property var calls: []
    property var subs: []
    property var responses: ({})
    function call(m, p, cb) {
        calls = calls.concat([{method: m, params: p}]);
        const r = responses[m];
        if (cb)
            cb(typeof r === "function" ? r(p) : (r === undefined ? {} : r), null);
    }
    function addSubscription(services, cb) { subs = subs.concat([cb]); return subs.length; }
    function emit(service, data) { subs.forEach(cb => cb(service, data)); }
    function last(m) { const c = calls.filter(x => x.method === m); return c.length ? c[c.length - 1].params : null; }
}
""")
scene = root / "Usage.qml"
scene.write_text("""import QtQuick
import qs.modules.services
import qs.modules.aicenter
import qs.config
Item {
    width: 900; height: 760
    Component.onCompleted: {
        const rows = {
            provider: [
                {key: "anthropic", requests: 3, inputTokens: 30000, outputTokens: 2000, costUSD: 0.5, estimated: true},
                {key: "ollama", requests: 5, inputTokens: 9000, outputTokens: 900, costUSD: 0}
            ],
            model: [
                {key: "claude-sonnet-4-5", provider: "anthropic", requests: 3, inputTokens: 30000, outputTokens: 2000, costUSD: 0.5, estimated: true},
                {key: "qwen3", provider: "ollama", requests: 5, inputTokens: 9000, outputTokens: 900, costUSD: 0}
            ],
            provider_day: [
                {key: "2026-10-05", provider: "anthropic", requests: 1, inputTokens: 100, outputTokens: 1},
                {key: "2026-10-06", provider: "anthropic", requests: 2, inputTokens: 300, outputTokens: 1}
            ]
        };
        BackendService.responses = {
            "usage.session": p => ({sessionId: p.sessionId, totals: {requests: 2, inputTokens: 12000, outputTokens: 400, costUSD: 0.12, estimated: true}}),
            "usage.summary": p => ({range: p.range, groupBy: p.groupBy, from: new Date(2026, 9, 5).toISOString(), to: new Date(2026, 9, 12).toISOString(),
                                    totals: {}, rows: rows[p.groupBy] || []}),
            "usage.info": {pricesOverride: "/home/user/.config/yozakura/ai-prices.json", ledgerDir: "/home/user/.local/share/yozakura/usage"}
        };
    }
    AiCenterPanel { id: panel; anchors.fill: parent }
    function addChat() {
        Ai.chat.append({role: "user", content: "Plan my week"});
        Ai.chat.append({role: "assistant", content: "Sure."});
    }
    function calls(m) { return JSON.stringify(BackendService.calls.filter(c => c.method === m).map(c => c.params)); }
}
""")

view = QQuickView()
view.engine().addImportPath(str(root))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(900, 760)
view.setSource(QUrl.fromLocalFile(str(scene)))
assert view.status() == QQuickView.Ready, view.errors()
view.show()
top = view.rootObject()


def pump(ms=150):
    t = QElapsedTimer()
    t.start()
    while t.elapsed() < ms:
        QCoreApplication.processEvents()


def ev(expr, target=None):
    target = target or top
    e = QQmlExpression(QQmlEngine.contextForObject(target) or view.engine().rootContext(), target, expr)
    value = e.evaluate()
    assert not e.hasError(), f"{expr}: {e.error().toString()}"
    return value[0] if isinstance(value, tuple) else value


def find(name, item=None):
    item = item or view.contentItem()
    if item.objectName() == name:
        return item
    for child in item.childItems():
        hit = find(name, child)
        if hit is not None:
            return hit
    return None


def shown(name):
    obj = find(name)
    if obj is None:
        return False
    while obj is not None:
        if not obj.property("visible"):
            return False
        obj = obj.parentItem()
    return True


def click(obj):
    point = obj.mapToScene(obj.boundingRect().center())
    QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, point.toPoint())
    pump()


def slot_text(name):
    return find("usageSlotText", find(name)).property("text")


pump()
# ── settings pushed on connect ───────────────────────────────────────────
assert json.loads(ev("calls('usage.claudeLimits.enable')")) == [{"enabled": True}]
assert json.loads(ev("calls('usage.alerts.set')")) == [{"thresholds": [80, 90]}]
ev("Config.ai.usage.notify = false")
pump()
assert json.loads(ev("calls('usage.alerts.set')"))[-1] == {"thresholds": []}, "notifications off -> no thresholds"
ev("Config.ai.usage.notify = true")
ev("Config.ai.usage.claudeLimits = false")
pump()
assert json.loads(ev("calls('usage.claudeLimits.enable')"))[-1] == {"enabled": False}
ev("Config.ai.usage.claudeLimits = true")

# ── strip: HTTP chat cost, no subscription ───────────────────────────────
ev("addChat()")
pump()
assert shown("composerCost"), "the session cost shows"
assert slot_text("composerCost") == "12k · ≈ $0.12", slot_text("composerCost")
assert json.loads(ev("calls('usage.session')"))[0]["sessionId"] == ev("Ai.chat.chatId")
assert not shown("composerLimit"), "API models have no subscription window"
ev("Config.ai.usage.stripTokens = false")
pump()
assert slot_text("composerCost") == "≈ $0.12"
ev("Config.ai.usage.stripTokens = true")

# ── HTTP requests are recorded ───────────────────────────────────────────
ev("UsageService.recordHttp(Ai.models[1], {inputTokens: 100, outputTokens: 5, cachedTokens: 60}, 'c1')")
rec = json.loads(ev("JSON.stringify(BackendService.last('usage.record'))"))
assert rec == {"provider": "anthropic", "model": "claude-sonnet-4-5", "sessionId": "c1", "space": "assistant", "engine": "http",
               "inputTokens": 100, "outputTokens": 5, "cachedTokens": 60}, rec
ev("UsageService.recordHttp(Ai.models[1], {inputTokens: 40, outputTokens: 2}, 'c1', 'compaction')")
assert json.loads(ev("JSON.stringify(BackendService.last('usage.record'))"))["space"] == "compaction", "background requests keep their purpose"
n = len(json.loads(ev("calls('usage.record')")))
ev("UsageService.recordHttp(Ai.models[0], {inputTokens: 100, outputTokens: 5}, 'a')")  # agents record in the backend
ev("UsageService.recordHttp(Ai.models[1], {inputTokens: 0, outputTokens: 0}, 'c1')")
assert len(json.loads(ev("calls('usage.record')"))) == n

# ── strip: agent subscription limit ──────────────────────────────────────
ev("Ai.mode = 'agent'")
ev("""BackendService.emit('usage.limits', {provider: 'claude', limits: [{provider: 'claude', source: 'agent',
    windows: [{id: '5h', usedPercent: 85, resetsAt: new Date(Date.now() + 2 * 3600000 + 10 * 60000).toISOString()}, {id: 'week', usedPercent: 40}]}]})""")
pump()
assert shown("composerLimit"), "Claude Code shows its subscription window"
assert slot_text("composerLimit") == "5h 85%", slot_text("composerLimit")
assert find("composerLimit").property("level") == "warn"
assert "Resets in 2h 1" in find("composerLimit").property("detail"), find("composerLimit").property("detail")
ev("Config.ai.usage.limitWindow = 'week'")
pump()
assert slot_text("composerLimit") == "wk 40%"
assert find("composerLimit").property("level") == "ok"
ev("Config.ai.usage.limitWindow = 'auto'")
# usage.updated carries the new session totals
ev("BackendService.emit('usage.updated', {record: {sessionId: Ai.activeAgent.id}, session: {requests: 3, inputTokens: 50000, outputTokens: 1000, costUSD: 1.5}})")
pump()
assert slot_text("composerCost") == "51k · $1.50", slot_text("composerCost")
# a backend restart re-sends the snapshot without provider -> settings again
before = len(json.loads(ev("calls('usage.claudeLimits.enable')")))
ev("BackendService.emit('usage.limits', {limits: []})")
pump()
assert len(json.loads(ev("calls('usage.claudeLimits.enable')"))) == before + 1
assert not shown("composerLimit")
ev("""BackendService.emit('usage.limits', {provider: 'claude', limits: [{provider: 'claude', windows: [{id: '5h', usedPercent: 95}]}]})""")
pump()
assert find("composerLimit").property("level") == "critical"

# ── Usage screen ─────────────────────────────────────────────────────────
assert not shown("usageScreen")
click(find("composerLimit"))
pump(300)
assert shown("usageScreen"), "the strip opens the Usage screen"
assert find("headerUsage").property("active")
assert shown("usageProvider_anthropic") and shown("usageProvider_ollama")
assert find("usageTotalCost").property("text") == "≈ $0.50", find("usageTotalCost").property("text")
assert json.loads(ev("calls('usage.summary')"))[0] == {"range": "today", "groupBy": "provider"}
assert not any(c["groupBy"] == "provider_day" for c in json.loads(ev("calls('usage.summary')"))), "no sparklines for today"
assert shown("usageFootnote") and "Edit prices" in find("usageFootnote").property("text")
assert find("usageLimitPercent") is not None and find("usageLimitPercent").property("text") == "95%"
assert not shown("usageNoLimits")
if os.environ.get("AI_CENTER_RENDER"):
    view.grabWindow().save(str(Path(os.environ["AI_CENTER_RENDER"]) / "usage.png"))
# expand a provider: its models
click(find("usageProvider_anthropic"))
pump()
texts = []


def collect(item):
    if item.property("text") is not None:
        texts.append(item.property("text"))
    for c in item.childItems():
        collect(c)


collect(find("usageScreen"))
assert "claude-sonnet-4-5" in texts and "qwen3" not in texts, "expanding lists the provider's models"
# hide a provider
ev("Config.ai.usage.hiddenProviders = ['ollama']")
pump()
assert not shown("usageProvider_ollama"), "hidden providers are left out"
# range switch: week fetches per-day rows for sparklines
click(find("usageRange_week"))
pump(300)
summary_calls = json.loads(ev("calls('usage.summary')"))
assert {"range": "week", "groupBy": "provider_day"} in summary_calls, summary_calls
# new records refresh the screen
n = len(summary_calls)
ev("BackendService.emit('usage.updated', {record: {provider: 'openai'}})")
pump(300)
assert len(json.loads(ev("calls('usage.summary')"))) > n
# close; the header button toggles it
click(find("usageClose"))
assert not shown("usageScreen")
click(find("headerUsage"))
pump(200)
assert shown("usageScreen")
click(find("headerUsage"))
assert not shown("usageScreen")
# ── one overlay at a time: Connect replaces Usage and sits on top ───────
click(find("headerUsage"))
pump(200)
assert shown("usageScreen") and ev("panel.overlay") == "usage"
ev("Ai.connectProviderRequested('')")
pump(200)
assert ev("panel.overlay") == "connect", ev("panel.overlay")
assert not shown("usageScreen"), "opening Connect closes the Usage screen"
assert find("connectSheet").property("opened") and shown("connectSheet")
assert find("connectSheet").property("z") > find("usageScreen").property("z")
ev("panel.toggleOverlay('usage')")  # the sheet covers the header
pump(200)
assert ev("panel.overlay") == "usage" and shown("usageScreen")
assert not find("connectSheet").property("opened"), "another overlay closes the Connect sheet"
ev("panel.toggleHistory()")
pump(200)
assert ev("panel.overlay") == "history" and not shown("usageScreen")
ev("panel.closeOverlay('history')")
pump(200)
assert ev("panel.overlay") == ""
ev("Config.ai.usage.headerButton = false")
pump()
assert not shown("headerUsage")

pump(200)
assert not errors, "\n".join(errors)
print("ai-usage-ui: ok")
