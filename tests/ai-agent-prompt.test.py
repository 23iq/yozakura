"""Agent quick requests: real create/send IPC callbacks and cancellation races."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-agent-prompt")
h.singleton("qs.config", "Config", '''QtObject {
property var ai: ({agents: {claude:{enabled:true,binary:"",model:"",effort:"",yolo:false}, codex:{enabled:true,binary:"",model:"",effort:"",yolo:false}, opencode:{enabled:true,binary:"",model:"",effort:"",yolo:false},recentDirs:[]},mcp:{yozakura:true}})
}''')
h.module("Quickshell", {"Quickshell": 'pragma Singleton\nQtObject { function env(key) { return "/tmp"; } }'})
h.singleton("qs.modules.services", "BackendService", '''QtObject {
property var creates: []
property var sends: []
property var closed: []
property var sendCallbacks: []
function call(method,args,cb) {
 if(method === "agents.create") creates=creates.concat([{args:args,cb:cb}]);
 else if(method === "agents.send") { sends=sends.concat([args]);sendCallbacks=sendCallbacks.concat([cb]); }
 else if(method === "agents.close") closed=closed.concat([args.session]);
 else if(cb) cb(method === "agents.events" ? {events:[]} : {},"");
}
function completeCreate(i,id) {creates[i].cb({id:id,agent:"codex",cwd:"/tmp",status:"idle",model:"",effort:""},"");}
function failSend(i) {sendCallbacks[i](null,"send rejected");}
}''')
h.copy("modules/services/ai/AgentSessions.qml")
h.copy("modules/services/ai/AgentPrompt.qml")
obj = h.load('''import QtQuick
import qs.modules.services
Item {
 id:scene
 property AgentSessions manager: AgentSessions { agents: [{id:"codex",capabilities:{images:true}}] }
 property AgentPrompt prompt: AgentPrompt {owner:scene.manager;model:({id:"agent:codex",agent:"codex",name:"Codex"})}
 property string resultError: ""
 property Connections result: Connections {target:scene.prompt;function onTurnFinished(text,error) {scene.resultError=error;}}
}''')
h.eval(obj, "prompt.send('cancelled',[]); prompt.stop(); prompt.send('current',[])")
h.eval(obj, "BackendService.completeCreate(0,'old')")
assert h.eval(obj, "BackendService.sends.length") == 0, "late create must not submit cancelled input"
assert h.eval(obj, "BackendService.closed[0]") == "old", "cancelled native session must be closed"
h.eval(obj, "BackendService.completeCreate(1,'current')")
assert h.eval(obj, "BackendService.sends.length") == 1
assert h.eval(obj, "BackendService.sends[0].session") == "current"
assert h.eval(obj, "BackendService.sends[0].text") == "current"
assert h.eval(obj, "BackendService.creates[1].args.mode") == "oneshot"
assert not h.eval(obj, "BackendService.creates[1].args.yolo")
h.eval(obj, "BackendService.failSend(0)")
assert not h.eval(obj, "prompt.busy"), "IPC send failure must finish a quick request"
assert h.eval(obj, "resultError") == "send rejected"
h.eval(obj, "prompt.send('next',[]); manager._onEvent({session:'other',kind:'text',text:'wrong',delta:true})")
assert h.eval(obj, "prompt.rows.get(prompt._reply).content") == "", "another session cannot write this reply"
h.eval(obj, "manager._onEvent({session:'current',kind:'text',text:'right',delta:true}); manager._onEvent({session:'current',kind:'done'})")
assert not h.eval(obj, "prompt.busy")
assert h.eval(obj, "prompt.rows.get(prompt._reply).content") == "right"
h.eval(obj, "prompt.send('stop',[]); prompt.stop(); manager._onEvent({session:'current',kind:'text',text:'late',delta:true})")
assert h.eval(obj, "prompt.rows.get(prompt._reply).content") == "", "cancelled deltas must be ignored"
print("ai-agent-prompt: ok")
h.exit(0)
