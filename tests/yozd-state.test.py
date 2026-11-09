"""YozdService does not republish unchanged workspaces/monitors.

compositor.state arrives for every window change; a title-only change (a
terminal spinner sends several per second) must update the clients but leave
the workspace/monitor arrays and the focused monitor/workspace objects alone,
so monitorFor() bindings in the bar, notch, dock and wallpaper do not re-run.
A real monitor/workspace change must still be published.

Clients are diffed by address (YozdClients.js): unchanged clients keep their
object identity, an identical snapshot publishes nothing, and focusedClient is
only replaced when the focused client itself changed.
"""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402

h = Harness('yozd-state')
h.module('Quickshell', {'Singleton': 'QtObject { default property list<QtObject> data }'})
h.module('qs.modules.services', {'BackendService': '''pragma Singleton
QtObject {
    property var sub: null
    function call(method, params, cb) {}
    function notify(method, params) {}
    function addSubscription(services, cb) { sub = cb; return 1; }
    function removeSubscription(key) {}
}'''})
# YozdService resolves BackendService as a same-directory sibling in the repo.
h.copy('modules/services/YozdService.qml', strip_singleton=True,
       replace={'import Quickshell\n': 'import Quickshell\nimport qs.modules.services\n'})
root = h.load('''import qs.modules.services
Item {
    property alias svc: s
    property int monitorBindingRuns: 0
    property int focusedMonitorChanges: 0
    property int workspaceChanges: 0
    property int clientChanges: 0
    property int focusedClientChanges: 0
    property var saved: null
    property var mon: s.monitorFor("DP-1")
    onMonChanged: monitorBindingRuns++
    YozdService { id: s }
    Connections { target: s; function onFocusedMonitorChanged() { focusedMonitorChanges++; } }
    Connections { target: s.workspaces; function onValuesChanged() { workspaceChanges++; } }
    Connections { target: s.clients; function onValuesChanged() { clientChanges++; } }
    Connections { target: s; function onFocusedClientChanged() { focusedClientChanges++; } }
}''', auto_stub=False)

ok_all = True


def check(name, ok, detail=''):
    global ok_all
    ok_all &= bool(ok)
    print(('PASS ' if ok else 'FAIL ') + name + (' ' + detail if detail else ''))


def state(title, active_ws=1, title3='w3'):
    return {
        'windows': [{'id': f'0x{i}', 'app_id': 'kitty', 'title': title if i == 0 else (title3 if i == 3 else f'w{i}'),
                     'workspace_id': str(1 + i % 5), 'is_focused': i == 0, 'is_floating': False,
                     'is_fullscreen': False, 'is_hidden': False,
                     'metadata': {'monitor_id': '0', 'x': 0, 'y': 0, 'width': 100, 'height': 100}}
                    for i in range(15)],
        'workspaces': [{'id': str(i), 'name': str(i), 'monitor_id': 'DP-1', 'is_active': i == active_ws}
                       for i in range(1, 11)],
        'monitors': [{'id': '0', 'name': 'DP-1', 'is_focused': True, 'width': 2560, 'height': 1440,
                      'refresh_rate': 240, 'scale': 1, 'metadata': {'active_workspace': str(active_ws)}}],
    }


def push(st):
    h.eval(root, f'svc.applyState({json.dumps(st)})')


def counters():
    return {k: root.property(k) for k in ('monitorBindingRuns', 'focusedMonitorChanges', 'workspaceChanges', 'clientChanges',
                                                'focusedClientChanges')}


push(state('spinner 0'))
before = counters()
n = 100
t0 = time.perf_counter()
for i in range(1, n + 1):
    push(state(f'spinner {i}'))
ms = (time.perf_counter() - t0) * 1000 / n
after = counters()
delta = {k: after[k] - before[k] for k in after}
print(f'{n} title-only events: {delta}, {ms:.2f} ms/event (incl. harness eval)')
check('title-only events update clients', delta['clientChanges'] == n)
check('workspaces are not republished', delta['workspaceChanges'] == 0)
check('focused monitor keeps its identity', delta['focusedMonitorChanges'] == 0)
check('monitorFor() bindings do not re-run', delta['monitorBindingRuns'] == 0)

push(state('spinner x', active_ws=2))
final = counters()
check('workspace switch is published', final['workspaceChanges'] == after['workspaceChanges'] + 1)
check('monitor change re-runs monitorFor() bindings', final['monitorBindingRuns'] > after['monitorBindingRuns'])
check('active workspace reflected', h.eval(root, 'svc.focusedMonitor.activeWorkspace.id') == 2
      and h.eval(root, 'svc.focusedWorkspace.id') == 2)


# Identity-preserving client diff.
push(state('same'))
h.eval(root, 'saved = svc.clients.values[3]')
c0 = counters()
push(state('same'))
c1 = counters()
check('identical snapshot does not republish clients', c1['clientChanges'] == c0['clientChanges'])
check('identical snapshot keeps focusedClient', c1['focusedClientChanges'] == c0['focusedClientChanges'])
push(state('changed'))
c2 = counters()
check('focused title change republishes clients', c2['clientChanges'] == c1['clientChanges'] + 1)
check('unchanged client keeps its object', h.eval(root, 'svc.clients.values[3] === saved'))
check('focused client is replaced when it changed', c2['focusedClientChanges'] == c1['focusedClientChanges'] + 1
      and h.eval(root, 'svc.focusedClient.title') == 'changed'
      and h.eval(root, 'svc.focusedClient === svc.clients.values[0]'))
h.eval(root, 'saved = svc.focusedClient')
push(state('changed', title3='renamed'))
c3 = counters()
check('other client change replaces only that client', h.eval(root, 'svc.clients.values[3].title') == 'renamed'
      and h.eval(root, 'svc.clients.values[0] === saved'))
check('focusedClient untouched by another client changing', c3['focusedClientChanges'] == c2['focusedClientChanges'])

sys.exit(0 if ok_all else 1)
