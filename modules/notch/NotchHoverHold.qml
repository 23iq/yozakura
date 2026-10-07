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
    // Presence that stayed `intentDelay` ms: a pointer only crossing the
    // notch on its way elsewhere never counts (what grows a pill)
    property int intentDelay: 0
    property bool _dwelled: false
    readonly property bool intent: root.held && (root._dwelled || root.intentDelay <= 0)

    onOverChanged: {
        if (root.over)
            leaveTimer.stop();
        else
            leaveTimer.restart();
    }
    onHeldChanged: {
        root._dwelled = false;
        if (root.held)
            intentTimer.restart();
        else
            intentTimer.stop();
    }

    Timer {
        id: intentTimer
        interval: Math.max(0, root.intentDelay)
        onTriggered: root._dwelled = root.held
    }

    Timer {
        id: leaveTimer
        interval: Math.max(0, root.delay)
    }
}
