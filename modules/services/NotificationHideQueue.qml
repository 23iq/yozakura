import QtQuick

// Second step of a popup timeout (Notifications.timeoutNotification): the
// service announces timeoutWithAnimation(id), then hides the popup `delay` ms
// later, once the exit animation ran. Every scheduled id keeps its own
// deadline, so a burst of timeouts never drops one (a dropped id left its
// popup shown for good).
QtObject {
    id: queue

    property int delay: 350
    // [{ id, at }], earliest deadline first (the delay is the same for all)
    property var _pending: []

    signal expired(var id)

    function schedule(id) {
        queue._pending = queue._pending.filter(p => p.id !== id).concat([
            {
                "id": id,
                "at": Date.now() + queue.delay
            }
        ]);
        queue._arm();
    }

    function _arm() {
        if (queue._pending.length === 0) {
            queue.timer.stop();
            return;
        }
        queue.timer.interval = Math.max(0, queue._pending[0].at - Date.now());
        queue.timer.restart();
    }

    function _fire() {
        const now = Date.now();
        const due = queue._pending.filter(p => p.at <= now);
        queue._pending = queue._pending.filter(p => p.at > now);
        due.forEach(p => queue.expired(p.id));
        queue._arm();
    }

    property Timer timer: Timer {
        repeat: false
        onTriggered: queue._fire()
    }
}
