"""AiPanel's custom provider: endpoint and curl template persist in the keystore.

They used to be written to Config.ai.customEndpoint/customCurlTemplate, keys
that do not exist (guarded by `!== undefined`, so nothing was ever saved),
while ModelCatalog/Ai.qml read them from KeyStore.getEndpoint/getCustomCurl.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-panel")
h.module("qs.modules.services", {
    "KeyStore": """pragma Singleton
import QtQuick
QtObject {
    property var store: ({ "custom": { api_key: "k0", endpoint: "http://old", custom_curl: "" } })
    property var calls: []
    function getKey(p) { return store[p] ? store[p].api_key : ""; }
    function getEndpoint(p) { return store[p] ? store[p].endpoint : ""; }
    function getCustomCurl(p) { return store[p] ? store[p].custom_curl : ""; }
    function hasKey(p) { return getKey(p) !== ""; }
    function setKey(p, k, e, c) { calls = calls.concat([[p, k, e, c]]); var s = store; s[p] = { api_key: k, endpoint: e, custom_curl: c }; store = s; }
    function deleteKey(p) {}
}""",
    "I18n": "pragma Singleton\nimport QtQuick\nQtObject { function t(k) { return k; } }",
})
h.singleton("qs.config", "Config", "QtObject { property QtObject theme: QtObject { property string font: 'Sans' } }")
h.module("qs.modules.theme", {
    "Colors": "pragma Singleton\nimport QtQuick\nQtObject { property color overSurface; property color outline; "
              "property color success; property color overPrimary; property color overError }",
    "Styling": "pragma Singleton\nimport QtQuick\nQtObject { function radius(x) { return x; } "
               "function srItem(x) { return 'red'; } }",
})
h.module("qs.modules.components", {"StyledRect": "import QtQuick\nRectangle { property string variant }"})

h.copy("modules/widgets/config/AiPanel.qml")
root = h.load('import QtQuick\nItem { width: 600; height: 900; AiPanel { objectName: "p"; anchors.fill: parent } }')
# Evaluate inside AiPanel's own context (its ids) via its first child.
panel = h.find(root, "p").children()[0]
ok = True


def check(name, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + name + (" " + detail if detail else ""))


check("endpoint field shows the keystore value", h.eval(panel, "endpointInput.text") == "http://old")
h.eval(panel, "endpointInput.text = 'http://new/v1'; curlInput.text = 'curl {{ENDPOINT}}'; root.saveCustomProvider()")
calls = json.loads(h.eval(panel, "JSON.stringify(KeyStore.calls)"))
check("save keeps the stored key and writes endpoint + curl",
      calls == [["custom", "k0", "http://new/v1", "curl {{ENDPOINT}}"]], str(calls))
h.eval(panel, "root.saveCustomProvider()")
check("unchanged values are not re-saved", len(json.loads(h.eval(panel, "JSON.stringify(KeyStore.calls)"))) == 1)
h.eval(panel, "customKeyInput.text = 'k1'; root.saveCustomProvider()")
calls = json.loads(h.eval(panel, "JSON.stringify(KeyStore.calls)"))
check("a new key is saved with the endpoint", calls[-1][:3] == ["custom", "k1", "http://new/v1"], str(calls[-1]))
check("key input is cleared after saving", h.eval(panel, "customKeyInput.text") == "")
h.exit(0 if ok else 1)
