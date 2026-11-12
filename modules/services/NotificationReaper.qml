import QtQuick

// Destroys the notification objects Notifications drops from its list
// (discarded, cleared, trimmed from history), so they and their timers do
// not pile up for the whole session. Each one is kept `grace` ms first: a
// popup or history row may still be animating it out, and an image download
// (5 s timeout) may still answer into it.
QtObject {
    id: reaper

    property int grace: 10000
    // obj => bool: back in use (never destroyed then)
    property var isLive: obj => false
    // [{ obj, at }], earliest first (the grace is the same for all)
    property var _dead: []

    function retire(objs) {
        const at = Date.now() + reaper.grace;
        (objs || []).forEach(obj => {
            if (obj && !reaper._dead.some(d => d.obj === obj))
                reaper._dead.push({
                    "obj": obj,
                    "at": at
                });
        });
        reaper._arm();
    }

    function _arm() {
        if (reaper._dead.length === 0 || reaper.timer.running)
            return;
        reaper.timer.interval = Math.max(0, reaper._dead[0].at - Date.now());
        reaper.timer.start();
    }

    function _fire() {
        const now = Date.now();
        const due = reaper._dead.filter(d => d.at <= now);
        reaper._dead = reaper._dead.filter(d => d.at > now);
        due.forEach(d => {
            if (!reaper.isLive(d.obj))
                d.obj.destroy();
        });
        reaper._arm();
    }

    property Timer timer: Timer {
        repeat: false
        onTriggered: reaper._fire()
    }
}
