"""Real assistant facade: "set once, stays". The engine + CLI-agent model
picked in a space is persisted (EngineMemory: aiEngines / aiAgentModels in
StateService) and used by new chats, the launch of new sessions
(agents.create model), Quick ask and a restart (a second Ai instance over
the same StateService). A resumed old session shows its own model; the
configured default only wins when it changed after the pick.
"""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-engine-memory")
repo = Path(__file__).resolve().parents[1]
config = json.loads(subprocess.check_output([
    "node", "-e", "console.log(JSON.stringify(require('./tests/lib/qmljs.cjs').loadLibrary('config/defaults/ai.js').data))"
], cwd=repo, text=True))
config["defaultModel"] = "agent:codex"
h.singleton("qs.config", "Config", "QtObject { property var ai: (" + json.dumps(config) + ") }")
h.module("Quickshell", {
    "Quickshell": 'pragma Singleton\nQtObject { function env(key) { return key === "HOME" ? "/tmp" : ""; } }',
    "Singleton": "QtObject { default property list<QtObject> data }",
})
h.module("Quickshell.Io", {
    "Process": "QtObject { property var command; property var stdout; property var stderr; property var environment; property bool running: false; signal exited(int code, int status); function signal(number) {} }",
    "StdioCollector": "QtObject { property string text; signal streamFinished; }",
    "SplitParser": "QtObject { signal read(string line); }",
    "FileView": "QtObject { property string path; property bool atomicWrites; property bool blockWrites; property bool printErrors; signal loaded; function setText(text) {} function text() { return ''; } }",
})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { function t(key) { return key; } }",
    "StateService": 'pragma Singleton\nQtObject { property bool initialized: true; property var values: ({}); function get(k,d) { return values[k] === undefined ? d : values[k]; } function set(k,v) { values=Object.assign({},values,{[k]:JSON.parse(JSON.stringify(v))}); } }',
    "KeyStore": 'pragma Singleton\nQtObject { signal keysChanged; function getKey(p) { return ""; } function hasKey(p) { return false; } function getEndpoint(p) { return ""; } function getCustomCurl(p) { return ""; } }',
    "BackendService": '''pragma Singleton
QtObject {
    property bool socketAvailable: true
    property var calls: []
    function addSubscription(names, cb) { return 1; }
    function removeSubscription(id) {}
    function call(method, args, cb) {
        calls = calls.concat([{method:method,args:args}]);
        const created = {id: "created" + calls.length, agent: args.agent, mode: args.mode, cwd: args.cwd, model: args.model, status: "idle"};
        if (cb) cb(method === "agents.list_agents" || method === "agents.sessions" ? [] : (method === "agents.create" ? created : {}), "");
    }
}''',
})
h.singleton("qs.modules.globals", "GlobalStates", '''QtObject {
property bool assistantVisible: false
property string aiSpace: "assistant"
property string settingsCategory: ""
property bool settingsWindowVisible: false
property string quickAskKind: ""
property var quickAskAttachments: []
function showQuickAsk(kind) { quickAskKind=kind||""; }
function hideQuickAsk() {}
function toggleAssistant() { assistantVisible=!assistantVisible; }
}''')
h.singleton("qs.modules.settings.store", "SettingsStore", "QtObject { function set(key,value) {} }")
h.singleton("qs.modules.services.activities", "ActivityService", "QtObject { property var transfers: [] }")
for src in (repo / "modules/services/ai").glob("*"):
    if src.suffix in (".qml", ".js"):
        h.copy(src.relative_to(repo), dest="modules/services/ai")
path = h.copy("modules/services/Ai.qml", dest="modules/services", strip_singleton=True)

SETUP = """catalog.setAgents([{id:'claude',label:'Claude Code',available:true,capabilities:{}},{id:'codex',label:'Codex',available:true,capabilities:{}}]);
catalog.apiModels=[{id:'openai:a',model:'a',provider:'openai',name:'A',kind:'api',available:true}]"""


def creates(obj):
    return [c["args"] for c in json.loads(h.eval(obj, "JSON.stringify(BackendService.calls)")) if c["method"] == "agents.create"]


def boot():
    obj = h.load(path)
    h.eval(obj, "GlobalStates.aiSpace = 'assistant'; _ensureInit()")
    h.eval(obj, SETUP)
    return obj


obj = boot()
assert h.eval(obj, "currentModelId") == "agent:codex", "nothing picked yet: the configured default"
# Picker child "Claude > Haiku": engine + model in one step.
assert h.eval(obj, "pickAgentModel('claude', 'haiku')")
assert h.eval(obj, "currentModelId") == "agent:claude"
assert h.eval(obj, "agentSettings.model") == "haiku"
assert h.eval(obj, "StateService.values.aiAgentModels['assistant:claude']") == "haiku"
assert h.eval(obj, "StateService.values.aiEngines.assistant.id") == "agent:claude"
assert h.eval(obj, "effort.set('low')")
h.eval(obj, "BackendService.calls=[]; send('hello', [])")
c = creates(obj)
assert c and c[0]["model"] == "haiku" and c[0]["effort"] == "low" and c[0]["agent"] == "claude", c
# A new chat keeps the pick, even after the configured default (codex) ...
h.eval(obj, "newConversation()")
assert h.eval(obj, "currentModelId") == "agent:claude", "new chat keeps the picked engine, not ai.defaultModel"
assert h.eval(obj, "activeAgent") is None
assert h.eval(obj, "agentSettings.model") == "haiku"
# ... and after resuming an old session that runs another model.
h.eval(obj, "agents.sessions=[{id:'old',agent:'codex',status:'idle',mode:'assistant',model:'gpt-5.4',cwd:'/tmp',effort:''}]; openConversation('agent','old')")
assert h.eval(obj, "agentSettings.model") == "gpt-5.4", "a resumed session shows its own model"
assert h.eval(obj, "currentModelId") == "agent:codex"
h.eval(obj, "newConversation()")
assert h.eval(obj, "currentModelId") == "agent:claude" and h.eval(obj, "agentSettings.model") == "haiku"
# Quick ask follows the Assistant's pick (ai.quickAsk.model is empty).
assert h.eval(obj, "quickModel.id") == "agent:claude"
h.eval(obj, "BackendService.calls=[]; askQuick('2+2?', [])")
c = creates(obj)
assert c and c[0]["mode"] == "oneshot" and c[0]["model"] == "haiku", c
# Code space: its own pick.
h.eval(obj, "setSpace('code'); pickAgentModel('codex', 'gpt-5.5')")
assert h.eval(obj, "StateService.values.aiAgentModels['code:codex']") == "gpt-5.5"
h.eval(obj, "setSpace('assistant')")

# Restart: a fresh facade over the same StateService.
obj2 = boot()
assert h.eval(obj2, "currentModelId") == "agent:claude", "the pick survives a restart"
assert h.eval(obj2, "agentSettings.model") == "haiku"
assert h.eval(obj2, "agentSettings.effort") == "low", "the model's level is remembered"
h.eval(obj2, "BackendService.calls=[]; send('again', [])")
c = creates(obj2)
assert c and c[0]["model"] == "haiku" and c[0]["mode"] == "assistant", c
h.eval(obj2, "setSpace('code')")
assert h.eval(obj2, "currentModelId") == "agent:codex"
assert h.eval(obj2, "agentSettings.model") == "gpt-5.5", "Code keeps its own agent model"
h.eval(obj2, "setSpace('assistant')")

# A default changed after the pick (pinned/edited setting) is the newer choice.
h.eval(obj2, "Config.ai = Object.assign({}, Config.ai, {defaultModel: 'openai:a'})")
obj3 = boot()
assert h.eval(obj3, "currentModelId") == "openai:a", h.eval(obj3, "currentModelId")
print("ai-engine-memory: ok")
h.exit(0)
