"""Real assistant facade: explicit default, separate engines and addressed cancellation."""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-facade")
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
    "FileView": "QtObject { property string path; property bool atomicWrites; property bool blockWrites; property bool printErrors; function setText(text) {} }",
})
h.module("qs.modules.services", {
    "I18n": "pragma Singleton\nQtObject { function t(key) { return key; } }",
    "StateService": 'pragma Singleton\nQtObject { property bool initialized: true; property var values: ({lastAiModel:"ollama:qwen"}); function get(k,d) { return values[k] === undefined ? d : values[k]; } function set(k,v) { values=Object.assign({},values,{[k]:v}); } }',
    "KeyStore": 'pragma Singleton\nQtObject { signal keysChanged; function getKey(p) { return ""; } function hasKey(p) { return false; } function getEndpoint(p) { return ""; } function getCustomCurl(p) { return ""; } }',
    "BackendService": '''pragma Singleton
QtObject {
    property bool socketAvailable: true
    property var calls: []
    function addSubscription(names, cb) { return 1; }
    function removeSubscription(id) {}
    function call(method, args, cb) {
        calls = calls.concat([{method:method,args:args}]);
        if (cb) cb(method === "agents.list_agents" || method === "agents.sessions" ? [] : {}, "");
    }
}''',
})
h.singleton("qs.modules.globals", "GlobalStates", '''QtObject {
property bool assistantVisible: false
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
obj = h.load(path)
h.eval(obj, "_ensureInit()")
assert h.eval(obj, "currentModelId") == "agent:codex", "configured primary wins over last API model"
h.eval(obj, '''catalog.setAgents([{id:'codex',label:'Codex',available:true,capabilities:{images:true}}]);
catalog.apiModels=[{id:'openai:a',model:'a',provider:'openai',name:'A',kind:'api',available:true}];
agents.sessions=[{id:'first',agent:'codex',status:'running',mode:'shell',model:'native',cwd:'/tmp',effort:'high'}];
openConversation('agent','first')''')
assert h.eval(obj, "busy")
assert not h.eval(obj, "configureAgent({model:'changed'})"), "running session settings stay unchanged"
h.eval(obj, "stop()")
assert h.eval(obj, "BackendService.calls[BackendService.calls.length-1].method") == "agents.cancel"
assert h.eval(obj, "BackendService.calls[BackendService.calls.length-1].args.session") == "first"
h.eval(obj, "setModel('openai:a'); chat.title='HTTP work'; chat.busy=true; setModel('agent:codex')")
assert not h.eval(obj, "busy"), "a background HTTP request must not block a new agent"
assert h.eval(obj, "chat.busy"), "switching engines keeps HTTP work alive"
h.eval(obj, "openConversation('chat',chat.chatId)")
assert h.eval(obj, "currentModelId") == "openai:a"
assert h.eval(obj, "busy")
h.eval(obj, "chat.busy=false; var removed=chat.chatId; removeConversation('chat',removed)")
assert h.eval(obj, "activeChat !== null || mode === 'agent'"), "deleting the visible chat leaves a usable conversation"
h.eval(obj, "openConversation('chat','late'); openConversation('agent','first'); store.loaded('late',{id:'late',model:'openai:a',messages:[]})")
assert h.eval(obj, "mode") == "agent", "late history load must not steal selection after opening an agent"
print("ai-facade: ok")
h.exit(0)
