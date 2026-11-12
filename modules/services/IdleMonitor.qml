import QtQuick
import Quickshell.Io
import qs.modules.services
import "YozdOutput.js" as YozdOutput
import qs.modules.globals

// An idle monitor in the compositor daemon (yozd). Create/update/destroy go
// through its CLI; the idle/active state arrives by event: the backend
// forwards the daemon's flips on the "idlemon" subscription
// (backend/pkg/svc/compositor/idle.go). While that path is not up (backend
// or daemon starting, a daemon that does not send the events, a lost
// subscription), the state is polled every second as before.
//
// In event mode the state is read once when a monitor is created, whenever
// the path comes (back) up or reports a new epoch (the daemon restarted: a
// stale id fails the read and the monitor is recreated), and by a slow
// safety re-read so a lost event cannot leave isIdle wrong for long.
Item {
    id: root

    property bool enabled: true
    property real timeout: 0
    property bool respectInhibitors: true
    property bool isIdle: false

    property var _monitorId: 0
    property bool _initialized: false

    // A monitor exists and its state is being followed (polling or events).
    property bool _active: false
    // The last idlemon.status said the event path is up.
    property bool _streamReady: false
    property var _epoch: null
    readonly property bool _backendUp: BackendService.socketAvailable
    readonly property bool _eventMode: _streamReady && _backendUp
    property var _subscription: null
    // Events received; a read that overlaps one is older than it.
    property int _eventSerial: 0
    property int _readSerial: 0
    property bool _readAgain: false
    // The media check cleared isIdle while the daemon still reports idle:
    // poll as before so the state comes back once the media stops.
    property bool _mediaHeld: false

    property var _createProcess: Process {
        id: _createProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: _createStdout
        }
        onExited: (code) => {
            if (code === 0 && _createStdout.text) {
                const result = YozdOutput.parse(_createStdout.text);
                if (result.ok && result.value && result.value.id !== undefined) {
                    root._monitorId = result.value.id;
                    root._initialized = true;
                    root._startPolling();
                } else {
                    console.warn("IdleMonitor: could not create idle monitor via " + Brand.daemon + ":", result.ok ? "response has no id" : result.error);
                    retryTimer.restart();
                }
            } else {
                console.warn("IdleMonitor: " + Brand.daemon + " idle-monitor-create failed: code=", code, "output:", _createStdout.text);
                retryTimer.restart();
            }
        }
    }

    property var _getProcess: Process {
        id: _getProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: _getStdout
        }
        onExited: (code) => {
            const result = YozdOutput.parse(_getStdout.text);
            if (code === 0 && result.ok && result.value) {
                // An event that arrived meanwhile is at least as new.
                if (root._readSerial === root._eventSerial)
                    root._applyIdle(result.value.is_idle);
                if (root._readAgain) {
                    root._readAgain = false;
                    root._checkIdle();
                }
                return;
            }
            // The yozd daemon restarted (or is down) and lost the monitor:
            // recreate it once the daemon answers again.
            root._readAgain = false;
            root._monitorId = 0;
            root._initialized = false;
            root._stopPolling();
            retryTimer.restart();
        }
    }

    property var _updateProcess: Process {
        id: _updateProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: _updateStdout
        }
        onExited: (code) => {
            if (code === 0) {
                root._checkIdle();
            }
        }
    }

    property var _destroyProcess: Process {
        id: _destroyProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: _destroyStdout
        }
        onExited: (code) => {
            root._monitorId = 0;
            root._initialized = false;
        }
    }

    function _initMonitor() {
        if (_initialized || !enabled || timeout <= 0) return;

        var timeoutMs = Math.round(timeout * 1000);
        var respect = respectInhibitors ? 1 : 0;
        var en = enabled ? 1 : 0;

        _createProcess.command = Brand.daemonArgs(["system", "idle-monitor-create", String(timeoutMs), String(respect), String(en)]);
        _createProcess.running = true;
    }

    function _destroyMonitor() {
        if (_monitorId > 0) {
            _destroyProcess.command = Brand.daemonArgs(["system", "idle-monitor-destroy", String(_monitorId)]);
            _destroyProcess.running = true;
        }
    }

    function _startPolling() {
        _active = true;
        // Polling reads within a second; events only report flips, so read
        // the new monitor's state once.
        if (_eventMode)
            _checkIdle();
    }

    function _stopPolling() {
        _active = false;
        _mediaHeld = false;
    }

    function _checkIdle() {
        if (!_initialized || _monitorId === 0) return;
        if (_getProcess.running) {
            _readAgain = true;
            return;
        }

        _readSerial = _eventSerial;
        _getProcess.command = Brand.daemonArgs(["system", "idle-monitor-get", String(_monitorId)]);
        _getProcess.running = true;
    }

    function _applyIdle(idle) {
        if (typeof idle !== "boolean")
            return;
        if (!idle)
            _mediaHeld = false;
        if (idle !== isIdle)
            isIdle = idle;
    }

    // ---- event path (idlemon subscription) ----

    function _subscribe() {
        if (_subscription !== null) return;
        _subscription = BackendService.addSubscription(["idlemon"], (service, data) => root._onIdlemon(service, data));
    }

    function _unsubscribe() {
        if (_subscription === null) return;
        BackendService.removeSubscription(_subscription);
        _subscription = null;
        _streamReady = false;
    }

    function _onIdlemon(service, data) {
        if (!data || !enabled) return;
        if (service === "idlemon.status") {
            const wasEventMode = _eventMode;
            const newEpoch = data.epoch !== _epoch;
            _epoch = data.epoch;
            _streamReady = data.connected === true && data.events === true;
            // The rising edge re-reads in on_EventModeChanged.
            if (wasEventMode && _eventMode && newEpoch)
                _checkIdle();
        } else if (service === "idlemon.changed") {
            if (!_initialized || data.id !== _monitorId)
                return;
            _eventSerial++;
            _applyIdle(data.is_idle);
        }
    }

    on_BackendUpChanged: {
        // A reconnected backend sends a fresh status on the new subscription.
        if (!_backendUp)
            _streamReady = false;
    }

    on_EventModeChanged: {
        // Events may have been missed while the path was down.
        if (_eventMode && _active)
            _checkIdle();
    }

    function _checkMediaInhibitor() {
        if (!root.respectInhibitors) return;

        _mediaCheckProcess.command = Brand.daemonArgs(["system", "media-inhibit-check"]);
        _mediaCheckProcess.running = true;
    }

    property var _mediaCheckProcess: Process {
        id: _mediaCheckProcess
        command: []
        running: false
        stdout: StdioCollector {
            id: _mediaCheckStdout
        }
        onExited: (code) => {
            if (code === 0 && _mediaCheckStdout.text) {
                try {
                    var json = JSON.parse(_mediaCheckStdout.text.trim());
                    if (json.count > 0) {
                        root.isIdle = false;
                        root._mediaHeld = root._active;
                    } else {
                        root._mediaHeld = false;
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: mediaCheckTimer
        objectName: "mediaCheckTimer"
        interval: 5000
        // The check can only clear isIdle, so it is pointless (12 process
        // spawns/min) while the session is active.
        running: root.respectInhibitors && root.isIdle
        repeat: true
        onTriggered: root._checkMediaInhibitor()
    }

    function _updateMonitor() {
        if (!enabled || timeout <= 0 || _monitorId === 0) {
            _stopPolling();
            return;
        }

        var timeoutMs = Math.round(timeout * 1000);
        var respect = respectInhibitors ? 1 : 0;
        var en = enabled ? 1 : 0;

        _updateProcess.command = Brand.daemonArgs(["system", "idle-monitor-update", String(_monitorId), String(timeoutMs), String(respect), String(en)]);
        _updateProcess.running = true;
    }

    // Retries monitor creation while the yozd daemon is unavailable.
    Timer {
        id: retryTimer
        objectName: "retryTimer"
        interval: 2000
        repeat: false
        onTriggered: root._initMonitor()
    }

    // Fallback while the event path is down (and while media holds the
    // session active, so idle comes back as soon as the media stops).
    Timer {
        id: pollTimer
        objectName: "pollTimer"
        interval: 1000
        running: root._active && (!root._eventMode || root._mediaHeld)
        repeat: true
        onTriggered: root._checkIdle()
    }

    // Safety re-read in event mode: events are ordered and a lost one is
    // unlikely (the backend resyncs on overflow and reconnects), but a wrong
    // isIdle drives dimming, locking and suspend. Stuck "idle" would act
    // while the user works, so it is re-checked sooner than stuck "active".
    Timer {
        id: safetyTimer
        objectName: "safetyTimer"
        interval: root.isIdle ? 15000 : 60000
        running: root._active && root._eventMode && !root._mediaHeld
        repeat: true
        onTriggered: root._checkIdle()
    }

    onEnabledChanged: {
        if (!enabled) {
            _unsubscribe();
            _destroyMonitor();
            _stopPolling();
            isIdle = false;
        } else {
            _subscribe();
            if (timeout > 0)
                _initMonitor();
        }
    }

    onTimeoutChanged: {
        if (timeout > 0 && enabled) {
            if (_initialized) {
                _updateMonitor();
            } else {
                _initMonitor();
            }
        }
    }

    onRespectInhibitorsChanged: {
        if (_initialized) {
            _updateMonitor();
        }
    }

    Component.onDestruction: {
        _unsubscribe();
        _destroyMonitor();
    }

    Component.onCompleted: {
        if (enabled)
            _subscribe();
        if (enabled && timeout > 0) {
            _initMonitor();
        }
    }
}
