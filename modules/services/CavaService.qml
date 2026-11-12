pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "CavaVisualizer.js" as Cava
import qs.modules.globals
import qs.config

// Shared cava spectrum for the notch visualizer and the music-reactive window
// border (BorderPulse). cava only runs while at least one consumer registered
// itself as active (media playing, island revealed / pulse enabled); it stops
// shortly after the last one goes away, so an idle shell costs no CPU. Each
// consumer applies its own setting (e.g. the notch checks notch.visualizer).
Singleton {
    id: root

    readonly property int barCount: 24
    // Frames per second cava delivers. Each frame redraws the screen-sized
    // panel window that hosts the notch visualizer, so this is kept at 30
    // (the bars ease between frames, see NotchVisualizer.easing); the user
    // can change it (performance.visualizerFps, clamped to 15..60). A running
    // cava is restarted once with the new rate (rateTimer).
    readonly property int framerate: Cava.clampRate(Config.performance ? Config.performance.visualizerFps : undefined)
    // Identical frames (silence, a held note) are dropped, after this many
    // repeats so eased consumers can settle on the last level first.
    readonly property int settleFrames: Math.ceil(framerate * 0.4)
    // Flipped off when cava is missing so we never respawn in a loop.
    property bool available: true
    property var values: Cava.silence(barCount)
    readonly property bool running: cavaProcess.running

    property int _failures: 0
    property int _repeats: 0
    // Set while cava is stopped only to pick up a new framerate: its exit is
    // then not a failure and it starts again at once.
    property bool _rateRestart: false
    property var _consumers: ({})
    property int consumerCount: 0
    readonly property bool wanted: available && consumerCount > 0
    readonly property string configPath: Brand.runtimeFile("-cava.conf")

    // Visualizers register by a unique key so several screens can share one
    // cava process.
    function setConsumer(key, active) {
        if (!key || (!!_consumers[key]) === !!active)
            return;
        const next = Object.assign({}, _consumers);
        if (active)
            next[key] = true;
        else
            delete next[key];
        _consumers = next;
        consumerCount = Object.keys(next).length;
    }

    // Levels for a visualizer with `count` bars (0..1 each).
    function levels(count) {
        return Cava.resample(values, count);
    }

    onWantedChanged: {
        if (wanted) {
            _failures = 0;
            stopTimer.stop();
            restartTimer.stop();
            cavaProcess.running = true;
        } else {
            restartTimer.stop();
            stopTimer.restart();
        }
    }

    // The command (and its config) is read when cava starts, so a new rate
    // needs a restart. Debounced: a slider dragged across several values
    // restarts cava once.
    onFramerateChanged: rateTimer.restart()

    Timer {
        id: rateTimer
        interval: 500
        onTriggered: {
            if (!cavaProcess.running || root._rateRestart)
                return;
            root._rateRestart = true;
            cavaProcess.running = false;
        }
    }

    // Grace period so track changes (brief pause/play flips) do not respawn cava.
    Timer {
        id: stopTimer
        interval: 1500
        onTriggered: {
            if (!root.wanted) {
                cavaProcess.running = false;
                root.values = Cava.silence(root.barCount);
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: {
            if (root.wanted)
                cavaProcess.running = true;
        }
    }

    Process {
        id: cavaProcess
        running: false
        // exec keeps cava as the tracked child so stopping the Process kills it.
        // If the shell dies, cava exits on SIGPIPE at its next frame.
        command: ["sh", "-c", "umask 077 && printf '%s' \"$1\" > \"$2\" && exec cava -p \"$2\"", Brand.appId + "-cava", Cava.buildConfig(root.barCount, root.framerate), root.configPath]
        stdout: SplitParser {
            onRead: data => {
                // Only a changed frame allocates and notifies; repeats stop
                // after settleFrames, so a silent stream costs no redraws.
                const frame = Cava.readFrame(data, root.barCount, root.values);
                if (!frame)
                    return;
                root._failures = 0;
                if (frame !== root.values) {
                    root._repeats = 0;
                    root.values = frame;
                } else if (root._repeats < root.settleFrames) {
                    root._repeats++;
                    root.values = frame.slice();
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root._rateRestart) {
                root._rateRestart = false;
                // Next tick: the Process finishes its own exit handling first.
                Qt.callLater(() => {
                    if (root.wanted && !cavaProcess.running)
                        cavaProcess.running = true;
                });
                return;
            }
            root.values = Cava.silence(root.barCount);
            if (exitCode === 127) {
                root.available = false;
                console.warn("CavaService: cava not found, audio visualizers disabled");
                return;
            }
            // Retry unexpected exits (e.g. PipeWire restart), but give up after
            // repeated failures until the visualizer is re-activated.
            if (root.wanted && ++root._failures < 5)
                restartTimer.restart();
        }
    }
}
