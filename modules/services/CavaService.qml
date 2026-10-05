pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "CavaVisualizer.js" as Cava
import qs.modules.globals

// Shared cava spectrum for the notch visualizer and the music-reactive window
// border (BorderPulse). cava only runs while at least one consumer registered
// itself as active (media playing, island revealed / pulse enabled); it stops
// shortly after the last one goes away, so an idle shell costs no CPU. Each
// consumer applies its own setting (e.g. the notch checks notch.visualizer).
Singleton {
    id: root

    readonly property int barCount: 24
    readonly property int framerate: 60
    // Flipped off when cava is missing so we never respawn in a loop.
    property bool available: true
    property var values: Cava.silence(barCount)
    readonly property bool running: cavaProcess.running

    property int _failures: 0
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
                const frame = Cava.parseFrame(data, root.barCount);
                if (frame) {
                    root._failures = 0;
                    root.values = frame;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
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
