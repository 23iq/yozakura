import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.modules.theme
import qs.modules.widgets.defaultview
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.tools
import qs.modules.services
import qs.modules.components
import qs.modules.widgets.launcher
import qs.modules.bar.workspaces
import qs.modules.aicenter.quickask
import qs.config
import qs.modules.shell
import "./NotchNotificationView.qml"
import qs.modules.bar.panels
import qs.modules.shell.hosts
import "NotchReveal.js" as NotchReveal
import "NotchShape.js" as NotchShape

Item {
    id: root

    required property ShellScreen screen
    property bool unifiedEffectActive: false

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool isScreenFocused: YozdService.focusedMonitor && YozdService.focusedMonitor.name === screen.name

    // Monitor reference and refrence to toplevels on monitor
    readonly property var compositorMonitor: YozdService.monitorFor(screen)
    readonly property var toplevels: (!compositorMonitor || !compositorMonitor.activeWorkspace || !YozdService.clients.values) ? [] : YozdService.clients.values.filter(c => c.workspace.id === compositorMonitor.activeWorkspace.id)

    // Check if there are any windows on the current monitor and workspace
    readonly property bool hasWindows: toplevels.length > 0

    // Get the bar position for this screen
    readonly property string barPosition: (barPanelRef && barPanelRef.barPosition !== undefined) ? barPanelRef.barPosition : Panels.primaryEdge
    readonly property string notchPosition: Config.notchPosition !== undefined ? Config.notchPosition : "top"
    // Side edge: the notch stands upright and opens toward the center
    readonly property bool vertical: NotchShape.vertical(notchPosition)
    readonly property int frameOffset: (Config.bar && Config.bar.frameEnabled && !root.activeWindowFullscreen) ? ((Config.bar.frameThickness !== undefined) ? Config.bar.frameThickness : 6) : 0
    // Space between the screen edge and the notch: the island floats; a
    // side notch already sits past the frame (EdgeLayout.notchRect)
    readonly property int edgeGap: (Config.notchTheme === "island" ? 4 : 0) + (vertical ? 0 : frameOffset)
    readonly property int popupGap: 4
    // {x, y} of a `w` x `h` child of `box` against the notch edge (`gap`
    // from it), centered along it
    function edgePlace(box, w, h, gap) {
        return NotchShape.viewPos(root.notchPosition, {
            w: box.width,
            h: box.height
        }, {
            w: w,
            h: h
        }, gap);
    }
    // Notch region on its edge (align, bar/dock/frame insets, hover strip)
    readonly property NotchPlacement placement: NotchPlacement {
        env: EdgeService.envFor(root.screen)
        width: notchRegionContainer.width
        height: notchRegionContainer.height
        revealed: root.reveal
        hoverDepth: Math.max((Config.notch && Config.notch.hoverRegionHeight !== undefined) ? Config.notch.hoverRegionHeight : 8, 8)
    }
    // Hidden: slid back behind its edge
    readonly property var hideOffset: NotchShape.hideOffset(notchPosition, vertical ? notchContainer.width : notchContainer.height)

    // Get the bar panel for this screen to check its state
    readonly property var barPanelRef: Visibilities.barPanels[screen.name]
    // The primary BarContent itself (span, groups, style): the bar panel
    // above is the UnifiedShellPanel, which has none of that geometry
    readonly property var barContentRef: Visibilities.bars[screen.name] ?? null

    // Check if bar is pinned (use bar state directly)
    readonly property bool barPinned: {
        // If barPanelRef exists, trust its pinned state explicitly
        if (barPanelRef && typeof barPanelRef.pinned !== 'undefined') {
            return barPanelRef.pinned;
        }
        // Fallback to config only if panel ref is missing
        return (Config.bar && Config.bar.pinnedOnStartup !== undefined) ? Config.bar.pinnedOnStartup : true;
    }
    
    // Check if bar is hovering (for synchronized reveal when bar is at same side)
    readonly property bool barHoverActive: {
        if (barPosition !== notchPosition)
            return false;
        if (barPanelRef && typeof barPanelRef.hoverActive !== 'undefined') {
            return barPanelRef.hoverActive;
        }
        return false;
    }

    // Fullscreen detection - scoped to this monitor so the effect only
    // applies to the screen that actually has the fullscreen window
    readonly property bool activeWindowFullscreen: CompositorData.monitorHasFullscreen(compositorMonitor)

    // Check if the bar for this screen is vertical
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

    // Notch state properties
    // Launcher/dashboard only open the notch when it hosts them (HostRouter)
    readonly property bool screenNotchOpen: HostRouter.notchOpen(screenVisibilities)
    readonly property bool hasActiveNotifications: Notifications.notchPopupList.length > 0 && Notifications.showsOnScreen(screen.name)

    // Hover state with delay to prevent flickering
    property bool hoverActive: false

    // Track if mouse is over any notch-related area: the edge strip (or the
    // stem of a dropped notch) and the whole notch silhouette plus a small
    // tolerance. The silhouette sliding under a still pointer while it
    // slides back (avoidance.returning) does not count as arriving on it, so
    // a collapse never re-opens it by itself.
    readonly property bool isMouseOverNotch: notchMouseAreaHover.hovered || (notchRegionContainer.hovered && !avoidance.returning)

    // Pointer presence held for notch.hoverCollapseDelay: what keeps the
    // expanded notch (pill, panels) open while crossing child controls
    NotchHoverHold {
        id: hoverHold
        over: root.isMouseOverNotch
        delay: Config.notch ? Config.notch.hoverCollapseDelay : 200
        intentDelay: Config.notch ? Config.notch.hoverExpandDelay : 90
    }

    // A grown notch never covers the bar's own modules (NotchAvoid.js)
    NotchAvoidance {
        id: avoidance
        screen: root.screen
        bar: root.barContentRef
        position: root.notchPosition
        pointer: hoverHold.held
        grown: !notchContainer.pillCollapsed && (notchContainer.styleSpec.collapses || root.screenNotchOpen || root.hasActiveNotifications || (root.defaultView ? root.defaultView.panelExpanded : false))
        targetAlong: Math.max(root.vertical ? notchContainer.targetHeight : notchContainer.targetWidth, notificationPopupContainer.targetWidth)
        restAlong: notchContainer.restAlong
        restAcross: (root.vertical ? notchContainer.capsule.w : notchContainer.capsule.h) + root.edgeGap
        edgeGap: root.edgeGap
        gap: root.popupGap
    }
    // Mask piece of a dropped notch: the bridge from the edge down to it
    readonly property Item notchStemHitbox: avoidance.moved && root.reveal ? notchHoverRegion : null

    readonly property bool microphoneNotice: MicrophoneStatus.noticeVisible && MicrophoneStatus.noticeScreen === screen.name

    // Reveal logic (NotchReveal.js); a disabled notch (notch.enabled, see
    // ShellLayout) only shows while a view is open in it
    readonly property bool reveal: NotchReveal.reveal({
        "enabled": ShellLayout.notchEnabled,
        "keepHidden": Config.notch ? Config.notch.keepHidden === true : false,
        "sameEdge": barPosition === notchPosition,
        "hasWindows": hasWindows,
        "fullscreen": activeWindowFullscreen,
        "barPinned": barPinned,
        "availableOnFullscreen": Config.bar ? Config.bar.availableOnFullscreen === true : false,
        "open": screenNotchOpen || panelAuto,
        "interacting": screenNotchOpen || panelAuto || hasActiveNotifications || microphoneNotice || hoverActive || barHoverActive
    })

    // Timer to delay hiding the notch after mouse leaves
    Timer {
        id: hideDelayTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!root.isMouseOverNotch) {
                root.hoverActive = false;
            }
        }
    }

    // Watch for mouse state changes
    onIsMouseOverNotchChanged: {
        if (isMouseOverNotch) {
            // Immediately show when mouse enters any notch area
            hideDelayTimer.stop();
            hoverActive = true;
        } else {
            // Delay hiding when mouse leaves
            hideDelayTimer.restart();
        }
    }

    // The hitbox for the mask
    readonly property Item notchHitbox: root.reveal ? notchHoverArea : notchHoverRegion

    // Default view component - user@host text
    Component {
        id: defaultViewComponent
        DefaultView { screenName: root.screen.name; revealed: root.reveal }
    }

    // The resting notch view (DefaultView, panels registry: NotchPanels.js)
    readonly property var defaultView: notchContainer.defaultView
    // Its open panel takes keyboard focus and click-outside (registry `modal`)
    readonly property bool panelModal: root.defaultView ? root.defaultView.modalPanel : false
    // It opened a panel by itself (registry `auto`): show the notch
    readonly property bool panelAuto: root.defaultView ? root.defaultView.autoPanel : false
    function dismissPanel() {
        if (root.defaultView)
            root.defaultView.dismissPanel();
    }

    // Shows the launcher/dashboard when layout.<module>.host is "notch"
    NotchHost {
        id: notchHost
        container: notchContainer
    }

    // Persistent views to avoid creation lag when opening the notch
    Loader {
        id: persistentLauncherViewLoader
        active: false
        sourceComponent: Component { LauncherView { visible: false } }
    }

    Loader {
        id: persistentDashboardViewLoader
        active: false
        sourceComponent: Component { DashboardView { visible: false; screenName: root.screen.name } }
    }

    // Persistent power menu view
    Loader {
        id: persistentPowerMenuViewLoader
        active: false
        sourceComponent: Component { PowerMenuView { visible: false } }
    }

    // Persistent tools menu view
    Loader {
        id: persistentToolsMenuViewLoader
        active: false
        sourceComponent: Component { ToolsMenuView { visible: false } }
    }

    // AI quick ask: a notch module (focusable input inside the island);
    // it switches views like the launcher, unlike the registry's panels.
    Loader {
        id: persistentQuickAskLoader
        active: false
        sourceComponent: Component { QuickAskCard { visible: false } }
    }

    // Notification view component
    Component {
        id: notificationViewComponent
        NotchNotificationView {}
    }

    // Hover region for detecting mouse when notch is hidden (doesn't block clicks)
    Item {
        id: notchHoverRegion

        // On the notch's edge; a thin strip while hidden, the whole notch
        // once revealed (NotchShape.hoverStrip); the resting footprint and
        // the bridge down to it once the notch moved off the bar
        readonly property var rect: root.reveal && (avoidance.moved || avoidance.returning) ? avoidance.stem : root.placement.hoverStrip
        x: rect.x
        y: rect.y
        width: rect.w
        height: rect.h

        Behavior on width {
            enabled: Config.animDuration > 0 && root.vertical
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Motion.morph.easing
            }
        }
        Behavior on height {
            enabled: Config.animDuration > 0 && !root.vertical
            NumberAnimation {
                duration: Config.animDuration / 4
                easing.type: Motion.morph.easing
            }
        }

        // HoverHandler doesn't block mouse events
        HoverHandler {
            id: notchMouseAreaHover
            enabled: true
        }
    }

    Item {
        id: notchRegionContainer
        
        readonly property bool popupShown: notificationPopupContainer.visible
        // The popup stacks below a top/bottom notch, beside a side one
        width: root.vertical ? notchAnimationContainer.width + (popupShown ? notificationPopupContainer.width + root.popupGap : 0) : Math.max(notchAnimationContainer.width, popupShown ? notificationPopupContainer.width : 0)
        height: root.vertical ? Math.max(notchAnimationContainer.height, popupShown ? notificationPopupContainer.height : 0) : notchAnimationContainer.height + (popupShown ? notificationPopupContainer.height + root.popupGap : 0)

        // On its edge, aligned (notch.align), past a side bar (EdgeLayout),
        // moved off the bar's modules while grown (NotchAvoidance)
        x: root.placement.x + avoidance.offsetX
        y: root.placement.y + avoidance.offsetY

        // The revealed notch: a HoverHandler (passive) on the container, an
        // ancestor of every control in it, so child MouseAreas and buttons
        // never take the hover away from the notch
        HoverHandler {
            id: notchBodyHover
        }
        // ...plus a small tolerance around the silhouette (also the mask)
        Item {
            id: notchHoverArea
            z: -1
            anchors.fill: parent
            anchors.margins: -Math.round(Metrics.spacing / 2)
            HoverHandler {
                id: notchToleranceHover
            }
        }
        readonly property bool hovered: notchBodyHover.hovered || notchToleranceHover.hovered

        // Animation container for reveal/hide
        Item {
            id: notchAnimationContainer
            // Hugs the edge, centered along it
            x: root.edgePlace(parent, width, height, 0).x
            y: root.edgePlace(parent, width, height, 0).y

            width: notchContainer.width + (root.vertical ? root.edgeGap : 0)
            height: notchContainer.height + (root.vertical ? 0 : root.edgeGap)

            // Opacity animation
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.enter.easing
                }
            }

            // Slide behind the edge when hidden
            transform: Translate {
                x: root.reveal ? 0 : root.hideOffset.x
                y: root.reveal ? 0 : root.hideOffset.y
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }

            // Center notch
            Notch {
                id: notchContainer
                screenName: root.screen.name
                unifiedEffectActive: root.unifiedEffectActive
                parentHovered: hoverHold.held
                hoverIntent: hoverHold.intent
                // Length a dock on its edge parts for (DockPanel): only
                // for what the pointer grew; a notch growing by itself
                // (notification, activity, shortcut) never moves the bar
                // under a pointer aiming at it, it drops past it instead
                edgeClaim: avoidance.anchored ? avoidance.targetAlong : 0
                x: root.edgePlace(parent, width, height, root.edgeGap).x
                y: root.edgePlace(parent, width, height, root.edgeGap).y

                // layer.enabled: true
                // layer.effect: Shadow {}

                defaultViewComponent: defaultViewComponent
                launcherViewComponent: null
                dashboardViewComponent: null
                powermenuViewComponent: null
                toolsMenuViewComponent: null
                notificationViewComponent: notificationViewComponent
                visibilities: root.screenVisibilities

                // Handle global keyboard events
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape && root.screenNotchOpen) {
                        Visibilities.setActiveModule("");
                        event.accepted = true;
                    }
                }
            }
        }

        // Popup de notificaciones debajo del notch
        StyledRect {
            id: notificationPopupContainer
            variant: "bg"
            // Toward the screen center from the notch: the far side of the region
            readonly property var at: NotchShape.viewPos(NotchShape.opposite(root.notchPosition), {
                w: notchRegionContainer.width,
                h: notchRegionContainer.height
            }, {
                w: width,
                h: height
            }, 0)
            x: at.x
            y: at.y
            
            // Target width (animated below); 0 while hidden
            readonly property real targetWidth: shouldShowNotificationPopup ? Math.round(popupHovered ? 420 + 48 : 320 + 48) : 0
            width: Math.round(popupHovered ? 420 + 48 : 320 + 48)
            height: shouldShowNotificationPopup ? (popupHovered ? notificationPopup.implicitHeight + 32 : notificationPopup.implicitHeight + 32) : 0
            clip: false
            visible: height > 0
            z: 999
            radius: Styling.radius(20)

            // Apply same reveal animation as notch
            opacity: root.reveal ? 1 : 0
            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.enter.easing
                }
            }

            transform: Translate {
                x: root.reveal ? 0 : root.hideOffset.x
                y: root.reveal ? 0 : root.hideOffset.y
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Motion.morph.easing
                    }
                }
            }

            // The rect\'s own shadow (also drawn by a corner style\'s mask)
            enableShadow: true

            property bool popupHovered: false

            readonly property bool shouldShowNotificationPopup: {
                // Mostrar solo si hay notificaciones y el notch esta expandido
                if (!root.hasActiveNotifications || !root.screenNotchOpen)
                    return false;

                // NO mostrar si estamos en el launcher (widgets tab con currentTab === 0)
                if (screenVisibilities.dashboard) {
                    // Solo ocultar si estamos en el widgets tab (dashboard tab 0) Y mostrando el launcher (widgetsTab index 0)
                    return !(GlobalStates.dashboardCurrentTab === 0 && GlobalStates.widgetsTabCurrentIndex === 0);
                }

                return true;
            }

            Behavior on width {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                    easing.overshoot: Motion.morph.overshoot
                }
            }

            Behavior on height {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Motion.morph.duration
                    easing.type: Motion.morph.easing
                }
            }

            HoverHandler {
                id: popupHoverHandler
                enabled: notificationPopupContainer.shouldShowNotificationPopup

                onHoveredChanged: {
                    notificationPopupContainer.popupHovered = hovered;
                }
            }

            NotchNotificationView {
                id: notificationPopup
                anchors.fill: parent
                anchors.margins: 16
                visible: notificationPopupContainer.shouldShowNotificationPopup
                opacity: visible ? 1 : 0
                notchHovered: notificationPopupContainer.popupHovered

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Motion.enter.easing
                    }
                }
            }
        }
    }


    // Listen for dashboard and powermenu state changes
    Connections {
        target: screenVisibilities

        function onLauncherChanged() {
            if (root.screenVisibilities.launcher && HostRouter.hostFor("launcher") === "notch") {
                persistentLauncherViewLoader.active = true;
                Qt.callLater(() => notchHost.open(persistentLauncherViewLoader.item, root.screen));
            } else if (!root.screenVisibilities.launcher) {
                notchHost.close();
            }
        }

        function onDashboardChanged() {
            if (root.screenVisibilities.dashboard && HostRouter.hostFor("dashboard") === "notch") {
                persistentDashboardViewLoader.active = true;
                Qt.callLater(() => notchHost.open(persistentDashboardViewLoader.item, root.screen));
            } else if (!root.screenVisibilities.dashboard) {
                notchHost.close();
            }
        }

        function onPowermenuChanged() {
            // other layout.powermenu.style values open in the menu overlay
            if (HostRouter.hostFor("powermenu") !== "notch")
                return;
            if (screenVisibilities.powermenu) {
                persistentPowerMenuViewLoader.active = true;
                Qt.callLater(() => {
                    if (persistentPowerMenuViewLoader.item) {
                        notchContainer.pushView(persistentPowerMenuViewLoader.item);
                        Qt.callLater(() => {
                            if (notchContainer.stackView.currentItem) {
                                notchContainer.stackView.currentItem.forceActiveFocus();
                            }
                        });
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }

        function onAiquickChanged() {
            if (root.screenVisibilities.aiquick) {
                persistentQuickAskLoader.active = true;
                Qt.callLater(() => {
                    if (persistentQuickAskLoader.item) {
                        notchContainer.pushView(persistentQuickAskLoader.item);
                        Qt.callLater(() => {
                            if (notchContainer.stackView.currentItem)
                                notchContainer.stackView.currentItem.forceActiveFocus();
                        });
                    }
                });
            } else if (notchContainer.stackView.depth > 1) {
                notchContainer.stackView.pop();
                notchContainer.isShowingDefault = true;
                notchContainer.isShowingNotifications = false;
            }
        }

        function onToolsChanged() {
            // other layout.tools.style values open in the menu overlay
            if (HostRouter.hostFor("tools") !== "notch")
                return;
            if (screenVisibilities.tools) {
                persistentToolsMenuViewLoader.active = true;
                Qt.callLater(() => {
                    if (persistentToolsMenuViewLoader.item) {
                        notchContainer.pushView(persistentToolsMenuViewLoader.item);
                        Qt.callLater(() => {
                            if (notchContainer.stackView.currentItem) {
                                notchContainer.stackView.currentItem.forceActiveFocus();
                            }
                        });
                    }
                });
            } else {
                if (notchContainer.stackView.depth > 1) {
                    notchContainer.stackView.pop();
                    notchContainer.isShowingDefault = true;
                    notchContainer.isShowingNotifications = false;
                }
            }
        }
    }

    // Export some internal items for Visibilities
    property alias notchContainerRef: notchContainer
    // Notch + notification popup: where this item draws (shadow capture)
    readonly property Item visualRegion: notchRegionContainer
}
