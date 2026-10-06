"""Code project as first-class state (real Ai facade + CodeProject).

Choosing a folder sets Ai.projectDir (persisted as `aiCodeProject`, first in
ai.agents.recentDirs), survives switching agents, is the cwd of new Code
sessions, and while a session of another folder runs it moves the view to
a new session there instead of failing silently. Busy refusals show a
notice. The picker UI side is tests/ai-folder-picker.test.py."""
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-code-project")
repo = Path(__file__).resolve().parents[1]
config = json.loads(subprocess.check_output([
    "node", "-e", "console.log(JSON.stringify(require('./tests/lib/qmljs.cjs').loadLibrary('config/defaults/ai.js').data))"
], cwd=repo, text=True))
config["defaultModel"] = "agent:codex"
config["agents"]["recentDirs"] = ["/tmp/old"]
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
import json  # noqa: E402

h.eval(obj, "_ensureInit()")
h.eval(obj, "catalog.setAgents([{id:'codex',label:'Codex',available:true,capabilities:{}},{id:'claude',label:'Claude Code',available:true,capabilities:{}}])")
h.eval(obj, "setSpace('code')")
assert h.eval(obj, "projectDir") == "/tmp/old", "no stored project: the most recent folder"
assert h.eval(obj, "chooseProject('~/src/app/')")
assert h.eval(obj, "projectDir") == "/tmp/src/app", "~ expanded, trailing slash dropped"
assert h.eval(obj, "StateService.values.aiCodeProject") == "/tmp/src/app", "persisted"
assert json.loads(h.eval(obj, "JSON.stringify(Config.ai.agents.recentDirs)"))[:2] == ["/tmp/src/app", "/tmp/old"]
assert h.eval(obj, "agentSettings.cwd") == "/tmp/src/app"
assert not h.eval(obj, "chooseProject('relative/path')") and h.eval(obj, "noticeError") == "ai.project_invalid"
# Switching agents keeps the project (it is not a per-agent override).
h.eval(obj, "setModel('agent:claude')")
assert h.eval(obj, "agentSettings.cwd") == "/tmp/src/app"
h.eval(obj, "setModel('agent:codex')")
# configureAgent({cwd}) in Code goes to the project, not an override.
assert h.eval(obj, "configureAgent({cwd: '/tmp/src/app'})")
# A new Code session starts in the project.
h.eval(obj, "BackendService.calls=[]; send('fix it', [])")
creates = [c for c in json.loads(h.eval(obj, "JSON.stringify(BackendService.calls)")) if c["method"] == "agents.create"]
assert creates and creates[0]["args"]["cwd"] == "/tmp/src/app", creates
# A running session in the project: choosing another folder moves the view
# to a new session there; the running one is left alone (no cancel).
h.eval(obj, "agents.sessions=[{id:'run',agent:'codex',status:'running',mode:'agent',cwd:'/tmp/src/app'}]; openConversation('agent','run')")
assert h.eval(obj, "busy")
assert not h.eval(obj, "configureAgent({model:'x'})"), "settings refused while busy"
assert h.eval(obj, "noticeError") == "ai.busy_notice", "the refusal is visible"
assert not h.eval(obj, "effort.set('high')") and h.eval(obj, "noticeError") == "ai.busy_notice"
key = h.eval(obj, "sessionKey")
h.eval(obj, "BackendService.calls=[]")
assert h.eval(obj, "chooseProject('/tmp/other')")
assert h.eval(obj, "activeAgent") is None and not h.eval(obj, "busy"), "view moved off the running session"
assert h.eval(obj, "sessionKey") != key and h.eval(obj, "sessionKey").startswith("new:code:")
assert h.eval(obj, "projectDir") == "/tmp/other" and h.eval(obj, "noticeError") == ""
assert not [c for c in json.loads(h.eval(obj, "JSON.stringify(BackendService.calls)")) if c["method"] == "agents.cancel"]
# Opening a Code session of another folder shows that folder as the project.
h.eval(obj, "openConversation('agent','run')")
assert h.eval(obj, "projectDir") == "/tmp/src/app"
print("ai-code-project: ok")
h.exit(0)
