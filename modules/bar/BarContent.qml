pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.bar.workspaces
import qs.modules.bar.panels
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config
import "BarLayout.js" as BarLayout
import "panels/PanelLayout.js" as PanelLayout
import "panels/PanelStyles.js" as PanelStyles

// One bar panel: auto-hide, hover hitbox, edge placement and module groups.
// What the panel looks like is its style component (panels/styles/, picked
// from panels/PanelStyles.js); `panel` is one spec of panels/PanelLayout.js.
// Modules get this item as their `bar` / `barRoot`.
Item {
    id: root

    required property ShellScreen screen
    // Normalized panel spec; null = the legacy single bar
    property var panel: null
    // The panel the notch and single-bar features (integrated dock) pair with
    property bool isPrimary: true

    readonly property var spec: panel ? panel : PanelLayout.fromLegacy(Config.bar)
    readonly property string panelId: spec.id
    property string barPosition: spec.edge
    property string orientation: barPosition === "left" || barPosition === "right" ? "vertical" : "horizontal"

    // ── Style ──
    readonly property string panelStyle: spec.style
    readonly property var styleMeta: PanelStyles.get(panelStyle)
    readonly property bool islandsStyle: panelStyle === "islands"
    // Modules: size and whether they drop their own pill background
    readonly property int moduleSize: spec.size > 0 ? spec.size : (styleMeta.size > 0 ? styleMeta.size : BarMetrics.moduleSize)
    readonly property bool flat: spec.flat
    readonly property var options: spec.options || ({})
    readonly property bool aligned: spec.align !== "fill"

    // ── Auto-hide: "auto" follows the shared pin (bar.pinnedOnStartup,
    // SUPER+SHIFT+B, pin module), "always" hides until the edge is hovered,
    // "never" stays (fullscreen still hides it) ──
    readonly property string autohideMode: spec.autohide
    readonly property bool pinned: autohideMode === "never" ? true : (autohideMode === "always" ? false : (Config.bar && Config.bar.pinnedOnStartup !== undefined ? Config.bar.pinnedOnStartup : true))
    function togglePin() {
        Panels.togglePinned();
    }
    // Unpinning drops any pending hover reveal so the bar hides immediately
    onPinnedChanged: {
        if (!pinned) {
            hoverActive = false;
            hideDelayTimer.stop();
        }
    }

    // Monitor reference and reference to toplevels on monitor
    readonly property var compositorMonitor: YozdService.monitorFor(screen)

    // Fullscreen detection - scoped to this monitor so the effect only
    // applies to the screen that actually has the fullscreen window
    readonly property bool activeWindowFullscreen: CompositorData.monitorHasFullscreen(compositorMonitor)

    // Whether auto-hide should be active (not pinned, or fullscreen forces it)
    readonly property bool shouldAutoHide: !pinned || activeWindowFullscreen

    onShouldAutoHideChanged: {
        if (!shouldAutoHide) {
            hoverActive = false;
            hideDelayTimer.stop();
        }
    }

    // Hover state with delay to prevent flickering
    property bool hoverActive: false

    // Track if mouse is over bar area
    readonly property bool isMouseOverBar: barMouseArea.containsMouse

    // Check if notch hover is active (for synchronized reveal when bar is at same side)
    // NOTE: We access Visibilities.notchPanels directly because UnifiedShellPanel registers itself as the panel ref
    readonly property var notchPanelRef: Visibilities.notchPanels[screen.name]
    readonly property string notchPosition: (Config.notchPosition !== undefined ? Config.notchPosition : "top")
    readonly property bool notchHoverActive: {
        if (barPosition !== notchPosition)
            return false;
        if (notchPanelRef) {
            // UnifiedShellPanel exposes 'notchHoverActive' property alias pointing to notchContent.hoverActive
            if (typeof notchPanelRef.notchHoverActive !== 'undefined')
                return notchPanelRef.notchHoverActive;
            if (typeof notchPanelRef.hoverActive !== 'undefined')
                return notchPanelRef.hoverActive;
        }
        return false;
    }

    // Check if notch is open (dashboard, powermenu, etc.)
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool notchOpen: screenVisibilities ? (screenVisibilities.launcher || screenVisibilities.dashboard || screenVisibilities.powermenu || screenVisibilities.tools) : false

    // Radius logic for "Squished" style
    readonly property real outerRadius: Styling.radius(0)
    readonly property real innerRadius: (Config.bar && Config.bar.pillStyle === "squished") ? Styling.radius(0) / 2 : Styling.radius(0)
    readonly property bool pinButtonVisible: (Config.bar && Config.bar.showPinButton !== undefined ? Config.bar.showPinButton : true)

    // ── Groups (start/center/end/drawer + gap slots) ──
    readonly property var layoutGroups: PanelLayout.resolveGroups(spec)
    readonly property var startIds: BarLayout.visibleIds(layoutGroups.start, {
        showPinButton: pinButtonVisible
    })
    readonly property var centerIds: BarLayout.visibleIds(layoutGroups.center, {
        showPinButton: pinButtonVisible
    })
    readonly property var endIds: BarLayout.visibleIds(layoutGroups.end, {
        showPinButton: pinButtonVisible
    })
    readonly property var drawerIds: BarLayout.visibleIds(layoutGroups.drawer, {
        showPinButton: pinButtonVisible
    })
    readonly property var gapStartIds: BarLayout.visibleIds(layoutGroups.gapStart, {
        showPinButton: pinButtonVisible
    })
    readonly property var gapEndIds: BarLayout.visibleIds(layoutGroups.gapEnd, {
        showPinButton: pinButtonVisible
    })

    // ── Drawer: hidden modules revealed by hovering the end group ──
    property bool drawerHovered: false
    property bool drawerExpanded: false
    // Keep the drawer open while one of its menus/popups is in use
    readonly property bool drawerHold: {
        if (notchOpen || (screenVisibilities && screenVisibilities.presets))
            return true;
        const groups = Visibilities.barPopupGroups;
        for (const key in groups) {
            const list = groups[key] || [];
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].isOpen && list[i].bar === root)
                    return true;
            }
        }
        return false;
    }
    onDrawerIdsChanged: if (drawerIds.length === 0)
        drawerExpanded = false

    Timer {
        interval: Math.max(0, Config.notch ? Config.notch.hoverExpandDelay : 90)
        running: root.drawerIds.length > 0 && root.drawerHovered && !root.drawerExpanded
        onTriggered: root.drawerExpanded = true
    }
    Timer {
        interval: Math.max(0, Config.notch ? Config.notch.hoverCollapseDelay : 200)
        running: root.drawerExpanded && !root.drawerHovered && !root.drawerHold
        onTriggered: root.drawerExpanded = false
    }

    // ── Islands geometry: tabs match the notch's resting height ──
    readonly property int islandPadding: BarMetrics.islandPadding

    // The style component laying the groups out (panels/styles/)
    readonly property PanelStyleBase styleItem: styleLoader.item as PanelStyleBase
    readonly property string styleFile: styleMeta.file
    onStyleFileChanged: loadStyle()
    Component.onCompleted: loadStyle()
    function loadStyle() {
        styleLoader.setSource(Qt.resolvedUrl("panels/" + styleFile), {
            "barRoot": root
        });
    }
    readonly property int islandThickness: islandsStyle && styleItem ? styleItem.implicitThickness : 0

    // Reveal/hide motion of the panel body and hitbox (Motion tokens; 0 ms
    // when motion is off)
    readonly property var motionIn: Motion.enter
    readonly property var motionOut: Motion.exit
    component EdgeAnim: NumberAnimation {
        duration: root.reveal ? root.motionIn.duration : root.motionOut.duration
        easing.type: root.reveal ? root.motionIn.easing : root.motionOut.easing
    }

    // Reveal logic
    readonly property bool reveal: {
        // If not auto-hiding, always reveal
        if (!shouldAutoHide)
            return true;

        // If fullscreen and not available on fullscreen, hide
        if (activeWindowFullscreen && !(Config.bar && Config.bar.availableOnFullscreen !== undefined ? Config.bar.availableOnFullscreen : false)) {
            return false;
        }

        // Show if: hovering, notch hovering (when at top), notch open
        // IMPORTANT: notchHoverActive must be checked to synchronize with notch
        return isMouseOverBar || hoverActive || notchHoverActive || notchOpen;
    }

    // Timer to delay hiding the bar after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isMouseOverBar) {
                root.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverBarChanged: {
        if (isMouseOverBar) {
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            // Pinned: reset at once; auto-hide: leave a grace period
            if (shouldAutoHide) {
                hideDelayTimer.restart();
            } else {
                hoverActive = false;
            }
        }
    }

    // Integrated dock configuration (classic/islands host it in the middle)
    readonly property bool integratedDockEnabled: (Config.dock && Config.dock.enabled !== undefined ? Config.dock.enabled : false) && (Config.dock && Config.dock.theme !== undefined ? Config.dock.theme : "default") === "integrated" && panelStyle === "classic" && isPrimary
    // Map dock position for integrated based on orientation
    readonly property string integratedDockPosition: {
        const pos = (Config.dock && Config.dock.position !== undefined ? Config.dock.position : "center");

        if (root.orientation === "horizontal") {
            if (pos === "left" || pos === "start")
                return "start";
            if (pos === "right" || pos === "end")
                return "end";
            return "center";
        }

        // Vertical always falls back to center logic inside the column but we treat it as appended to group
        return "center";
    }

    // Radius helpers for dock connections
    readonly property bool dockAtStart: integratedDockEnabled && integratedDockPosition === "start"
    readonly property bool dockAtEnd: integratedDockEnabled && integratedDockPosition === "end"

    readonly property bool frameEnabled: Config.bar && Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false
    readonly property int frameOffset: frameEnabled ? (Config.bar && Config.bar.frameThickness !== undefined ? Config.bar.frameThickness : 6) : 0
    // The frame swallows the panel (bar.containBar), for styles that allow it
    readonly property bool contained: styleMeta.containable && (Config.bar && Config.bar.containBar !== undefined ? Config.bar.containBar : false) && frameEnabled
    readonly property bool actualContainBar: contained

    // Distance to the screen/frame edge, and to the screen ends along the edge
    readonly property int effectiveOuterMargin: spec.margin >= 0 ? spec.margin : (styleItem ? styleItem.outerMargin : 0)
    readonly property int sideMargin: spec.margin >= 0 ? spec.margin : (styleItem ? styleItem.sideMargin : 0)
    readonly property int barPadding: styleItem ? styleItem.padding : 0
    readonly property int topOuterMargin: (orientation === "vertical" ? sideMargin : (barPosition === "top" ? effectiveOuterMargin : 0))
    readonly property int bottomOuterMargin: (orientation === "vertical" ? sideMargin : (barPosition === "bottom" ? effectiveOuterMargin : 0))
    readonly property int leftOuterMargin: (orientation === "horizontal" ? sideMargin : (barPosition === "left" ? effectiveOuterMargin : 0))
    readonly property int rightOuterMargin: (orientation === "horizontal" ? sideMargin : (barPosition === "right" ? effectiveOuterMargin : 0))

    // Cross-edge size of the panel body, and its length when not filling the edge
    readonly property int panelThickness: spec.thickness > 0 ? spec.thickness : (styleItem ? Math.round(styleItem.implicitThickness) : 0)
    readonly property int panelLength: styleItem ? Math.round(styleItem.implicitLength) : 0
    readonly property int barTargetWidth: orientation === "vertical" ? panelThickness : 0
    readonly property int barTargetHeight: orientation === "horizontal" ? panelThickness : 0

    readonly property int totalBarWidth: barTargetWidth + ((root.barPosition === "left" || root.orientation === "horizontal") ? (root.frameOffset + root.leftOuterMargin) : 0) + ((root.barPosition === "right" || root.orientation === "horizontal") ? (root.frameOffset + root.rightOuterMargin) : 0)

    readonly property int totalBarHeight: barTargetHeight + ((root.barPosition === "top" || root.orientation === "vertical") ? (root.frameOffset + root.topOuterMargin) : 0) + ((root.barPosition === "bottom" || root.orientation === "vertical") ? (root.frameOffset + root.bottomOuterMargin) : 0)

    // Depth from the screen edge (frame included) the panel occupies
    readonly property int edgeDepth: (orientation === "horizontal" ? barTargetHeight : barTargetWidth) + effectiveOuterMargin

    // ── Span along the edge for panels that do not fill it (align) ──
    readonly property real edgeLength: orientation === "horizontal" ? width : height
    readonly property real spanLength: aligned ? Math.min(panelLength + 2 * sideMargin, Math.max(0, edgeLength - 2 * frameOffset)) : edgeLength
    readonly property real spanStart: {
        if (!aligned)
            return 0;
        switch (spec.align) {
        case "start":
            return frameOffset;
        case "end":
            return edgeLength - frameOffset - spanLength;
        default:
            return Math.round((edgeLength - spanLength) / 2);
        }
    }

    // ── Span the bar occupies on its edge, measured from each screen end
    // (panel coordinates, horizontal bars). Live activities use the rest. ──
    readonly property real startExtent: {
        if (orientation !== "horizontal")
            return 0;
        if (aligned)
            return spanStart + (styleItem ? styleItem.startReach : 0);
        return frameOffset + leftOuterMargin + (styleItem ? styleItem.startReach : 0);
    }
    readonly property real endExtent: {
        if (orientation !== "horizontal")
            return 0;
        if (aligned)
            return edgeLength - spanStart - spanLength + (styleItem ? styleItem.endReach : 0);
        return frameOffset + rightOuterMargin + (styleItem ? styleItem.endReach : 0);
    }
    // Fillet of the tab-shaped styles (0 for strips)
    readonly property real islandFillet: styleItem ? styleItem.fillet : 0

    // Base outer margin for reservation logic (4px + border when !containBar)
    readonly property int baseOuterMargin: effectiveOuterMargin

    // Shadow logic for bar components (tab styles carry the shadow instead)
    readonly property bool shadowsEnabled: !flat && styleMeta.containable && Config.showBackground && (!actualContainBar || (Config.bar && Config.bar.keepBarShadow !== undefined ? Config.bar.keepBarShadow : false))

    // The hitbox for the mask
    property alias barHitbox: barMouseArea
    readonly property Region hitRegion: Region {
        item: root.visible ? barMouseArea : null
    }

    readonly property int hoverStrip: Math.max((Config.bar && Config.bar.hoverRegionHeight !== undefined ? Config.bar.hoverRegionHeight : 8), 4) + root.frameOffset

    // MouseArea for hover detection - contains bar content (like Dock)
    MouseArea {
        id: barMouseArea
        hoverEnabled: true

        // Size includes margins
        width: root.orientation === "horizontal" ? root.spanLength : (root.reveal ? root.totalBarWidth : root.hoverStrip)
        height: root.orientation === "vertical" ? root.spanLength : (root.reveal ? root.totalBarHeight : root.hoverStrip)

        // Position using x/y
        x: {
            if (root.barPosition === "right")
                return parent.width - width;
            return root.orientation === "horizontal" ? root.spanStart : 0;
        }
        y: {
            if (root.barPosition === "bottom")
                return parent.height - height;
            return root.orientation === "vertical" ? root.spanStart : 0;
        }

        Behavior on x {
            enabled: root.orientation === "vertical"
            EdgeAnim {}
        }
        Behavior on y {
            enabled: root.orientation === "horizontal"
            EdgeAnim {}
        }

        Behavior on width {
            enabled: root.orientation === "vertical"
            EdgeAnim {}
        }
        Behavior on height {
            enabled: root.orientation === "horizontal"
            EdgeAnim {}
        }

        // Bar content inside MouseArea (clicks pass through to children)
        Item {
            id: bar

            // Along the edge an aligned panel already sits inside the frame
            readonly property int alongOffset: root.aligned ? 0 : root.frameOffset

            anchors {
                top: (root.barPosition === "top" || root.orientation === "vertical") ? parent.top : undefined
                bottom: (root.barPosition === "bottom" || root.orientation === "vertical") ? parent.bottom : undefined
                left: (root.barPosition === "left" || root.orientation === "horizontal") ? parent.left : undefined
                right: (root.barPosition === "right" || root.orientation === "horizontal") ? parent.right : undefined

                topMargin: root.barPosition === "top" ? (root.frameOffset + root.topOuterMargin) : (root.orientation === "vertical" ? (bar.alongOffset + root.topOuterMargin) : 0)
                bottomMargin: root.barPosition === "bottom" ? (root.frameOffset + root.bottomOuterMargin) : (root.orientation === "vertical" ? (bar.alongOffset + root.bottomOuterMargin) : 0)
                leftMargin: root.barPosition === "left" ? (root.frameOffset + root.leftOuterMargin) : (root.orientation === "horizontal" ? (bar.alongOffset + root.leftOuterMargin) : 0)
                rightMargin: root.barPosition === "right" ? (root.frameOffset + root.rightOuterMargin) : (root.orientation === "horizontal" ? (bar.alongOffset + root.rightOuterMargin) : 0)
            }

            states: [
                State {
                    name: "horizontal"
                    when: root.orientation === "horizontal"
                    PropertyChanges {
                        target: bar
                        height: root.barTargetHeight
                    }
                },
                State {
                    name: "vertical"
                    when: root.orientation === "vertical"
                    PropertyChanges {
                        target: bar
                        width: root.barTargetWidth
                    }
                }
            ]

            // Opacity animation
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                EdgeAnim {}
            }

            // Slide animation
            transform: Translate {
                x: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "left")
                        return root.reveal ? 0 : -bar.width - (root.frameOffset + root.leftOuterMargin);
                    if (root.barPosition === "right")
                        return root.reveal ? 0 : bar.width + (root.frameOffset + root.rightOuterMargin);
                    return 0;
                }
                y: {
                    if (!root.shouldAutoHide)
                        return 0;
                    if (root.barPosition === "top")
                        return root.reveal ? 0 : -bar.height - (root.frameOffset + root.topOuterMargin);
                    if (root.barPosition === "bottom")
                        return root.reveal ? 0 : bar.height + (root.frameOffset + root.bottomOuterMargin);
                    return 0;
                }
                Behavior on x {
                    EdgeAnim {}
                }
                Behavior on y {
                    EdgeAnim {}
                }
            }

            // The style lays the groups out (panels/PanelStyles.js registry)
            Loader {
                id: styleLoader
                anchors.fill: parent
            }
        }
    }
}
