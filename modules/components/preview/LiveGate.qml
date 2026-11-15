pragma Singleton

import QtQuick

// The queue live previews are built from: a page shows at once and its real
// parts (LivePart, the settings' LiveBars) are created after it, one per
// step, never in the frames that lay the page out. `ask(owner, build)`
// runs `build()` in turn; an owner destroyed before its turn calls
// `forget(owner)` from its Component.onDestruction.
QtObject {
    id: root

    // the first build waits this long, then one more per `step`
    property int pause: 60
    property int step: 16
    property var queue: []

    function ask(owner, build) {
        // (an owner already waiting keeps its place: one build each)
        const waiting = root.queue.find(e => e.owner === owner);
        if (waiting) {
            waiting.build = build;
            return;
        }
        root.queue.push({
            "owner": owner,
            "build": build
        });
        if (!root.timer.running) {
            root.timer.interval = root.pause;
            root.timer.start();
        }
    }

    // an owner going away drops its builds (call from Component.onDestruction)
    function forget(owner) {
        root.queue = root.queue.filter(e => e.owner !== owner);
    }

    property Timer timer: Timer {
        repeat: true
        onTriggered: {
            root.timer.interval = root.step;
            while (root.queue.length > 0) {
                const next = root.queue.shift();
                // (a destroyed owner reads as null / has no parent left)
                if (next.owner && next.owner.parent !== undefined) {
                    next.build();
                    break;
                }
            }
            if (root.queue.length === 0)
                root.timer.stop();
        }
    }
}
