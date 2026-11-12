pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import "IdleSchedule.js" as IdleSchedule
import "WallpaperIdleDelay.js" as WallpaperIdleDelay

Singleton {
    id: root

    // General Idle Settings
    property string lockCmd: Config.system.idle.general.lock_cmd ?? Brand.appBin + " lock"
    property string beforeSleepCmd: Config.system.idle.general.before_sleep_cmd ?? "loginctl lock-session"
    property string afterSleepCmd: Config.system.idle.general.after_sleep_cmd ?? Brand.appBin + " screen on"

    // Sleep/Lock monitoring is handled by the Go daemon (login1 DBus).
    // The daemon executes the configured commands itself and emits
    // SUSPEND/WAKE/LOCK events that drive the QML state below.
    property int sleepSubscription: -1

    // Keep the daemon command config in sync.
    function syncSleepCommands() {
        BackendService.call("sleep.setCommands", {
            before: root.beforeSleepCmd,
            after: root.afterSleepCmd,
            lock: root.lockCmd
        });
    }

    function handleSleepEvent(service, data) {
        if (service !== "sleep" || !data) return;
        const event = data.event;
        if (event === "SUSPEND") {
            root.lockBeforeSleep();
            SuspendManager.onPrepareForSleep();
        } else if (event === "WAKE") {
            SuspendManager.onWakingUp();
        } else if (event === "LOCK") {
            root.lockBeforeSleep();
        }
    }

    Component.onCompleted: {
        root.sleepSubscription = BackendService.addSubscription(["sleep"], (service, data) => root.handleSleepEvent(service, data));
        syncSleepCommands();
    }

    // Master Idle Logic. There is no per-second tick while the user is
    // away: a single-shot timer wakes at the next threshold that matters
    // (each listener's timeout and the wallpaper idle-pause delay), so an
    // idle session costs one wake-up per threshold.
    // Idle seconds as of the last threshold reached (0 while active). It
    // steps from threshold to threshold and is not a running clock, so
    // compare it only against one of idleThresholds (Wallpaper compares it
    // with pauseWallpaperIdleDelay); idleSecondsNow() reads the live value.
    property int elapsedIdleTime: 0
    property var triggeredListeners: [] // Keeps track of indices that have fired
    readonly property var idleThresholds: IdleSchedule.thresholds(Config.system.idle.listeners, [WallpaperIdleDelay.idleDelay(Config.performance)])

    property bool _idle: false
    // Idle time accounted up to the start of the pending wait (ms), and
    // when that wait started (wall clock, only to place a mid-wait change).
    property real _idleMs: 0
    property real _stepStart: 0

    // Master Monitor: Detects "absence of activity" almost immediately
    property var masterMonitor: IdleMonitor {
        id: masterMonitor
        timeout: 1 // 1 second threshold to consider the session "idle"
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                root._idle = true;
                root._idleMs = 0;
                root.elapsedIdleTime = 0;
                root._schedule();
            } else {
                idleTimer.stop();
                root._idle = false;
                root.resetIdleState();
            }
        }
    }

    // The timer measures idle time like the old 1 s tick did (it does not
    // run while the machine is suspended); the wall clock only places a
    // threshold change that lands in the middle of a wait.
    property var idleTimer: Timer {
        id: idleTimer
        repeat: false
        onTriggered: {
            root._idleMs += idleTimer.interval;
            root._reached();
        }
    }

    // Listeners or the wallpaper delay changed while idle: account the time
    // spent in the current wait, fire what is now due and re-plan.
    onIdleThresholdsChanged: {
        if (!root._idle)
            return;
        root._idleMs += root._pendingMs();
        idleTimer.stop();
        root._reached();
    }

    function _pendingMs() {
        const spent = Math.max(0, Date.now() - root._stepStart);
        return idleTimer.running ? Math.min(spent, idleTimer.interval) : spent;
    }

    function _reached() {
        root.elapsedIdleTime = Math.floor(root._idleMs / 1000);
        root.checkListeners();
        root._schedule();
    }

    function _schedule() {
        root._stepStart = Date.now();
        const wait = IdleSchedule.nextDelay(root.idleThresholds, root._idleMs);
        if (wait < 0)
            return;
        idleTimer.interval = Math.max(1, Math.ceil(wait));
        idleTimer.restart();
    }

    // Live idle seconds (0 while active) for a reader that needs the
    // running value at one moment; nothing is ticking to provide it.
    function idleSecondsNow() {
        return root._idle ? Math.floor((root._idleMs + root._pendingMs()) / 1000) : 0;
    }

    // Idle hooks are user-configured shell commands; the command string is
    // the script itself and is never spliced into QML source.
    function executeCommand(cmd) {
        if (!cmd)
            return;
        const proc = hookProcess.createObject(root, {
            command: ["sh", "-c", cmd]
        });
        if (proc)
            proc.running = true;
        else
            console.error("Failed to create process for command:", cmd);
    }

    property Component hookProcess: Component {
        Process {
            id: proc
            onExited: proc.destroy()
        }
    }

    function shouldUseInternalSleepLock() {
        const cmd = (root.beforeSleepCmd || "").trim();
        return cmd === "loginctl lock-session"
            || cmd === "loginctl lock-sessions"
            || cmd === Brand.appId + " lock" || cmd === Brand.appBin + " lock" || cmd === Brand.legacyAppId + " lock";
    }

    function lockBeforeSleep() {
        if (root.shouldUseInternalSleepLock()) {
            LockscreenService.lock();
        }
    }

    function checkListeners() {
        const listeners = Config.system.idle.listeners;
        const due = IdleSchedule.due(listeners, root.elapsedIdleTime, root.triggeredListeners);
        for (const i of due) {
            const listener = listeners[i];
            if (listener.onTimeout) {
                console.log("Idle timer " + (listener.timeout || 60) + "s reached: " + listener.onTimeout);
                root.executeCommand(listener.onTimeout);
            }
            root.triggeredListeners.push(i);
        }
    }

    function resetIdleState() {
        let listeners = Config.system.idle.listeners;

        // Execute resume commands for all triggered listeners
        // We iterate backwards to undo latest states first (optional preference)
        for (let i = root.triggeredListeners.length - 1; i >= 0; i--) {
            let idx = root.triggeredListeners[i];
            let listener = listeners[idx];

            if (listener && listener.onResume) {
                console.log("Idle resuming (undoing " + (listener.timeout || 0) + "s): " + listener.onResume);
                root.executeCommand(listener.onResume);
            }
        }

        // Reset counters
        root.elapsedIdleTime = 0;
        root.triggeredListeners = [];
    }
}
