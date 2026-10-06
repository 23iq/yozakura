"""Stale discovery responses cannot restore a disabled or replaced provider."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-model-catalog")
h.singleton("qs.config", "Config", "QtObject { property var ai: ({extraModels:[]}) }")
h.module("qs.modules.services", {
    "KeyStore": '''pragma Singleton
QtObject {
    property bool enabled: true
    property string endpoint: "http://old"
    function getKey(p) { return "" }
    function hasKey(p) { return p === "ollama" && enabled }
    function getEndpoint(p) { return p === "ollama" ? endpoint : "" }
}''',
    "Discovery": "pragma Singleton\nQtObject { property var requests: [] }",
})
path = h.copy("modules/services/ai/ModelCatalog.qml")
h.stub("HttpGet", '''import qs.modules.services
QtObject {
    property var callback
    function get(url, headers, cb) { callback=cb; Discovery.requests=Discovery.requests.concat([this]) }
    function finish(text) { callback(text,true) }
}''')
obj = h.load(path)
h.eval(obj, 'refresh(); KeyStore.enabled=false; refresh(); Discovery.requests[0].finish(\'{"models":[{"name":"old"}]}\')')
assert h.eval(obj, "apiModels.length") == 0, "disabled Ollama cannot return from an earlier request"
h.eval(obj, 'KeyStore.enabled=true; refresh(); KeyStore.endpoint="http://new"; refresh(); Discovery.requests[1].finish(\'{"models":[{"name":"old"}]}\')')
assert h.eval(obj, "apiModels.length") == 0, "previous endpoint cannot replace current discovery"
h.eval(obj, 'Discovery.requests[2].finish(\'{"models":[{"name":"new"}]}\')')
assert h.eval(obj, "apiModels[0].model") == "new"
assert h.eval(obj, "pending") == 0
print("ai-model-catalog: ok")
h.exit(0)
