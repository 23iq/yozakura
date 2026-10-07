import QtQuick

// Mouse over a session row (TmuxSessionDelegate): hover selects, click opens
// or creates, right click toggles the options, long press renames, a left
// swipe asks to quit. Off while the row is being renamed or deleted, so
// its cancel / confirm buttons get the clicks.
MouseArea {
    id: area

    required property var row
    readonly property var tab: area.row.tab

    property real startX: 0
    property real startY: 0
    property bool isDragging: false
    property bool longPressTriggered: false

    hoverEnabled: !area.row.list.isScrolling
    enabled: !area.row.isInDeleteMode && !area.row.isInRenameMode
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    function select() {
        area.tab.selectedIndex = area.row.index;
        area.row.list.currentIndex = area.row.index;
    }

    onEntered: {
        if (!area.row.list.isScrolling && !area.tab.deleteMode && !area.tab.renameMode && area.tab.expandedItemIndex === -1)
            area.select();
    }

    onClicked: mouse => {
        const t = area.tab;
        const data = area.row.modelData;
        if (t.deleteMode && data.name !== t.sessionToDelete) {
            t.cancelDeleteMode();
            return;
        }
        if (t.renameMode && data.name !== t.sessionToRename) {
            t.cancelRenameMode();
            return;
        }
        if (mouse.button === Qt.LeftButton) {
            if (area.row.isExpanded)
                return;
            if (data.isCreateSpecificButton)
                t.createTmuxSession(data.sessionNameToCreate);
            else if (data.isCreateButton)
                t.createTmuxSession();
            else
                t.attachToSession(data.name);
        } else if (!area.row.isCreate) {
            // Right click toggles the options menu
            t.expandedItemIndex = t.expandedItemIndex === area.row.index ? -1 : area.row.index;
            t.selectedOptionIndex = 0;
            t.keyboardNavigation = false;
            area.select();
        }
    }

    onPressed: mouse => {
        area.startX = mouse.x;
        area.startY = mouse.y;
        area.isDragging = false;
        area.longPressTriggered = false;
        if (mouse.button !== Qt.RightButton)
            longPressTimer.start();
    }

    onPositionChanged: mouse => {
        if (!area.pressed || mouse.button === Qt.RightButton)
            return;
        const dx = mouse.x - area.startX;
        const dy = mouse.y - area.startY;
        // More than 10 px is a drag; a left swipe asks to quit
        if (Math.sqrt(dx * dx + dy * dy) > 10) {
            area.isDragging = true;
            longPressTimer.stop();
            if (dx < -50 && Math.abs(dy) < 30 && !area.row.isCreate && !area.longPressTriggered) {
                area.tab.enterDeleteMode(area.row.modelData.name);
                area.longPressTriggered = true;
            }
        }
    }

    onReleased: {
        longPressTimer.stop();
        area.isDragging = false;
        area.longPressTriggered = false;
    }

    Timer {
        id: longPressTimer
        interval: 800
        onTriggered: {
            if (!area.isDragging && !area.row.isCreate) {
                area.tab.enterRenameMode(area.row.modelData.name);
                area.longPressTriggered = true;
            }
        }
    }
}
