pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.config

Item {
    id: root

    property var windowData
    property var toplevel
    property var monitorData: null
    property real scale
    property real availableWorkspaceWidth
    property real availableWorkspaceHeight
    property real xOffset: 0
    property real yOffset: 0

    property bool hovered: false
    property bool pressed: false
    property bool atInitPosition: (initX == x && initY == y)

    property string barPosition: "top"
    property int barReserved: 0

    // Search highlighting
    property bool isSearchMatch: false
    property bool isSearchSelected: false

    // Override position tracking for immediate visual update
    property real overrideX: -1
    property real overrideY: -1
    property bool useOverridePosition: false

    // Cache calculated values
    readonly property real initX: {
        if (useOverridePosition && overrideX >= 0)
            return overrideX;

        let base = (windowData?.at?.[0] || 0) - (monitorData?.x || 0);
        if (barPosition === "left")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + xOffset);
    }
    readonly property real initY: {
        if (useOverridePosition && overrideY >= 0)
            return overrideY;
        let base = (windowData?.at?.[1] || 0) - (monitorData?.y || 0);
        if (barPosition === "top")
            base -= barReserved;
        return Math.round(Math.max(base * scale, 0) + yOffset);
    }
    readonly property real targetWindowWidth: Math.round((windowData?.size[0] || 100) * scale)
    readonly property real targetWindowHeight: Math.round((windowData?.size[1] || 100) * scale)
    readonly property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60
    readonly property string iconPath: AppSearch.guessIcon(windowData?.class || "")

    signal dragStarted
    signal dragFinished(int targetWorkspace)
    signal windowClicked
    signal windowClosed

    // The overview that lays the windows out (Overview or OverviewStrip: dragArea >
    // window > windowSpace > belt > overview); duck-typed, both expose the grid.
    function overviewHost() {
        return root.parent.parent.parent;
    }

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: atInitPosition ? 1 : 99999

    Drag.active: false
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    clip: true

    // Timer to reset override position after a delay (waiting for YozdService update)
    Timer {
        id: resetOverrideTimer
        interval: 200
        onTriggered: {
            root.useOverridePosition = false;
        }
    }

    // Watch for windowData changes to reset override when real data updates
    onWindowDataChanged: {
        if (useOverridePosition) {
            resetOverrideTimer.restart();
        }
    }

    // Off while dragging: the pointer drives x/y, an animation would lag it
    Behavior on x {
        enabled: Motion.morph.duration > 0 && !root.useOverridePosition && !root.pressed
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on y {
        enabled: Motion.morph.duration > 0 && !root.useOverridePosition && !root.pressed
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on width {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }
    Behavior on height {
        enabled: Motion.morph.duration > 0
        NumberAnimation {
            duration: Motion.morph.duration
            easing.type: Motion.morph.easing
        }
    }

    OverviewWindowFace {
        id: face
        toplevel: root.toplevel
        windowData: root.windowData
        iconPath: root.iconPath
        hovered: root.hovered
        pressed: root.pressed
        matched: root.isSearchMatch
        selected: root.isSearchSelected
        compact: root.compactMode
        glow: root.isSearchSelected && !root.Drag.active
        tooltipShown: dragArea.containsMouse && !root.Drag.active
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: parent

        // Hover only highlights; focus happens on click.
        onEntered: root.hovered = true
        onExited: root.hovered = false

        onPressed: mouse => {
            root.pressed = true;
            root.Drag.active = true;
            root.Drag.source = root;
            root.dragStarted();
        }

        onReleased: mouse => {
            const overviewRoot = root.overviewHost();
            let targetWorkspace = overviewRoot.draggingTargetWorkspace;

            root.pressed = false;
            root.Drag.active = false;

            if (mouse.button === Qt.LeftButton) {
                // If targetWorkspace is -1, calculate it from current position
                if (targetWorkspace === -1) {
                    // Calculate which workspace we're over based on position
                    const workspaceColIndex = Math.floor((root.x - root.xOffset + root.availableWorkspaceWidth / 2) / (root.availableWorkspaceWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));
                    const workspaceRowIndex = Math.floor((root.y - root.yOffset + root.availableWorkspaceHeight / 2) / (root.availableWorkspaceHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));

                    if (workspaceColIndex >= 0 && workspaceColIndex < overviewRoot.columns && workspaceRowIndex >= 0 && workspaceRowIndex < overviewRoot.rows) {
                        targetWorkspace = overviewRoot.workspaceGroup * overviewRoot.workspacesShown + workspaceRowIndex * overviewRoot.columns + workspaceColIndex + 1;
                    } else {
                        // Out of bounds, default to current workspace
                        targetWorkspace = windowData?.workspace.id;
                    }
                }

                root.dragFinished(targetWorkspace);
                overviewRoot.draggingTargetWorkspace = -1;

                // Check if moving to different workspace
                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                    // Moving to different workspace
                    if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                        // Calculate position in the target workspace
                        // Get target workspace offset
                        const targetColIndex = (targetWorkspace - 1) % overviewRoot.columns;
                        const targetRowIndex = Math.floor((targetWorkspace - 1) % overviewRoot.workspacesShown / overviewRoot.columns);
                        const targetXOffset = Math.round((overviewRoot.workspaceImplicitWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetColIndex + overviewRoot.workspacePadding / 2);
                        const targetYOffset = Math.round((overviewRoot.workspaceImplicitHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetRowIndex + overviewRoot.workspacePadding / 2);

                        // Calculate relative position in target workspace
                        const relativeX = root.x - targetXOffset;
                        const relativeY = root.y - targetYOffset;

                        // Convert to percentage
                        const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                        const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);

                        // Move to workspace and set position
                        YozdService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        YozdService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);

                        // Force immediate window data update
                        CompositorData.updateWindowList();
                    } else {
                        // Just move workspace without repositioning
                        YozdService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);

                        // Force immediate window data update
                        CompositorData.updateWindowList();
                    }

                    // Reset position in overview
                    root.x = root.initX;
                    root.y = root.initY;
                } else if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                    // Dropped on same workspace and floating - reposition
                    const relativeX = root.x - root.xOffset;
                    const relativeY = root.y - root.yOffset;

                    const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                    const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);

                    const draggedX = root.x;
                    const draggedY = root.y;

                    YozdService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);

                    // Force immediate window data update
                    CompositorData.updateWindowList();

                    // Set override position for immediate visual update
                    root.overrideX = draggedX;
                    root.overrideY = draggedY;
                    root.useOverridePosition = true;

                    root.x = draggedX;
                    root.y = draggedY;

                    resetOverrideTimer.restart();
                } else {
                    // Reset position for non-floating or non-moved windows
                    root.x = root.initX;
                    root.y = root.initY;
                }
            }
        }

        onClicked: mouse => {
            if (!root.windowData)
                return;

            if (mouse.button === Qt.LeftButton) {
                // Single click just focuses the window without closing overview
                YozdService.dispatch(`focuswindow address:${windowData.address}`);
            } else if (mouse.button === Qt.MiddleButton) {
                root.windowClosed();
            }
        }

        onDoubleClicked: mouse => {
            if (!root.windowData)
                return;

            if (mouse.button === Qt.LeftButton) {
                // Double click closes overview and focuses window
                root.windowClicked();
            }
        }
    }
}
