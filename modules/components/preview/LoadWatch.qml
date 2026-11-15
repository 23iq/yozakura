import QtQuick

// LoadWatch: an asynchronous Loader build that never lands (seen offscreen
// under load: the Loader stays Loading) is started again, a few times.
// `arm()` after each setSource; `retry()` asks the owner to build again
// (which arms it again). Once the build is no longer stuck (or no longer
// wanted) the count of tries starts over.
//
//     LoadWatch { id: watch; loader: loader; wanted: root.wanted; onRetry: root.reload() }
//     function reload() { loader.setSource(url, props); watch.arm(); }
Timer {
    id: watch

    // the Loader watched (anything with a `status`)
    property var loader: null
    // false: a stuck build is left alone (it is going away)
    property bool wanted: true
    property int maxTries: 3
    property int tries: 0

    signal retry

    function arm() {
        watch.restart();
    }

    interval: 4000
    onTriggered: {
        if (!watch.loader || watch.loader.status !== Loader.Loading || !watch.wanted) {
            watch.tries = 0;
            return;
        }
        if (watch.tries++ < watch.maxTries)
            watch.retry();
    }
}
