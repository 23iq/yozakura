pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.settings.store
import "../NewLookFlow.js" as Flow

// The one "Try the new Yozakura look" session shared by every place the
// card shows (presets popup, settings Presets page, the startup notice).
// The flow itself is NewLookFlow.js; this runs its commands, counts down
// and marks general.newLookOffered through `<app> config set` (validated
// and hot-applied by the backend, like the CLI).
Singleton {
    id: root

    property string phase: "idle"
    property int seconds: Flow.SECONDS // tests shorten it
    property int left: 0
    property real started: 0
    // Set as soon as the user answers (the config file follows).
    property bool answered: false
    // (args, cb(ok, out, err)) running `<app> preset <args>`. Tests replace it.
    property var run: PresetStudio.run
    // (argv, cb) running a command. Tests replace it.
    property var exec: null
    readonly property string active: PresetStudio.active
    readonly property bool trying: root.phase === "starting" || root.phase === "trying" || root.phase === "ending"
    readonly property bool offer: root.trying || (!root.answered && Flow.shouldOffer(Config.general, root.active))
    readonly property real fraction: Flow.fraction(root.left, root.seconds)

    function send(event) {
        const s = Flow.step(root.phase, event);
        root.phase = s.phase;
        if (s.mark)
            root.markOffered();
        if (s.phase === "trying") {
            root.started = Date.now();
            root.left = root.seconds;
            countdown.restart();
        } else {
            countdown.stop();
        }
        if (s.run)
            root.run(s.run, ok => {
                root.send(ok ? "ok" : "fail");
                if (s.phase === "ending")
                    PresetStudio.refresh();
            });
    }

    function tryIt() {
        root.send("try");
    }

    function keep() {
        root.send("keep");
    }

    function revert() {
        root.send("revert");
    }

    function dismiss() {
        root.send("dismiss");
    }

    function markOffered() {
        root.answered = true;
        const argv = [Brand.appId, "config", "set", "general.newLookOffered", "true"];
        if (root.exec) {
            root.exec(argv, null);
            return;
        }
        const p = proc.createObject(root, {
            "command": argv
        });
        p.running = true;
    }

    Timer {
        id: countdown
        interval: 250
        repeat: true
        onTriggered: {
            root.left = Flow.remaining(root.started, Date.now(), root.seconds);
            if (root.left <= 0)
                root.send("timeout");
        }
    }

    Component {
        id: proc
        Process {
            onExited: destroy()
        }
    }
}
