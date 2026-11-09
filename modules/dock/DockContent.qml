pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.config
import qs.modules.bar.panels
import qs.modules.shell
import qs.modules.bar.workspaces
import "../specials/Specials.js" as Specials

Item {
    id: root

    required property ShellScreen screen
    property bool unifiedEffectActive: false

    // Pass pinned state from parent or config
    readonly property bool keepHidden: Config.dock?.keepHidden ?? false
    property bool pinned: Config.dock?.pinnedOnStartup ?? false

    // Theme configuration
    // "integrated" without a bar that hosts it falls back to the default look
    readonly property string theme: (Config.dock?.theme ?? "default") === "integrated" ? "default" : (Config.dock?.theme ?? "default")
    readonly property bool isFloating: theme === "floating"
    readonly property bool isDefault: theme === "default"

    // Position: exactly dock.position (the dock has no top edge; "top" is
    // drawn at the bottom). A bar on the same edge is stacked (barStack), the
    // configured edge is never remapped.
    readonly property string userPosition: Config.dock?.position ?? "bottom"
    readonly property string position: userPosition === "left" || userPosition === "right" ? userPosition : "bottom"

    // Depth of the bar panels on the dock's edge: the dock sits outside them.
    readonly property int barStack: {
        const list = EdgeService.panelsFor(root.screen, true);
        let depth = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].pos === root.position)
                depth = Math.max(depth, list[i].size || 0);
        }
        return depth;
    }

    readonly property bool isBottom: position === "bottom"
    readonly property bool isLeft: position === "left"
    readonly property bool isRight: position === "right"
    readonly property bool isVertical: isLeft || isRight

    // Margin calculations
    readonly property int dockMargin: Config.dock?.margin ?? 8
    readonly property int compositorGapsOut: Config.compositor?.gapsOut ?? 4

    readonly property int windowSideMargin: dockMargin > 0 ? Math.max(0, dockMargin - compositorGapsOut) : 0
    readonly property int edgeSideMargin: isDefault ? 0 : dockMargin

    // Reference to the bar panel on this screen
    readonly property var barPanelRef: Visibilities.barPanels[screen.name]
    readonly property bool barPinned: {
        if (barPanelRef && typeof barPanelRef.pinned !== 'undefined') {
            return barPanelRef.pinned;
        }
        return true;
    }

    // Monitor reference and the toplevels it shows: an open special
    // workspace covers the active one, so its windows count instead.
    readonly property var compositorMonitor: YozdService.monitorFor(screen)
    readonly property string openSpecial: CompositorData.specialWorkspaceNames[screen.name] || ""
    // Plain `var` views of YozdService's list holders.
    readonly property var _clients: YozdService.clients
    readonly property var _workspaces: YozdService.workspaces
    readonly property var toplevels: (!compositorMonitor || !compositorMonitor.activeWorkspace || !_clients || !_clients.values) ? [] : Specials.visibleClients(_clients.values, _workspaces ? _workspaces.values : [], compositorMonitor.activeWorkspace.id, openSpecial, YozdService.compositorName === "niri" ? CompositorData.niriSpecialNames : null)

    // Check if there are any windows on the current monitor and workspace
    readonly property bool hasWindows: toplevels.length > 0

    // Fullscreen detection - scoped to this monitor so the effect only
    // applies to the screen that actually has the fullscreen window
    readonly property bool activeWindowFullscreen: {
        if (!compositorMonitor || !toplevels)
            return false;

        for (var i = 0; i < toplevels.length; i++) {
            if (toplevels[i].fullscreen == true && toplevels[i].monitor === compositorMonitor.id) {
                return true;
            }
        }
        return false;
    }

    // Reveal logic
    property bool reveal: {
        // Priority: Fullscreen check
        if (activeWindowFullscreen) {
            return (Config.dock?.availableOnFullscreen ?? false) && (Config.dock?.hoverToReveal && dockMouseArea.containsMouse);
        }

        // If keepHidden is true, ONLY show on hover
        // IMPORTANT: keepHidden overrides pinned and desktop mode
        if (keepHidden) {
            return (Config.dock?.hoverToReveal && dockMouseArea.containsMouse);
        }

        return root.pinned || (Config.dock?.hoverToReveal && dockMouseArea.containsMouse) || !hasWindows;
    }

    readonly property int totalMargin: root.windowSideMargin + root.edgeSideMargin
    readonly property int shadowSpace: 32
    readonly property int dockSize: Config.dock?.height ?? 56

    implicitWidth: root.isVertical ? dockSize + totalMargin + shadowSpace * 2 : dockContent.implicitWidth + shadowSpace * 2
    implicitHeight: root.isVertical ? dockContent.implicitHeight + shadowSpace * 2 : dockSize + totalMargin + shadowSpace * 2

    readonly property int frameOffset: Config.bar?.frameEnabled ? (Config.bar?.frameThickness ?? 6) : 0
    readonly property int edgeOffset: frameOffset + barStack

    // The hitbox for the mask
    readonly property Item dockHitbox: dockMouseArea

    // Content sizing helper
    Item {
        id: dockContent
        implicitWidth: root.isVertical ? root.dockSize : dockLayoutHorizontal.implicitWidth + Space.s * 2
        implicitHeight: root.isVertical ? dockLayoutVertical.implicitHeight + Space.s * 2 : root.dockSize
    }

    MouseArea {
        id: dockMouseArea
        hoverEnabled: true

        // Size
        width: root.isVertical ? (root.reveal ? root.dockSize + root.totalMargin + root.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4) + root.edgeOffset) : dockContent.implicitWidth + 20
        height: root.isVertical ? dockContent.implicitHeight + 20 : (root.reveal ? root.dockSize + root.totalMargin + root.shadowSpace : (Config.dock?.hoverRegionHeight ?? 4) + root.edgeOffset)

        // Position using x/y
        x: {
            const base = root.isBottom ? (parent.width - width) / 2 : (root.isLeft ? 0 : parent.width - width);
            // If left, keep at 0 to cover the frame area. If right, keep at right edge.
            if (root.isLeft)
                return 0;
            if (root.isRight)
                return parent.width - width;
            return base;
        }
        y: {
            const base = root.isVertical ? (parent.height - height) / 2 : parent.height - height;
            // If bottom, keep at bottom edge to cover the frame area.
            if (root.isBottom)
                return parent.height - height;
            return base;
        }

        Behavior on x {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }

        Behavior on width {
            enabled: Config.animDuration > 0 && root.isVertical
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }

        Behavior on height {
            enabled: Config.animDuration > 0 && !root.isVertical
            NumberAnimation {
                duration: Motion.exit.duration
                easing.type: Motion.morph.easing
            }
        }

        // Dock container
        Item {
            id: dockContainer

            // Corner size for default theme
            readonly property int cornerSize: root.isDefault && Config.roundness > 0 ? Config.roundness + 4 : 0

            // Size
            width: {
                if (root.isDefault && cornerSize > 0) {
                    if (root.isBottom)
                        return dockContent.implicitWidth + cornerSize * 2;
                }
                return dockContent.implicitWidth;
            }
            height: {
                if (root.isDefault && cornerSize > 0) {
                    if (root.isVertical)
                        return dockContent.implicitHeight + cornerSize * 2;
                }
                return dockContent.implicitHeight;
            }

            // Position using x/y
            x: {
                const base = root.isBottom ? (parent.width - width) / 2 : (root.isLeft ? root.edgeSideMargin : parent.width - width - root.edgeSideMargin);
                if (root.isLeft)
                    return base + root.edgeOffset;
                if (root.isRight)
                    return base - root.edgeOffset;
                return base;
            }
            y: {
                const base = root.isVertical ? (parent.height - height) / 2 : parent.height - height - root.edgeSideMargin;
                if (root.isBottom)
                    return base - root.edgeOffset;
                return base;
            }

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.exit.duration
                    easing.type: Motion.morph.easing
                }
            }
            Behavior on y {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.exit.duration
                    easing.type: Motion.morph.easing
                }
            }

            // Animation for dock reveal
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.exit.duration
                    easing.type: Motion.enter.easing
                }
            }

            // Slide animation
            transform: Translate {
                x: root.isVertical ? (root.reveal ? 0 : (root.isLeft ? -(dockContainer.width + root.edgeSideMargin) : (dockContainer.width + root.edgeSideMargin))) : 0
                y: root.isBottom ? (root.reveal ? 0 : (dockContainer.height + root.edgeSideMargin)) : 0
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.exit.duration
                        easing.type: Motion.morph.easing
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Motion.exit.duration
                        easing.type: Motion.morph.easing
                    }
                }
            }

            // Full background with edge fillets (default theme)
            DockShape {
                id: dockShape
                visible: root.isDefault
                anchors.fill: parent
                position: root.position
                cornerSize: dockContainer.cornerSize
                contentWidth: dockContent.implicitWidth
                contentHeight: dockContent.implicitHeight
                fullRadius: Look.radius("surface")
            }

            // Background for floating theme
            StyledRect {
                id: dockBackgroundFloating
                visible: root.isFloating
                anchors.fill: parent
                variant: "bg"
                glassSurface: "dock"
                anchorEdge: root.position
                // enableShadow: true
                radius: Look.radius("surface", height)
                enableBorder: !root.unifiedEffectActive
            }

            // Horizontal layout
            DockItems {
                id: dockLayoutHorizontal
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: (dockContent.implicitHeight - implicitHeight) / 2
                visible: !root.isVertical
                screen: root.screen
                pinned: root.pinned
                onPinToggled: root.pinned = !root.pinned
            }

            // Vertical layout
            DockItems {
                id: dockLayoutVertical
                anchors.horizontalCenter: parent.horizontalCenter
                y: dockContainer.cornerSize + (dockContent.implicitHeight - implicitHeight) / 2
                visible: root.isVertical
                vertical: true
                position: root.position
                screen: root.screen
                pinned: root.pinned
                onPinToggled: root.pinned = !root.pinned
            }

            // Unified outline
            DockOutline {
                anchors.fill: parent
                z: 5000
                shown: root.isDefault && !root.unifiedEffectActive
                position: root.position
                cornerSize: dockContainer.cornerSize
                shape: dockShape
            }
        }
    }
}
