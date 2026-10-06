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
    "FileView": "QtObject { property string path; property bool atomicWrites; property bool blockWrites; property bool printErrors; signal loaded; function setText(text) {} function text() { return ''; } }",
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
        const created = {id: "created" + calls.length, agent: args.agent, mode: args.mode, cwd: args.cwd, status: "idle"};
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
# Spaces: Code keeps CLI agents and its own selection; Assistant gets its chat back.
h.eval(obj, "setModel('openai:a'); chat.title='assistant chat'")
assistant_chat = h.eval(obj, "chat.chatId")
h.eval(obj, "setSpace('code')")
assert h.eval(obj, "GlobalStates.aiSpace") == "code"
assert h.eval(obj, "StateService.values.aiSpace") == "code", "visible space is persisted"
assert h.eval(obj, "mode") == "agent" and h.eval(obj, "currentModelId").startswith("agent:"), "Code runs CLI agents"
assert h.eval(obj, "activeAgent") is None, "Code starts without the assistant's agent session"
assert not h.eval(obj, "setModel('openai:a')"), "HTTP models are rejected in Code"
assert h.eval(obj, "noticeError") == "ai.code_needs_agent"
h.eval(obj, "setModel('agent:codex')")
assert h.eval(obj, "StateService.values.lastAiCodeModel") == "agent:codex"
assert h.eval(obj, "sessionKey").startswith("new:code:")
h.eval(obj, "BackendService.calls=[]; send('fix the build', [])")
creates = [c for c in h.eval(obj, "JSON.stringify(BackendService.calls)") and __import__("json").loads(h.eval(obj, "JSON.stringify(BackendService.calls)")) if c["method"] == "agents.create"]
assert creates and creates[0]["args"]["mode"] == "agent", creates
h.eval(obj, "setSpace('assistant')")
assert h.eval(obj, "mode") == "chat" and h.eval(obj, "chat.chatId") == assistant_chat, "Assistant restores its own chat"
assert h.eval(obj, "currentModelId") == "openai:a"
h.eval(obj, "setModel('agent:codex'); BackendService.calls=[]; send('dim the screen', [])")
creates = [c for c in __import__("json").loads(h.eval(obj, "JSON.stringify(BackendService.calls)")) if c["method"] == "agents.create"]
assert creates and creates[0]["args"]["mode"] == "assistant" and creates[0]["args"]["cwd"] == "/tmp", creates
assert creates[0]["args"]["yolo"] is False, "assistant agents always ask"
# Opening a project session from history switches to Code.
h.eval(obj, "agents.sessions=agents.sessions.concat([{id:'proj',agent:'codex',status:'idle',mode:'agent',cwd:'/tmp'}]); openConversation('agent','proj')")
assert h.eval(obj, "GlobalStates.aiSpace") == "code" and h.eval(obj, "activeAgent.id") == "proj"
assert h.eval(obj, "StateService.values.aiLastCodeSession.id") == "proj", "last Code session is remembered"
h.eval(obj, "openConversation('agent','first')")
assert h.eval(obj, "GlobalStates.aiSpace") == "assistant", "legacy shell sessions belong to the Assistant"
# Effort is remembered per model and reaches the chat; Ollama gets num_ctx.
h.eval(obj, """setSpace('assistant'); catalog.apiModels=[
  {id:'anthropic:claude-sonnet-4-5',model:'claude-sonnet-4-5',provider:'anthropic',name:'Sonnet',kind:'api',available:true,
   info:{reasoning:'anthropic_budget',efforts:['off','low','medium','high','max'],contextWindow:200000}},
  {id:'ollama:qwen3',model:'qwen3',provider:'ollama',name:'qwen3',kind:'local',available:true,
   info:{source:'ollama',reasoning:'ollama_think',capabilities:['thinking'],contextWindow:262144}}];
setModel('anthropic:claude-sonnet-4-5')""")
assert h.eval(obj, "effort.level") == "", "auto: nothing sent until the user picks a level"
assert h.eval(obj, "JSON.stringify(effort.levels)") == '["off","low","medium","high","max"]'
assert h.eval(obj, "effort.set('high')")
assert h.eval(obj, "chat.effort") == "high", "the chat uses the chosen level"
assert h.eval(obj, "StateService.values.aiModelEfforts['anthropic:claude-sonnet-4-5']") == "high", "remembered per model"
assert h.eval(obj, "contextState.window") == 200000
h.eval(obj, "chat.contextTokens = 190000")
assert h.eval(obj, "contextState.level") == "critical"
h.eval(obj, "setModel('ollama:qwen3')")
assert h.eval(obj, "chat.numCtx") == 32768, "num_ctx = min(model max, ai.ollama.numCtx)"
assert h.eval(obj, "contextState.window") == 32768
h.eval(obj, "setModel('anthropic:claude-sonnet-4-5')")
assert h.eval(obj, "effort.level") == "high", "switching back restores the model's level"
# Agents: the chosen native level is remembered for the next session.
h.eval(obj, "setModel('agent:codex'); effort.set('xhigh')")
assert h.eval(obj, "StateService.values.aiModelEfforts['agent:codex/default']") == "xhigh"
assert h.eval(obj, "agentSettings.effort") == "xhigh"
print("ai-facade: ok")
h.exit(0)
