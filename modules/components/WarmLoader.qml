import QtQuick

// A Loader for a heavy view that is created once and kept (launcher,
// dashboard). The item is incubated asynchronously, over several frames, so
// the first open does not freeze the GUI thread (the shell has no QML disk
// cache: see AGENTS.md). Callers never read `item` straight after activating:
//   request(cb)  cb(item) at once when ready, otherwise once it has loaded;
//                the latest request wins, cancel() drops it
//   warm()       start loading without a consumer (warm-up after startup)
// The caller re-checks in cb that the item is still wanted (the module may
// have been closed or rerouted while it was loading).
Loader {
    id: root

    property var _pending: null
    readonly property bool ready: root.status === Loader.Ready && root.item !== null
    readonly property bool pending: root._pending !== null

    active: false
    asynchronous: true

    function request(cb) {
        if (root.ready) {
            root._pending = null;
            cb(root.item);
            return;
        }
        root._pending = cb;
        root.active = true;
    }

    function cancel() {
        root._pending = null;
    }

    function warm() {
        root.active = true;
    }

    onLoaded: {
        const cb = root._pending;
        root._pending = null;
        if (cb && root.item)
            cb(root.item);
    }
}
