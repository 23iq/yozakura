"""Deferred agent creation generations and unsupported API images in real QML."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness("ai-request-runner")
h.singleton("qs.config", "Config", 'QtObject {property var ai: ({systemPrompt:"",shell:{systemPrompt:""}})}')
h.singleton("qs.modules.globals", "GlobalStates", "QtObject {function showQuickAsk() {}}")
h.singleton("qs.modules.services", "I18n", "QtObject {function t(key) {return key;}}")
h.copy("modules/services/ai/RequestRunner.qml")
obj = h.load('''import QtQuick
Item {
 id:scene
 property QtObject facade: QtObject {
  property string sessionKey: "agent:new"
  property bool busy: false
  property var currentModel: ({id:"agent:codex",agent:"codex",kind:"agent",available:true})
  property var quickModel: currentModel
  property var quick: null
  property var activeAgent: null
  property var activeChat: null
  property var agentSettings: ({cwd:"/tmp"})
  property string noticeError: ""
  property string opened: ""
  property QtObject catalog: QtObject {function find(id) {return scene.facade.currentModel;}}
  property QtObject agents: QtObject {
   property var agents: [{id:"codex",capabilities:{images:true}}]
   property var creates: []
   property var closed: []
   function create(agent,cwd,opts) {creates=creates.concat([opts]);}
   function close(id) {closed=closed.concat([id]);}
  }
  function openConversation(kind,id) {opened=id;}
 }
 property RequestRunner runner: RequestRunner {owner:scene.facade}
 property string callbackError: ""
}''')
h.eval(obj, "runner.send('old',[]);runner.stop();runner.send('new',[])")
new_generation = h.eval(obj, "runner.pending[facade.sessionKey]")
assert not h.eval(obj, "facade.agents.creates[0].onCreated({id:'old'})")
assert h.eval(obj, "runner.pending[facade.sessionKey]") == new_generation
assert h.eval(obj, "facade.agents.closed[0]") == "old"
h.eval(obj, "facade.agents.creates[0].onError()")
assert h.eval(obj, "runner.pending[facade.sessionKey]") == new_generation, "old failure cannot consume new create"
assert h.eval(obj, "facade.agents.creates[1].onCreated({id:'new'})")
assert h.eval(obj, "facade.opened") == "new"
h.eval(obj, "facade.currentModel=({id:'groq:test',provider:'groq',kind:'api',available:true});facade.quickModel=facade.currentModel")
assert not h.eval(obj, "runner.send('image',[{type:'image',base64:'data'}])")
assert h.eval(obj, "facade.noticeError") == "ai.unsupported_attachment"
h.eval(obj, "runner.runPrompt('image',{attachments:[{type:'image',base64:'data'}]},(text,error)=>scene.callbackError=error)")
assert h.eval(obj, "callbackError") == "ai.unsupported_attachment"
assert not h.eval(obj, "runner.askQuick('image',[{type:'image',base64:'data'}],'chat')")
assert h.eval(obj, "facade.noticeError") == "ai.unsupported_attachment"
print("ai-request-runner: ok")
h.exit(0)
