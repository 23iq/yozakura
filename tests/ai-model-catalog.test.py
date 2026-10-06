"""Model catalog: Ollama models from the backend probe (real capabilities,
chat-only models; reachable = connected, no keystore opt-in), stale probes
ignored, the /api/tags fallback for daemons without the providers service,
LM Studio listed from its /models (reachability), hidden providers skipped,
and capability records from assets/ai/models.json for API models."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
TABLE = (REPO / "assets/ai/models.json").read_text()

h = Harness("ai-model-catalog")
h.singleton("qs.config", "Config", """QtObject {
    property QtObject ai: QtObject {
        property var extraModels: []
        property var agents: ({})
        property QtObject ollama: QtObject { property string endpoint: "" }
        property QtObject lmstudio: QtObject { property string endpoint: "" }
        property QtObject providers: QtObject { property var hidden: []; property int probeInterval: 0; property var customHeaders: [] }
    }
}""")
h.module("qs.modules.globals", {"GlobalStates": "pragma Singleton\nQtObject { property bool assistantVisible: false }"})
h.module("Quickshell", {"Quickshell": "pragma Singleton\nQtObject { property string shellDir: '/repo' }"})
h.module("Quickshell.Io", {"FileView": "QtObject { property string path; property bool printErrors; property string content; signal loaded; function text() { return content; } }"})
h.module("qs.modules.services", {
    "KeyStore": '''pragma Singleton
QtObject {
    property var keys: ({})
    function getKey(p) { return keys[p] || "" }
    function hasKey(p) { return false }
    function getEndpoint(p) { return "" }
}''',
    "BackendService": '''pragma Singleton
QtObject {
    property var calls: []
    function call(method, params, cb) { calls = calls.concat([{method: method, params: params, cb: cb}]) }
}''',
    "Discovery": "pragma Singleton\nQtObject { property var requests: [] }",
})
path = h.copy("modules/services/ai/ModelCatalog.qml")
h.stub("HttpGet", '''import qs.modules.services
QtObject {
    property var callback
    property string url
    function get(u, headers, cb) { url=u; callback=cb; Discovery.requests=Discovery.requests.concat([this]) }
    function finish(text) { callback(text,true) }
}''')
obj = h.load(path)

PROBE = {"endpoint": "http://127.0.0.1:11434", "reachable": True, "models": [
    {"id": "qwen3.5:9b", "name": "qwen3.5:9b", "sizeLabel": "9.7B", "quantization": "Q4_K_M", "contextLength": 262144,
     "capabilities": ["completion", "tools", "vision", "thinking"], "detailed": True},
    {"id": "gemma3:4b", "name": "gemma3:4b", "contextLength": 131072, "capabilities": ["completion", "vision"], "detailed": True},
    {"id": "nomic-embed-text", "name": "nomic-embed-text", "capabilities": ["embedding"], "detailed": True},
]}


def answer(i, result, err=""):
    h.eval(obj, f"BackendService.calls[{i}].cb({json.dumps(result)}, {json.dumps(err)})")


def last_request(part):
    n = h.eval(obj, "Discovery.requests.length")
    for i in range(n - 1, -1, -1):
        if part in h.eval(obj, f"Discovery.requests[{i}].url"):
            return i
    return -1


# The probe lists Ollama models with their real capabilities.
h.eval(obj, "refresh()")
assert h.eval(obj, "BackendService.calls[0].method") == "providers.ollama.probe"
answer(0, PROBE)
assert h.eval(obj, "apiModels.length") == 2, "embedding-only models are not chat models"
assert h.eval(obj, "find('ollama:qwen3.5:9b').info.contextWindow") == 262144
assert h.eval(obj, "find('ollama:qwen3.5:9b').tools") is True
assert h.eval(obj, "find('ollama:gemma3:4b').tools") is False, "no tools capability -> chat only"
assert h.eval(obj, "find('ollama:gemma3:4b').description") == "Ollama"
assert h.eval(obj, "find('ollama:qwen3.5:9b').description") == "9.7B · Q4_K_M"
assert h.eval(obj, "ollama.reachable") is True
assert h.eval(obj, "pending") == 1, "only the LM Studio listing is still running"

# Re-probing is throttled unless forced.
h.eval(obj, "probeOllama(false)")
assert h.eval(obj, "BackendService.calls.length") == 1, "a probe right after the last one is skipped"
h.eval(obj, "probeOllama(true)")
assert h.eval(obj, "BackendService.calls.length") == 2

# A probe for an old endpoint cannot replace the current list (changing
# the endpoint re-probes at once).
h.eval(obj, "Config.ai.ollama.endpoint = 'http://other:11434'")
calls = h.eval(obj, "BackendService.calls.length")
assert calls == 3 and h.eval(obj, "BackendService.calls[2].params.endpoint") == "http://other:11434"
answer(1, {"reachable": True, "models": []})
assert h.eval(obj, "apiModels.length") == 2, "stale endpoint result ignored"

# Old daemon (no providers service): /api/tags directly, no opt-in needed;
# reachable = connected.
h.eval(obj, "refresh()")
answer(3, None, "unknown method")
tags = last_request("/api/tags")
assert h.eval(obj, f"Discovery.requests[{tags}].url") == "http://other:11434/api/tags"
h.eval(obj, f'Discovery.requests[{tags}].finish(\'{{"models":[{{"name":"old"}}]}}\')')
assert h.eval(obj, "find('ollama:old') !== null")
assert h.eval(obj, "ollama.reachable") is True

# LM Studio: its /models listing (no key) is both list and reachability.
lm = last_request(":1234/v1/models")
assert lm >= 0, "LM Studio is probed on refresh"
assert h.eval(obj, f"Discovery.requests[{lm}].url") == "http://127.0.0.1:1234/v1/models"
h.eval(obj, f'Discovery.requests[{lm}].finish(\'{{"data":[{{"id":"qwen3-8b"}},{{"id":"text-embedding-nomic"}}]}}\')')
assert h.eval(obj, "lmstudio.reachable") is True
assert h.eval(obj, "find('lmstudio:qwen3-8b').kind") == "local"
assert h.eval(obj, "find('lmstudio:qwen3-8b').endpoint") == "http://127.0.0.1:1234/v1"
assert h.eval(obj, "find('lmstudio:text-embedding-nomic')") is None

# Hidden providers are neither probed nor listed.
h.eval(obj, "Config.ai.providers.hidden = ['ollama', 'lmstudio']; refresh()")
before = h.eval(obj, "BackendService.calls.length")
h.eval(obj, "refresh()")
assert h.eval(obj, "BackendService.calls.length") == before, "hidden Ollama is not probed"
assert h.eval(obj, "apiModels.length") == 0
assert h.eval(obj, "ollama.reachable") is False
h.eval(obj, "Config.ai.providers.hidden = []")

# API models get capability records from the bundled table once it loads.
h.eval(obj, "KeyStore.keys = ({openai: 'k'}); refresh()")
req = last_request("api.openai.com")
h.eval(obj, f'Discovery.requests[{req}].finish(\'{{"data":[{{"id":"gpt-5"}},{{"id":"gpt-4o"}}]}}\')')
assert h.eval(obj, "find('openai:gpt-5').info.contextWindow === undefined"), "no table yet"
h.eval(obj, f"tableFile.content = {json.dumps(TABLE)}; tableFile.loaded()")
assert h.eval(obj, "find('openai:gpt-5').info.contextWindow") == 400000
assert h.eval(obj, "find('openai:gpt-5').info.reasoning") == "openai_effort"
h.eval(obj, "refresh()")
req = last_request("api.openai.com")
h.eval(obj, f'Discovery.requests[{req}].finish(\'{{"data":[{{"id":"gpt-4o"}}]}}\')')
assert h.eval(obj, "find('openai:gpt-4o').info.contextWindow") == 128000, "fetched after the table: enriched at once"
print("ai-model-catalog: ok")
h.exit(0)
