pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.globals
import qs.modules.services
import "CompileQueue.js" as Queue
import "WarmUp.js" as WarmUp

// Idle-time compile warm-up, once per shell (a singleton; HostedSurfaces
// calls start() on every screen, only the first call counts). Compiles the
// heavy, rarely opened entry points (CompileQueue.ENTRIES) with
// Qt.createComponent(url, Component.Asynchronous), one at a time, never
// while a window is open or opening, and keeps the Component objects so the
// engine keeps their compiled types. Nothing is ever instantiated. A failed
// compile only logs a warning. performance.warmViews = false stops it (and
// releases what it holds).
Singleton {
    id: root

    readonly property bool enabled: WarmUp.enabled(Config.performance)
    // Paths are relative to the repository root, resolved from this file
    // (modules/shell/hosts/) like the shell's own loaders resolve them.
    property var entries: Queue.ENTRIES
    property string base: "../../../"
    // Shortened by tests ({startDelay, gap, busyRetry}); empty = defaults.
    property var timing: ({})

    readonly property bool busy: Visibilities.currentActiveModule !== "" || GlobalStates.settingsWindowVisible
    property bool started: false
    property int index: 0
    property var pending: null
    property var held: []
    property int compiled: 0
    property int failed: 0

    function start() {
        if (root.started)
            return;
        root.started = true;
        root.schedule(Queue.delayBefore(0, root.timing));
    }

    function schedule(ms: int) {
        stepTimer.interval = ms;
        stepTimer.restart();
    }

    function step() {
        const plan = Queue.next({
            "enabled": root.enabled,
            "index": root.index,
            "count": root.entries.length,
            "busy": root.busy,
            "pending": root.pending !== null
        }, root.timing);
        if (plan.action === "wait")
            root.schedule(plan.delay);
        else if (plan.action === "compile")
            root.compile(root.entries[root.index]);
    }

    function compile(path: string) {
        const url = Qt.resolvedUrl(root.base + path);
        const component = Qt.createComponent(url, Component.Asynchronous);
        root.pending = component;
        if (Queue.settled(component.status)) {
            root.finish(component, url);
            return;
        }
        component.statusChanged.connect(() => {
            if (Queue.settled(component.status))
                root.finish(component, url);
        });
    }

    function finish(component, url) {
        if (root.pending !== component)
            return;
        root.pending = null;
        if (component.status === Component.Ready && root.enabled) {
            root.held = root.held.concat([component]);
            root.compiled++;
        } else if (component.status !== Component.Ready) {
            console.warn("CompileWarmUp: could not compile " + url + ": " + component.errorString());
            root.failed++;
        }
        root.index++;
        root.schedule(Queue.delayBefore(root.index, root.timing));
    }

    onEnabledChanged: {
        if (!root.enabled) {
            root.held = [];
            return;
        }
        if (root.started && root.pending === null && !stepTimer.running)
            root.schedule(Queue.delayBefore(root.index, root.timing));
    }

    Timer {
        id: stepTimer
        onTriggered: root.step()
    }
}
