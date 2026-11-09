import QtQuick

// The screen list for per-screen windows that always exist (wallpaper,
// desktop, bar panel, OSD): a Variants model that lets hotplugged outputs in
// only once the output list has held still for `interval`.
//
// QtWayland crashes (oldestEnteredScreen) when a surface is created on an
// output in the same tick that output appears, and a hotplug often comes as
// a burst (add, mode change, re-add). The screens present when this object
// is created pass at once, so the first start is not delayed; screens added
// later wait out the settle period. Removed screens leave at once, so their
// windows go with the output as before.
QtObject {
    id: settle

    // The raw list (Quickshell.screens).
    property var source: []
    // How long the list must hold still before an added screen is let in.
    property int interval: 400

    // The settled list: bind a Variants model to it.
    readonly property var screens: _screens
    // false while an added screen waits for the list to settle.
    readonly property bool settled: !_timer.running

    property var _screens: []
    property bool _ready: false

    function _list(): var {
        return settle.source ? Array.from(settle.source) : [];
    }

    function _sync(): void {
        if (!_ready)
            return;
        const src = _list();
        const kept = _screens.filter(s => src.indexOf(s) >= 0);
        if (kept.length !== _screens.length)
            _screens = kept;
        if (src.some(s => kept.indexOf(s) < 0))
            _timer.restart();
        else
            _timer.stop();
    }

    onSourceChanged: _sync()

    Component.onCompleted: {
        _screens = _list();
        _ready = true;
    }

    property Timer _timer: Timer {
        interval: Math.max(1, settle.interval)
        onTriggered: settle._screens = settle._list()
    }
}
