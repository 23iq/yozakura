import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import "DryRunBackend.js" as DryRunBackend

pragma Singleton

// BackendService bridges QML to the yozakura Go daemon over a Unix socket.
// Protocol: line-delimited JSON-RPC (see backend/pkg/ipc).
// - reqSocket: shared request/response socket, id -> callback map.
// - Subscriptions: one dedicated Socket per consumer group; each sends
//   {"id":1,"method":"subscribe","params":{"services":[...]}} on connect
//   and streams {"id":1,"result":{"service":"x","data":...}} lines.
//
// Usage:
//   const handle = BackendService.addSubscription(["systemmonitor"], (service, data) => {...});
//   BackendService.setSubscriptionActive(handle, false); // pause polling
//   BackendService.removeSubscription(handle);
//
// Lifecycle: the daemon is launched by `yozakura` itself, not by this
// singleton. If the socket is missing we just keep retrying the
// connection — the user is expected to run `yozakura` (or autostart it)
// before the shell starts.
//
// Dry run (DryRun.active, `<app> onboarding --dry-run`): fail closed. Only
// the reads allowed by DryRunMethods.js reach the daemon (their answers pass
// DryRunBackend.overlay); every other call is answered by the mock,
// journaled, and its fake events are pushed to the subscribers.
Singleton {
    id: root

    readonly property string socketPath: Brand.runtimeFile(".sock")

    property bool connected: false

    // ---- request machinery ----
    property var pending: ({})
    property int nextId: 1

    // ---- subscriptions: keyed by integer handle ----
    property var subscriptions: ({})
    property int nextSubId: 1

    Timer {
        id: probeTimer
        interval: 500
        running: true
        repeat: true
        onTriggered: root.tryConnect()
    }

    // If the socket isn't connected yet, queue the request and drain it
    // once connected — otherwise requests fired during startup are
    // silently dropped ("device not open").
    property var pendingQueue: []

    function _drainQueue() {
        if (!root.socketAvailable) return;
        while (root.pendingQueue.length > 0) {
            const item = root.pendingQueue.shift();
            if (item.callback !== undefined) root.pending[item.id] = item.callback;
            reqSocket.write(item.msg + "\n");
            reqSocket.flush();
        }
    }

    function call(method, params, callback) {
        if (!params) params = {};
        if (DryRun.active) {
            if (DryRunBackend.isMutating(method, params)) {
                root._dryCall(method, params, callback);
                return;
            }
            params = DryRunBackend.readParams(method, params);
            if (callback !== undefined) {
                const cb = callback;
                callback = (result, error) => cb(error ? result : DryRunBackend.overlay(root._dry, method, result), error);
            }
        }
        const id = root.nextId++;
        const msg = JSON.stringify({id, method, params});
        if (callback !== undefined) root.pending[id] = callback;
        if (root.socketAvailable) {
            reqSocket.write(msg + "\n");
            reqSocket.flush();
            root._drainQueue();
        } else {
            root.pendingQueue.push({id, msg, callback});
        }
    }

    function notify(method, params) {
        if (!params) params = {};
        root.call(method, params, undefined);
    }

    // ---- dry run ----
    property var _dry: DryRun.active ? DryRunBackend.create(DryRun.failIds) : null

    function _dryCall(method, params, callback) {
        const out = DryRunBackend.handle(root._dry, method, params, Date.now());
        DryRun.journal(out.line);
        Qt.callLater(() => {
            if (callback)
                callback(out.result, out.error);
            out.events.forEach(e => root._emitLocal(e.service, e.data));
            if (DryRunBackend.hasPending(root._dry))
                dryClock.start();
        });
    }

    // Delivers a faked event to every subscription of its service group.
    function _emitLocal(service, data) {
        const group = String(service).split(".")[0];
        const keys = Object.keys(root.subscriptions);
        for (let i = 0; i < keys.length; i++) {
            const sub = root.subscriptions[keys[i]];
            if (sub && sub.ok && sub.active && sub.socket.callback && sub.socket.services.indexOf(group) >= 0)
                sub.socket.callback(service, data);
        }
    }

    Timer {
        id: dryClock
        interval: 250
        repeat: true
        onTriggered: {
            DryRunBackend.due(root._dry, Date.now()).forEach(e => {
                DryRun.journal(e.line);
                root._emitLocal(e.service, e.data);
            });
            if (!DryRunBackend.hasPending(root._dry))
                stop();
        }
    }

    function tryConnect() {
        if (root.socketAvailable) return;
        reqSocket.connected = true;
        const keys = Object.keys(root.subscriptions);
        for (let i = 0; i < keys.length; i++) {
            const sub = root.subscriptions[keys[i]];
            if (sub && sub.active && sub.ok) sub.socket.connected = true;
        }
    }

    property bool socketAvailable: false
    onSocketAvailableChanged: {
        if (!socketAvailable) probeTimer.running = true;
    }

    // Connect on the spot instead of waiting for probeTimer's first tick;
    // early requests are queued until the socket is up either way.
    Component.onCompleted: tryConnect()

    // Adds a subscription. Returns an integer handle.
    function addSubscription(services, callback) {
        const key = root.nextSubId++;
        const dry = root._dry;
        const cb = dry ? (service, data) => callback(service, DryRunBackend.overlayEvent(dry, service, data)) : callback;
        const obj = subSocketFactory.createObject(root, {services: services, callback: cb});
        root.subscriptions[key] = {socket: obj, active: true, ok: true};
        if (root.socketAvailable) Qt.callLater(() => { if (root.subscriptions[key] && root.subscriptions[key].ok) obj.connected = true; });
        return key;
    }

    function setSubscriptionActive(key, active) {
        const sub = root.subscriptions[key];
        if (!sub || !sub.ok) return;
        sub.active = active;
        if (active) {
            if (!root.socketAvailable) {
                probeTimer.running = true;
                return;
            }
            sub.socket.connected = true;
        } else {
            sub.socket.connected = false;
        }
    }

    function removeSubscription(key) {
        const sub = root.subscriptions[key];
        if (!sub || !sub.ok) return;
        sub.ok = false;
        sub.socket.connected = false;
        sub.socket.destroy();
        delete root.subscriptions[key];
    }

    // Per-consumer subscription socket. Sends the subscribe request on every
    // connect and forwards matching ServiceEvents to the registered callback.
    Component {
        id: subSocketFactory
        Socket {
            id: sub
            property var services: []
            property var callback: null

            path: root.socketPath
            connected: false

            parser: SplitParser {
                onRead: (data) => {
                    if (!data) return;
                    try {
                        const msg = JSON.parse(data);
                        const ev = msg.result;
                        if (ev && ev.service && sub.callback) {
                            sub.callback(ev.service, ev.data);
                        }
                    } catch (e) {
                        console.warn("BackendService: failed to parse event:", e);
                    }
                }
            }

            onConnectionStateChanged: {
                if (sub.connected) {
                    sub.write(JSON.stringify({id: 1, method: "subscribe", params: {services: sub.services}}) + "\n");
                    sub.flush();
                }
            }

            onError: (error) => {
                console.warn("BackendService: subscription socket error", error);
                root.onSocketDown();
            }
        }
    }

    // Shared request/response socket.
    Socket {
        id: reqSocket
        path: root.socketPath
        connected: false

        parser: SplitParser {
            onRead: (data) => {
                if (!data) return;
                try {
                    const msg = JSON.parse(data);
                    if (typeof msg.id === "number" && msg.id !== 0) {
                        const cb = root.pending[msg.id];
                        delete root.pending[msg.id];
                        if (cb) cb(msg.result, msg.error);
                    }
                } catch (e) {
                    console.warn("BackendService: failed to parse response:", e);
                }
            }
        }

        onError: (error) => {
            console.warn("BackendService: request socket error", error);
            root.onSocketDown();
        }

        onConnectionStateChanged: {
            root.socketAvailable = reqSocket.connected;
            if (reqSocket.connected) {
                root._drainQueue();
            } else {
                root.onSocketDown();
            }
        }
    }

    function onSocketDown() {
        socketAvailable = false;
        probeTimer.running = true;
    }
}
