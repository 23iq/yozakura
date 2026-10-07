import QtQuick

// Debounced pointer presence over the notch: `held` turns on as soon as the
// pointer is `over` it and stays on for `delay` ms after it left, so
// crossing a gap, a child control or the concave corners never collapses
// the expanded notch for a frame (and re-expands it right after).
Item {
    id: root
    visible: false

    property bool over: false
    property int delay: 200
    readonly property bool held: root.over || leaveTimer.running

    onOverChanged: {
        if (root.over)
            leaveTimer.stop();
        else
            leaveTimer.restart();
    }

    Timer {
        id: leaveTimer
        interval: Math.max(0, root.delay)
    }
}
