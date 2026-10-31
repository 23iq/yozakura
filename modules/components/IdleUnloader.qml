import QtQuick

// Fires unload() once `idle` has been true for `delay` ms. Views that are
// kept loaded for speed use it to release their objects and image caches
// after they have been closed for a while. It only decides when; what is
// dropped stays with the owner, and anything that must survive (drafts,
// scroll, chat) has to live in a service, not in the view.
Item {
    id: root

    // The view is not in use right now
    property bool idle: false
    property bool active: true
    property int delay: 60000

    signal unload

    visible: false

    Timer {
        interval: root.delay
        running: root.active && root.idle
        onTriggered: root.unload()
    }
}
