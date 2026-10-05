import QtQuick
import Quickshell.Io
import qs.modules.services
import "YozdOutput.js" as YozdOutput
import qs.modules.globals

Item {
    id: root

    property bool enabled: true
    property real timeout: 0
    property bool respectInhibitors: true
    property bool isIdle: false

    property var _monitorId: 0
    property bool _initialized: false

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
                if (result.value.is_idle !== undefined && result.value.is_idle !== root.isIdle)
                    root.isIdle = result.value.is_idle;
                return;
            }
            // The yozd daemon restarted (or is down) and lost the monitor:
            // recreate it once the daemon answers again.
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
            _monitorId = 0;
            _initialized = false;
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
        pollTimer.running = true;
    }

    function _stopPolling() {
        pollTimer.running = false;
    }

    function _checkIdle() {
        if (!_initialized || _monitorId === 0) return;

        _getProcess.command = Brand.daemonArgs(["system", "idle-monitor-get", String(_monitorId)]);
        _getProcess.running = true;
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
        interval: 2000
        repeat: false
        onTriggered: root._initMonitor()
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: root._checkIdle()
    }

    onEnabledChanged: {
        if (!enabled) {
            _destroyMonitor();
            _stopPolling();
            isIdle = false;
        } else if (timeout > 0) {
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
        _destroyMonitor();
    }

    Component.onCompleted: {
        if (enabled && timeout > 0) {
            _initMonitor();
        }
    }
}