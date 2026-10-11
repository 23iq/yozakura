import QtQuick

// Vertical swipe over the dashboard's tab content: `swiped(1)` for up (the
// next tab), `swiped(-1)` for down. Clicks pass through to the tab.
MouseArea {
    id: root

    property real startY: 0
    property real startX: 0
    property bool swiping: false
    property real swipeThreshold: 50

    signal swiped(int delta)

    propagateComposedEvents: true
    preventStealing: false

    onPressed: mouse => {
        root.startY = mouse.y;
        root.startX = mouse.x;
        root.swiping = false;
        mouse.accepted = false;
    }

    // Only a mostly vertical move counts as a swipe.
    onPositionChanged: mouse => {
        if (Math.abs(mouse.y - root.startY) > 20 && Math.abs(mouse.x - root.startX) < 30)
            root.swiping = true;
    }

    onReleased: mouse => {
        const deltaY = mouse.y - root.startY;
        if (root.swiping && Math.abs(deltaY) > root.swipeThreshold)
            root.swiped(deltaY < 0 ? 1 : -1);
        root.swiping = false;
        mouse.accepted = false;
    }
}
