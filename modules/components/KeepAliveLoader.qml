import QtQuick

// A Loader for a big window that is opened now and then (Settings): created
// asynchronously on the first open, kept alive (hidden by its own `visible`
// binding) for `keepFor` ms after it was closed so reopening is instant, then
// released. keepFor 0 releases it as soon as it closes.
//   wanted   the window is shown now
//   allowed  loading is allowed at all (e.g. SuspendManager.wakeReady)
Loader {
    id: root

    property bool wanted: false
    property bool allowed: true
    property int keepFor: 0
    // Kept loaded although not wanted (until the release timer fires)
    readonly property bool kept: root._kept && !root.wanted
    property bool _kept: false

    asynchronous: true
    active: root.allowed && (root.wanted || root._kept)

    onWantedChanged: {
        if (root.wanted) {
            releaseTimer.stop();
            root._kept = root.keepFor > 0;
        } else if (root._kept) {
            releaseTimer.restart();
        }
    }

    onKeepForChanged: {
        if (root.keepFor <= 0) {
            releaseTimer.stop();
            root._kept = false;
        } else if (root.wanted) {
            root._kept = true;
        } else if (root._kept) {
            releaseTimer.restart();
        }
    }

    Timer {
        id: releaseTimer
        interval: Math.max(1, root.keepFor)
        onTriggered: root._kept = false
    }
}
