import QtQuick

// Whether a live preview should exist now: `awake` follows `shown` (an item's
// effective visibility: false while a cached page, the kept-alive Settings
// window, another tab or the home under a page hides it), true at once,
// false only once it stayed hidden `holdMs` (a quick switch of tabs keeps
// the part). LivePart, LiveBars and LiveScreen build nothing while asleep.
//
//     LiveHold { id: hold; shown: root.visible }
//     Loader { active: hold.awake }
QtObject {
    id: root

    property bool shown: true
    property int holdMs: 1500
    property bool awake: false

    onShownChanged: {
        if (root.shown) {
            root.timer.stop();
            root.awake = true;
        } else {
            root.timer.restart();
        }
    }
    Component.onCompleted: root.awake = root.shown

    property Timer timer: Timer {
        interval: root.holdMs
        onTriggered: root.awake = false
    }
}
